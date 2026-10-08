// Notification service for evoshell.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.commons

import "components"
import "LayoutModel.js" as LayoutModel
import "NotificationLogic.js" as NotificationLogic

Item {
  id: service

  // Injected by the shell service loader.
  property var shell: null

  readonly property string home: Quickshell.env("HOME")
  // History + DND live under XDG state: they're persistent user state
  // (the notifications received, the last-set DND preference), not
  // regeneratable cache that a `rm -rf ~/.cache` should wipe.
  // Must match bin/notif-files: $EVOSHELL_STATE/monitors/notifications/.
  readonly property string stateDir: Util.stateDir(home) + "/monitors/"
  readonly property string focusAppHelper: Qt.resolvedUrl("bin/focus-app").toString().replace("file://", "")
  readonly property string filesHelper: Qt.resolvedUrl("bin/notif-files").toString().replace("file://", "")
  readonly property var filesHelperCmd: ["/usr/bin/python3", "-I", filesHelper]
  // One file per on-screen popup, so live toasts survive shell restarts.
  // A file exists exactly as long as its popup is showing: written when the
  // toast appears, moved into historyDir when it expires, is dismissed, or is
  // acted upon.
  readonly property string popupStateDir: stateDir + "notifications/"
  // The notifications that already left the screen, one file each, trimmed to
  // the newest historyLimit. This directory IS the history: `showHistory`
  // replays exactly what has been moved in here.
  readonly property string historyDir: popupStateDir + "history/"
  // Copies of the avatars/images persisted entries reference — the sender's
  // originals don't outlive the notification (see persistablePopup). Each
  // copy lives and dies with the JSON file whose stem it carries.
  readonly property string imagesDir: popupStateDir + "images/"
  // Corner radius is shared with the menu and shell panels.
  // It mirrors Hyprland's current decoration:rounding value.
  readonly property int cornerRadius: Theme.cornerRadius
  // Toasts honour per-monitor placements from the shell config. Bar clearance is
  // applied when the bar shares the same edge as the notification anchor.
  readonly property string barPosition: shell && shell.barConfig ? String(shell.barConfig.position || "top") : "top"
  readonly property bool barVertical: barPosition === "left" || barPosition === "right"
  readonly property int defaultBarSize: barVertical ? Theme.bar.sizeVertical : Theme.bar.sizeHorizontal
  readonly property int liveBarSize: shell && shell.bar && !shell.bar.barHidden ? Math.max(0, shell.bar.barSize) : defaultBarSize
  readonly property int barClearance: liveBarSize + Theme.popupMargin

  // Placements come from the merged shell config (repo defaults + overrides).
  readonly property bool shellConfigReady: !!(shell && shell.shellConfig)
  readonly property var shellConfig: shellConfigReady ? shell.shellConfig : ({})

  // One screen: the saved notification output, else the bar's output.
  // An empty list does not mean every screen. Wait until the shell config
  // exists so the first frame does not flash popups on every output.
  readonly property var notificationPlacements: LayoutModel.readNotificationPlacements(shellConfig)
  readonly property var popupScreens: shellConfigReady
    ? LayoutModel.screensForPlacements(notificationPlacements, Quickshell.screens)
    : []
  readonly property var barScreenNames: LayoutModel.screenNames(
    LayoutModel.screensForPlacements(
      LayoutModel.readBarPlacements(shell && shell.barConfig ? shell.barConfig : {}),
      Quickshell.screens))

  // Live Notification objects by originalId, kept OUT of the ListModels: a
  // QObject stored in a model role becomes a dangling C++ pointer when the
  // server destroys the notification (sender close, DND untrack, dismiss),
  // and the next read of that role segfaults in QQmlListModel::data. A JS
  // map only holds a wrapper, which degrades to a catchable error instead.
  property var liveRefs: ({})

  // PersistentProperties handles in-process QML reloads. The on-disk
  // notifications.json file is the cross-restart backstop — its `dnd` key
  // is hydrated into persisted.doNotDisturb on startup and written back via
  // a debounced save timer.
  PersistentProperties {
    id: persisted
    reloadableId: "evo-notifications"
    property bool doNotDisturb: false
    onDoNotDisturbChanged: {
      // Suppress the write that load-time hydration would otherwise trigger.
      if (service._hydrating) return
      service.scheduleSettingsSave()
    }
  }

  // Guards onDoNotDisturbChanged while we're hydrating from disk so the
  // hydration assignment doesn't immediately schedule a write-back.
  property bool _hydrating: false

  readonly property alias doNotDisturb: persisted.doNotDisturb

  function setDoNotDisturb(value) {
    persisted.doNotDisturb = !!value
  }

  // popupModel feeds the on-screen toast stack — the only model the service
  // keeps. Everything a toast leaves behind lives on disk under historyDir.
  //
  // Aliased as a property so consumers outside this Item's id scope can bind
  // to it. QML ids aren't visible to external consumers without the alias.
  property alias popupModel: popupModel
  ListModel { id: popupModel }

  // How many notifications the history directory keeps, and therefore how
  // many `showHistory` can replay. The history panel reads the same files.
  readonly property int historyLimit: 10
  property var historyEntries: []
  readonly property int unreadCount: {
    var n = 0
    var rows = historyEntries || []
    for (var i = 0; i < rows.length; i++) {
      var row = rows[i]
      if (row && row.read !== true && row.hidden !== true)
        n++
    }
    return n
  }

  readonly property int lowPopupDuration: 3000
  readonly property int normalPopupDuration: 5000
  readonly property int maxPopupDuration: 30000

  function durationFor(urgency, expireTimeout) {
    switch (urgency) {
    case NotificationUrgency.Critical:
      return 0
    case NotificationUrgency.Low:
      return Math.min(maxPopupDuration, Math.max(lowPopupDuration, requestedDuration(expireTimeout)))
    default:
      return Math.min(maxPopupDuration, Math.max(normalPopupDuration, requestedDuration(expireTimeout)))
    }
  }

  function requestedDuration(expireTimeout) {
    // FreeDesktop notification spec (and Quickshell) report expireTimeout in
    // milliseconds, so pass it through directly.
    var ms = Number(expireTimeout || 0)
    if (!isFinite(ms) || ms <= 0) return 0
    return Math.round(ms)
  }

  // DND bypass: only let through notifications we trust to be intentional
  // and rare.
  //   - evoshell-action: a user-action confirmation toast ("Theme changed",
  //     "Screenshot saved"). The user JUST did something — their feedback
  //     should show.
  //   - urgency=critical AND app_name=notify-send: bare-CLI emergency alerts.
  //     Trusted because it's almost always the shell or system scripts —
  //     chat apps set app_name to their brand (Discord/Slack/Vesktop), which
  //     falls outside this rule.
  function shouldBypassDnd(notification) {
    return NotificationLogic.shouldBypassDnd(notification, NotificationUrgency.Critical)
  }

  function snapshotOf(notification) {
    return NotificationLogic.snapshotOf(notification, Date.now())
  }

  // A notification nobody looks back at:
  //   - the freedesktop `transient` hint is set ("popup only, don't store")
  //   - app_name is "notify-send" (the CLI default — means the sender
  //     didn't bother declaring an identity, so it's almost certainly
  //     ephemeral test/feedback noise)
  //   - app_name is "evoshell-action" (the shell's own user-action toasts —
  //     the user just triggered them)
  // Their toasts still land in history like any other once they've been on
  // screen; the distinction only decides whether a DND-silenced one is worth
  // recording at all.
  function isEphemeral(notification) {
    var transient = false
    try {
      transient = !!(notification.hints && notification.hints["transient"])
    } catch (e) { transient = false }
    return transient || NotificationLogic.isEphemeralApp(String(notification.appName || ""))
  }

  function handleNotification(notification) {
    // Without `tracked = true` the Notification object is destroyed as soon
    // as this signal handler returns, which would null out the `ref` we just
    // captured for the popup card.
    notification.tracked = true
    var snapshot = snapshotOf(notification)
    liveRefs[snapshot.originalId] = notification
    // Guard the delete: a newer notification may have reused this originalId
    // (freedesktop replaces_id) and taken over the map slot.
    notification.closed.connect(function(reason) {
      if (service.liveRefs[snapshot.originalId] === notification)
        delete service.liveRefs[snapshot.originalId]
      // The sender withdrew it (CloseNotification). Nothing else would take a
      // critical toast down.
      if (reason === NotificationCloseReason.CloseRequested)
        Qt.callLater(function() { service.removeClosedPopup(snapshot.originalId, snapshot.timestamp) })
    })

    // DND bypass rules: chat apps abuse urgency=critical to force
    // visibility, so critical alone isn't enough — we also require the
    // sender to be CLI-style. See shouldBypassDnd().
    if (service.doNotDisturb && !shouldBypassDnd(notification)) {
      // The toast never shows, so the only record a silenced notification
      // can leave is a history entry. Write it straight into history —
      // "what did I miss while silenced" is exactly what history is for.
      if (!isEphemeral(notification)) {
        writeSilenced(notification, snapshot)
        return
      }
      delete liveRefs[snapshot.originalId]
      notification.tracked = false
      return
    }

    persistPopupFile(snapshot)
    watchForUpdates(notification, snapshot)
    // Qt.callLater avoids "QV4::Object::insertMember" crashes when a
    // Repeater is mid-incubation while we mutate its model.
    Qt.callLater(function() {
      removePopupsByOriginalId(snapshot.originalId, NotificationLogic.popupFileName(snapshot))
      removeDuplicatePopups(service.currentContent(notification, snapshot))
      popupModel.insert(0, snapshot)
      // An update that arrived while the insert was deferred found no row to
      // write to, and a property that already changed will not change again.
      // Reading the object once the row exists catches up on it.
      service.refreshPopup(notification, snapshot.originalId, snapshot.timestamp)
    })
  }

  // Persist a silenced notification, held tracked until its content is
  // stable: untracking tells the sender its notification closed (Chromium
  // then deletes its avatar file), and a replaces_id update lands on this
  // object without a second onNotification — releasing on a stale snapshot
  // would drop it. Each catch-up write reuses the original file identity.
  function writeSilenced(notification, written) {
    writeHistoryFile(written, function() {
      var updated = null
      try {
        updated = NotificationLogic.replacementSnapshot(notification, written.originalId, written.timestamp)
      } catch (e) {
        // Torn down by the server while the write was queued.
      }
      if (updated && NotificationLogic.popupRowChanged(written, updated)) {
        service.writeSilenced(notification, updated)
        return
      }
      service.releaseSilenced(notification, written.originalId)
    })
  }

  // Let go of a DND-silenced notification once its history write has run.
  // The id may have been reused and the object torn down meanwhile.
  function releaseSilenced(notification, originalId) {
    if (liveRefs[originalId] === notification) delete liveRefs[originalId]
    try {
      notification.tracked = false
    } catch (e) {
      // Object already destroyed by the server — nothing left to release.
    }
  }

  // Everything the card draws. A change to any of these is a client updating
  // the notification in place, which is the only kind of update we ever hear
  // about after the popup exists.
  readonly property var updateSignals: [
    "summaryChanged", "bodyChanged", "appNameChanged", "appIconChanged",
    "imageChanged", "urgencyChanged", "expireTimeoutChanged", "hintsChanged"
  ]

  // A client that updates a notification through replaces_id does not produce
  // a second onNotification: the server writes the new content onto the object
  // we are already holding. The card draws a snapshot copied out of that
  // object — deliberately, since the object itself must stay out of the model
  // — so nothing reaches the screen until we copy it again.
  function watchForUpdates(notification, snapshot) {
    function refresh() {
      service.refreshPopup(notification, snapshot.originalId, snapshot.timestamp)
    }

    for (var i = 0; i < updateSignals.length; i++) {
      var signal = notification[updateSignals[i]]
      if (signal && typeof signal.connect === "function") signal.connect(refresh)
    }
  }

  function refreshPopup(notification, originalId, timestamp) {
    // A newer notification may have taken this id over, and the object may
    // outlive its popup — in both cases there is nothing here to refresh.
    if (service.liveRefs[originalId] !== notification) return

    var updated
    try {
      updated = NotificationLogic.replacementSnapshot(notification, originalId, timestamp)
    } catch (e) {
      // Object torn down by the server while the signal was in flight.
      return
    }

    var roles = NotificationLogic.popupRoles()
    for (var i = 0; i < popupModel.count; i++) {
      var row = popupModel.get(i)
      if (!row || row.originalId !== originalId || row.timestamp !== timestamp) continue
      if (!NotificationLogic.popupRowChanged(row, updated)) return
      for (var r = 0; r < roles.length; r++) popupModel.setProperty(i, roles[r], updated[roles[r]])
      // The file name is the timestamp and id this popup was persisted under,
      // so the rewrite lands on the same file: a restart restores the version
      // last shown, and so does the copy that ends up in history.
      persistPopupFile(updated)
      return
    }
  }

  // A restored row carries an id from the previous server generation, and
  // the new server hands out ids from 1 again — so a fresh notification
  // with the same originalId is a coincidence, not the same notification.
  // The timestamp (via the file name) disambiguates: it travels with the
  // row through every model and file round-trip.
  function isRestoredRow(row) {
    return !!row && !!restoredPopups[NotificationLogic.popupFileName(row)]
  }

  // A notification arriving under an originalId a popup on screen already
  // holds supersedes it, so that row leaves the screen. Its file is deleted
  // rather than archived: the row taking its place archives itself when it
  // goes, and history would otherwise hold two entries for what the sender
  // means as one notification.
  // keepFileName is the replacement's own file: a same-millisecond
  // replacement shares the replaced row's filename, and the new write is
  // already queued — deleting that path here would erase the replacement's
  // only file.
  function removePopupsByOriginalId(originalId, keepFileName) {
    for (var i = popupModel.count - 1; i >= 0; i--) {
      var row = popupModel.get(i)
      if (!row || row.originalId !== originalId) continue
      // Not a replaces_id match — see isRestoredRow. Removing it here
      // would silently kill a restored critical alert on an unrelated ping.
      if (isRestoredRow(row)) continue
      if (NotificationLogic.popupFileName(row) !== keepFileName) deletePopupFileFor(row)
      popupModel.remove(i)
    }
  }

  // What the notification says now: a replaces_id update may have landed
  // while its insert was deferred, and the snapshot still holds the original.
  function currentContent(notification, snapshot) {
    try {
      return NotificationLogic.replacementSnapshot(notification, snapshot.originalId, snapshot.timestamp)
    } catch (e) {
      // Torn down by the server meanwhile — the snapshot is all there is.
      return snapshot
    }
  }

  // A notification repeating a toast already on screen takes its place, the
  // same way a replaces_id update would. Only toasts with a live notification
  // behind them qualify: a restored or replayed row shares its images with an
  // entry already in history.
  function removeDuplicatePopups(snapshot) {
    for (var i = popupModel.count - 1; i >= 0; i--) {
      var row = popupModel.get(i)
      if (!NotificationLogic.isDuplicatePopup(row, snapshot) || isRestoredRow(row)) continue
      var ref = liveRefs[row.originalId]
      if (!ref) continue
      deletePopupFileFor(row)
      popupModel.remove(i)
      try {
        if (ref.tracked) ref.dismiss()
      } catch (e) {
        // Object already torn down by the server — nothing to dismiss.
      }
    }
  }

  // The server object is already closed, and its id may belong to a newer
  // notification by now, so this never goes through liveRefs.
  function removeClosedPopup(originalId, timestamp) {
    for (var i = popupModel.count - 1; i >= 0; i--) {
      var row = popupModel.get(i)
      if (!row || row.originalId !== originalId || row.timestamp !== timestamp || isRestoredRow(row)) continue
      archivePopupFileFor(row)
      popupModel.remove(i)
    }
  }

  function dismissPopup(index) {
    removePopup(index, "dismiss")
  }

  function expirePopup(index) {
    removePopup(index, "expire")
  }

  function removePopup(index, reason) {
    if (index < 0 || index >= popupModel.count) return
    var entry = popupModel.get(index)
    var originalId = entry ? entry.originalId : -1
    // A restored row has no live server object, and its old-generation id
    // may meanwhile belong to a fresh notification — resolving liveRefs by
    // id would dismiss that unrelated notification at the server.
    var restored = isRestoredRow(entry)
    var ref = !restored && originalId >= 0 ? liveRefs[originalId] : null
    // The popup is leaving the screen — for any reason — so its file must not
    // survive to the next shell restart. It becomes the newest history entry
    // instead. Rows that never had a file (a history replay, the empty-history
    // placeholder) archive to nothing, which the move tolerates.
    if (entry) {
      archivePopupFileFor(entry)
      if (restored) delete restoredPopups[NotificationLogic.popupFileName(entry)]
    }
    popupModel.remove(index)
    if (ref) {
      try {
        if (ref.tracked) {
          if (reason === "expire" && typeof ref.expire === "function") ref.expire()
          else ref.dismiss()
        }
      } catch (e) {
        // Object already torn down by the server — nothing to dismiss.
      }
    }
  }

  function clearPopups() {
    while (popupModel.count > 0) dismissPopup(0)
  }

  // Ephemeral toast when the monitors panel enables a notification placement.
  function showPlacementPreview(headline, detail) {
    var snapshot = NotificationLogic.snapshotOf({
      id: Date.now(),
      appName: "evoshell-action",
      summary: String(headline || "Notifications here"),
      body: String(detail || ""),
      urgency: NotificationUrgency.Low,
      expireTimeout: lowPopupDuration,
      hints: { transient: true, "evoshell-glyph": "󰂚" }
    }, Date.now())
    Qt.callLater(function() {
      popupModel.insert(0, snapshot)
    })
  }

  // Run the popup's click action, then dismiss. Shell toasts carry the
  // action as an argv vector in the `execArgv` role (see execArgvFromHints),
  // which the persistence files preserve, so restored toasts stay clickable.
  // Third-party clients register a libnotify action under the canonical
  // identifier "default" instead; that one only works while the sender is live.
  function invokePopupDefault(index) {
    if (index < 0 || index >= popupModel.count) return
    var entry = popupModel.get(index)

    // Run the argv (via Util.execArgv, no shell interpretation). Detached so it
    // outlives the shell, which installer toasts depend on: they restart it.
    var argv = NotificationLogic.parseExecArgv(entry ? entry.execArgv : "")
    if (argv) {
      Util.execArgv(argv)
      dismissPopup(index)
      return
    }
    // Restored rows have no live actions, and looking up liveRefs by their
    // old-generation id could fire an unrelated fresh notification's action.
    var ref = entry && !isRestoredRow(entry) ? liveRefs[entry.originalId] : null
    var invoked = false
    try {
      if (ref && ref.actions) {
        for (var i = 0; i < ref.actions.length; i++) {
          var action = ref.actions[i]
          if (action && action.identifier === "default") {
            action.invoke()
            invoked = true
            break
          }
        }
      }
    } catch (e) {
      // Notification already torn down by the server — fall through to focus.
      console.warn("invoke default failed:", e)
    }
    // Chat apps (Slack, Discord, Vesktop, etc.) rarely register a "default"
    // libnotify action — they just expect clicking the notification to
    // focus their window. Fall back to focusing the sending app by class so
    // that click-to-jump actually works.
    if (!invoked) focusApp(entry)
    dismissPopup(index)
  }

  // Try to focus an existing Hyprland window matching the notification's
  // sender. The helper handles case-insensitive class matching.
  function focusApp(entry) {
    if (!entry || !entry.app) return
    focusAppProc.command = [service.focusAppHelper, String(entry.app)]
    focusAppProc.running = true
  }

  Process { id: focusAppProc; running: false }

  // ---------------------------------------------------- popup persistence
  //
  // Mirror every on-screen popup to its own file under popupStateDir so
  // toasts survive shell restarts. Writes, moves and deletes go through one serialized queue: a
  // burst of replaces_id updates must not race a single reused Process, and
  // ordering guarantees a delete issued after a write wins.

  // Popups restored from a previous shell process, keyed by their file
  // name (timestamp-originalId) since ids alone repeat across server
  // generations. The replaces_id handling and liveRefs lookups must not
  // match these rows against fresh notifications.
  property var restoredPopups: ({})

  // Entries are either { command, done } for a file job or { read: true } for
  // a replay's directory read. Queueing the read rather than running it beside
  // the queue is what makes it a barrier: it takes its place in line, so the
  // history it sees is the one that existed when the replay was asked for.
  // Everything queued after it — a clear, an archive, a silenced write — waits
  // for it, and no amount of later traffic can push it back.
  property var popupFileQueue: []

  // Done callback of the job popupFileProc is currently running.
  property var runningPopupFileJobDone: null

  function enqueuePopupFileJob(command, done, stdin) {
    popupFileQueue = popupFileQueue.concat([{ command: command, done: done || null, stdin: stdin || "" }])
    runNextPopupFileJob()
  }

  function enqueueHistoryRead() {
    popupFileQueue = popupFileQueue.concat([{ read: true }])
    runNextPopupFileJob()
  }

  function runNextPopupFileJob() {
    if (readHistoryProc.running || popupFileProc.running) return
    if (popupFileQueue.length === 0) return

    var job = popupFileQueue[0]
    popupFileQueue = popupFileQueue.slice(1)

    if (job.read) {
      startHistoryRead()
      return
    }
    if (job.panel) {
      startPanelHistoryRead()
      return
    }

    popupFileProc.payload = job.stdin || ""
    popupFileProc.stdinEnabled = popupFileProc.payload !== ""
    popupFileProc.command = job.command
    service.runningPopupFileJobDone = job.done || null
    popupFileProc.running = true
  }

  Process {
    id: popupFileProc
    running: false
    property string payload: ""
    onStarted: {
      if (payload !== "") write(payload)
      payload = ""
      stdinEnabled = false
    }
    onExited: {
      var done = service.runningPopupFileJobDone
      service.runningPopupFileJobDone = null
      if (done) {
        try {
          done()
        } catch (e) {
          console.warn("notifications: file job callback failed:", e)
        }
      }
      service.runNextPopupFileJob()
    }
  }

  function persistPopupFile(snapshot) {
    var persistable = NotificationLogic.persistablePopup(snapshot, imagesDir)
    var command = filesHelperCmd.concat(["persist", NotificationLogic.popupFileName(snapshot)])
    for (var i = 0; i < persistable.copies.length; i++)
      command.push(persistable.copies[i].from, persistable.copies[i].to)
    enqueuePopupFileJob(command, null, NotificationLogic.serializePopup(persistable.entry, NotificationUrgency.Normal))
  }

  function deletePopupFileFor(row) {
    if (!row) return
    enqueuePopupFileJob(filesHelperCmd.concat(["delete", NotificationLogic.imageStem(row)]))
  }

  // ---------------------------------------------------- history
  //
  // A popup that leaves the screen keeps its file — it just moves one level
  // down, into historyDir. Trimming happens in the same helper job: names
  // sort by the leading millisecond timestamp, so everything but the newest
  // historyLimit files is dropped, image copies included.

  function archivePopupFileFor(row) {
    if (!row) return
    enqueuePopupFileJob(filesHelperCmd.concat([
      "archive",
      NotificationLogic.popupFileName(row),
      String(historyLimit)
    ]), function() { service.requestPanelHistory() })
  }

  // Record a notification that never made it to the screen (DND silenced it),
  // straight into history. Same file format as an archived popup, so the
  // replay can't tell the two apart.
  //
  // A silenced notification is untracked the moment it arrives, so the server
  // has nothing left for a later replaces_id to replace and hands the sender a
  // fresh id instead. Every update from a chatty thread is therefore its own
  // notification here, and several can sit in the ten slots together — there
  // is no id to recognize them by, and guessing from app and summary would
  // merge genuinely separate messages.
  function writeHistoryFile(entry, done) {
    if (!entry) {
      if (done) done()
      return
    }
    var persistable = NotificationLogic.persistablePopup(entry, imagesDir)
    var command = filesHelperCmd.concat([
      "write-history",
      NotificationLogic.popupFileName(entry),
      String(historyLimit)
    ])
    for (var i = 0; i < persistable.copies.length; i++)
      command.push(persistable.copies[i].from, persistable.copies[i].to)
    enqueuePopupFileJob(command, function() {
      service.requestPanelHistory()
      if (done) done()
    }, NotificationLogic.serializePopup(persistable.entry, NotificationUrgency.Normal))
  }

  function clearHistory() {
    enqueuePopupFileJob(filesHelperCmd.concat(["clear-history"]), function() {
      service.requestPanelHistory()
    })
  }

  // A restart can kill a queued job between its copy and its JSON write,
  // leaving copies no JSON-derived cleanup can name. Swept at startup,
  // through the queue so in-flight copies aren't mistaken for orphans.
  function sweepOrphanImages() {
    enqueuePopupFileJob(filesHelperCmd.concat(["sweep"]))
  }

  Process {
    id: readHistoryProc
    onStarted: stdoutBuf = ""

    property string stdoutBuf: ""
    running: false
    command: ["/usr/bin/python3", "-I", service.filesHelper, "read-history"]
    // Let the file queue go again, whatever the read did — a failed or empty
    // read must not leave archives and clears parked behind it forever.
    onExited: {
      var purpose = service.historyReadPurpose
      var buf = stdoutBuf
      stdoutBuf = ""
      if (purpose === "panel")
        service.applyPanelHistory(buf)
      else
        service.replayHistory(buf)
      if (service.panelHistoryStale) {
        service.panelHistoryStale = false
        service.requestPanelHistory()
      }
      service.runNextPopupFileJob()
    }
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        readHistoryProc.stdoutBuf += chunk
        if (readHistoryProc.stdoutBuf.length > 262144) {
          readHistoryProc.signal(15)
          readHistoryProc.stdoutBuf = ""
        }
      }
    }
  }

  // Toasts that were on screen when the replay was asked for. The clear in
  // replayHistory archives them, but the directory read is already in flight
  // by then, so they're handed over in memory instead of being waited for.
  property var replayCarryOver: []

  // Set from the moment a read is queued until it starts, so a second
  // showHistory while one is still waiting its turn doesn't queue another.
  property bool historyReadQueued: false
  property string historyReadPurpose: "replay"
  property bool panelHistoryReadQueued: false
  property bool panelHistoryStale: false

  // Re-show what's in historyDir as toasts. The read goes through the file
  // queue and its own subprocess, so the replay lands in replayHistory once
  // the work queued ahead of it has finished.
  function showRecentHistory() {
    if (readHistoryProc.running || service.historyReadQueued) return "ok"
    service.replayCarryOver = liveRowsForReplay()
    service.historyReadQueued = true
    enqueueHistoryRead()
    return "ok"
  }

  function startHistoryRead() {
    service.historyReadQueued = false
    service.historyReadPurpose = "replay"
    readHistoryProc.running = true
  }

  function startPanelHistoryRead() {
    service.panelHistoryReadQueued = false
    service.historyReadPurpose = "panel"
    readHistoryProc.running = true
  }

  // Reload the history panel from disk. A read already queued or in flight
  // is left to finish; panelHistoryStale asks for one more pass afterwards
  // so an archive that landed during the read is not missed.
  function requestPanelHistory() {
    if (service.panelHistoryReadQueued || readHistoryProc.running) {
      service.panelHistoryStale = true
      return
    }
    service.panelHistoryReadQueued = true
    popupFileQueue = popupFileQueue.concat([{ panel: true }])
    runNextPopupFileJob()
  }

  function applyPanelHistory(raw) {
    service.historyEntries = NotificationLogic.panelHistoryEntries(raw, service.historyLimit)
  }

  function patchHistoryEntry(key, patch) {
    var stem = String(key || "")
    var rows = service.historyEntries || []
    var next = []
    var found = null
    for (var i = 0; i < rows.length; i++) {
      var row = rows[i]
      if (!row || String(row.key) !== stem) {
        next.push(row)
        continue
      }
      found = NotificationLogic.copyPanelEntry(row, patch)
      next.push(found)
    }
    if (!found) return
    service.historyEntries = next
    var record = NotificationLogic.historyRecordFromPanel(found)
    enqueuePopupFileJob(
      filesHelperCmd.concat(["write-history", NotificationLogic.popupFileName(record), String(historyLimit)]),
      function() { service.requestPanelHistory() },
      NotificationLogic.serializeHistoryRecord(record)
    )
  }

  function hideHistoryEntry(key) {
    patchHistoryEntry(key, { hidden: true })
  }

  function unhideHistoryEntry(key) {
    patchHistoryEntry(key, { hidden: false })
  }

  function markEntryRead(key) {
    patchHistoryEntry(key, { read: true })
  }

  function markAllRead() {
    var rows = service.historyEntries || []
    var next = []
    var changed = false
    for (var i = 0; i < rows.length; i++) {
      var row = rows[i]
      if (!row || row.read === true || row.hidden === true) {
        next.push(row)
        continue
      }
      changed = true
      var updated = NotificationLogic.copyPanelEntry(row, { read: true })
      next.push(updated)
      var record = NotificationLogic.historyRecordFromPanel(updated)
      enqueuePopupFileJob(
        filesHelperCmd.concat(["write-history", NotificationLogic.popupFileName(record), String(historyLimit)]),
        null,
        NotificationLogic.serializeHistoryRecord(record)
      )
    }
    if (!changed) return
    service.historyEntries = next
    requestPanelHistory()
  }

  function removeHistoryEntry(key) {
    var stem = String(key || "")
    if (!/^[0-9]{1,16}-[0-9]{1,16}$/.test(stem)) return
    var rows = service.historyEntries || []
    var next = []
    for (var i = 0; i < rows.length; i++) {
      if (!rows[i] || String(rows[i].key) !== stem)
        next.push(rows[i])
    }
    service.historyEntries = next
    enqueuePopupFileJob(filesHelperCmd.concat(["delete-history", stem]), function() {
      service.requestPanelHistory()
    })
  }

  function openHistoryEntry(item) {
    if (!item) return
    var argv = NotificationLogic.parseExecArgv(item.execArgv || "")
    if (argv) {
      Util.execArgv(argv)
      return
    }
    focusApp(item)
  }

  // Copy the on-screen rows out of the model. The placeholder from an earlier
  // empty replay carries originalId -1 and is not a notification, so it is
  // left behind rather than replayed as one. The replay dismisses these
  // notifications, and senders delete their images on close — so the carried
  // rows point at the persisted copies, like the archived files they join.
  function liveRowsForReplay() {
    var rows = []
    for (var i = 0; i < popupModel.count; i++) {
      var row = popupModel.get(i)
      if (!row || row.originalId < 0) continue
      rows.push(NotificationLogic.persistablePopup({
        id: row.id,
        originalId: row.originalId,
        app: row.app,
        appIcon: row.appIcon,
        summary: row.summary,
        body: row.body,
        image: row.image,
        glyph: row.glyph || "",
        execArgv: row.execArgv || "",
        urgency: row.urgency,
        timestamp: row.timestamp
      }, imagesDir).entry)
    }
    return rows
  }

  function replayHistory(raw) {
    var rows = NotificationLogic.historyRows(
      raw, service.replayCarryOver, NotificationUrgency.Normal, service.historyLimit)
    service.replayCarryOver = []

    // Replaying nothing at all looks like a dead keybinding, so say so.
    if (rows.length === 0) {
      popupModel.insert(0, {
        id: -1,
        originalId: -1,
        app: "evoshell-action",
        appIcon: "",
        summary: "No recent notifications",
        body: "",
        image: "",
        glyph: "󰂚",
        execArgv: "",
        urgency: NotificationUrgency.Low,
        expireTimeout: 0,
        timestamp: Date.now()
      })
      return
    }

    clearPopups()
    // Rows arrive newest-first, and index 0 is the top of the toast stack.
    for (var i = 0; i < rows.length; i++) {
      // Replayed rows are restored rows: their notification died with the
      // sender long ago, so they must never resolve to a live server object
      // that has since been handed their old id.
      service.restoredPopups[NotificationLogic.popupFileName(rows[i])] = true
      popupModel.append(rows[i])
    }
  }

  Process {
    id: restorePopupsProc
    onStarted: stdoutBuf = ""

    property string stdoutBuf: ""
    running: false
    command: ["/usr/bin/python3", "-I", service.filesHelper, "read-popups"]
    onExited: service.restorePopups(stdoutBuf)
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        restorePopupsProc.stdoutBuf += chunk
        if (restorePopupsProc.stdoutBuf.length > 262144) {
          restorePopupsProc.signal(15)
          restorePopupsProc.stdoutBuf = ""
        }
      }
    }
  }

  function restorePopups(raw) {
    var entries = NotificationLogic.parsePopupFiles(raw, NotificationUrgency.Normal)
    var now = Date.now()
    var live = []
    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i]
      var duration = durationFor(entry.urgency, entry.expireTimeout)
      if (NotificationLogic.popupExpired(entry, duration, now)) {
        // It would have expired on screen had the shell kept running, so it
        // gets archived exactly like an expiry that happened while it did.
        archivePopupFileFor(entry)
        continue
      }
      // Survivors restart with a full lifetime on purpose: shell restarts
      // are rare, and a full look after the restart flicker beats resuming
      // a toast with a second left on its clock. The reset is persisted as
      // an absolute deadline so a second restart while the toast is still
      // on screen judges it by the reset clock, not the original timestamp.
      if (duration > 0) {
        entry.deadline = now + duration
        persistPopupFile(entry)
        // deadline is persistence metadata, not a model role — fresh rows
        // never carry it, and ListModel roles must stay consistent.
        delete entry.deadline
      }
      live.push(entry)
    }
    if (live.length === 0) return

    Qt.callLater(function() {
      for (var j = 0; j < live.length; j++) {
        var restored = live[j]
        // A notification received while the restore was reading the dir can
        // already occupy this originalId with the same timestamp — then it
        // IS this entry, live with its own file, and must be left alone. A
        // different timestamp is indistinguishable between a genuine
        // cross-restart replaces_id and a new-generation id coincidence, so
        // show both: a briefly duplicated toast beats silently dropping a
        // restored critical alert.
        var duplicate = false
        for (var k = 0; k < popupModel.count; k++) {
          var row = popupModel.get(k)
          if (row && row.originalId === restored.originalId && row.timestamp === restored.timestamp) {
            duplicate = true
            break
          }
        }
        if (duplicate) continue
        // Append (entries are newest-first) so restored toasts stack in
        // their original order below anything that just arrived. Restored
        // popups have no liveRefs entry — the server object died with the
        // old shell — so dismissal and action fallbacks degrade gracefully.
        service.restoredPopups[NotificationLogic.popupFileName(restored)] = true
        popupModel.append(restored)
      }
    })
  }

  // ---------------------------------------------------- settings persistence

  Process {
    id: settingsReadProc
    onStarted: stdoutBuf = ""
    property string stdoutBuf: ""
    command: service.filesHelperCmd.concat(["settings-read"])
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        settingsReadProc.stdoutBuf += chunk
        if (settingsReadProc.stdoutBuf.length > 65536) {
          settingsReadProc.signal(15)
          settingsReadProc.stdoutBuf = ""
        }
      }
    }
    onExited: service.loadSettings(stdoutBuf)
  }

  Process {
    id: settingsWriteProc
    stdinEnabled: true
    property string payload: ""
    command: service.filesHelperCmd.concat(["settings-write"])
    onStarted: {
      write(payload)
      payload = ""
      stdinEnabled = false
    }
    onExited: if (service.settingsDirty) service.flushSettings()
  }

  Timer {
    id: settingsSaveTimer
    interval: 200
    repeat: false
    onTriggered: service.flushSettings()
  }

  function scheduleSettingsSave() {
    if (!service.settingsLoaded) return
    settingsSaveTimer.restart()
  }

  property bool settingsLoaded: false

  function loadSettings(raw) {
    // The helper can fire more than once during startup if the read is
    // retried; ignore extra completions after the first hydrate.
    if (service.settingsLoaded) return

    var parsed = NotificationLogic.parseSettings(raw)
    if (parsed.error) console.warn("notifications: settings parse failed:", parsed.errorMessage || "")

    if (parsed.dnd !== null) {
      service._hydrating = true
      persisted.doNotDisturb = parsed.dnd
      service._hydrating = false
    }

    service.settingsLoaded = true
    // Versions before the history moved into its own directory kept every
    // notification in here. Rewrite once so that dead payload doesn't sit in
    // the file until the next DND toggle happens to clear it.
    if (parsed.legacy) service.scheduleSettingsSave()
  }

  // A toggle while the previous write is still running is saved once that
  // write exits, so the file always ends on the latest value.
  property bool settingsDirty: false

  function flushSettings() {
    if (settingsWriteProc.running) {
      settingsDirty = true
      return
    }
    settingsDirty = false
    settingsWriteProc.payload = JSON.stringify({ version: 3, dnd: persisted.doNotDisturb }, null, 2) + "\n"
    settingsWriteProc.stdinEnabled = true
    settingsWriteProc.running = true
  }

  // The helper creates the state directories itself. An empty settings read
  // (no file yet) leaves the defaults in place.
  Component.onCompleted: {
    settingsReadProc.running = true
    restorePopupsProc.running = true
    // Safe beside the restore read: it only re-persists entries whose
    // JSON exists, exactly the images the sweep keeps.
    sweepOrphanImages()
    requestPanelHistory()
  }

  // ---------------------------------------------------- IPC

  IpcHandler {
    target: "notifications"

    function dndState(): string {
      return service.doNotDisturb ? "on" : "off"
    }

    function toggleDnd(): string {
      service.setDoNotDisturb(!service.doNotDisturb)
      return dndState()
    }

    function setDnd(value: string): string {
      var v = String(value || "").toLowerCase()
      var on = v === "true" || v === "1" || v === "on" || v === "yes"
      service.setDoNotDisturb(on)
      return dndState()
    }

    function isDnd(): string {
      return dndState()
    }

    // Replay the notifications that have been moved into the history dir.
    function showHistory(): string {
      return service.showRecentHistory()
    }

    // `clear` forgets the recorded history; the toasts on screen stay put.
    function clear(): string {
      service.clearHistory()
      return "ok"
    }

    function dismissAll(): string {
      service.clearPopups()
      return "ok"
    }

    // Dismiss the most recent popup.
    function dismissOne(): string {
      if (popupModel.count === 0) return "none"
      service.dismissPopup(0)
      return "ok"
    }

    // Fire the default action on the most recent popup, then dismiss it.
    function invokeLast(): string {
      if (popupModel.count === 0) return "none"
      service.invokePopupDefault(0)
      return "ok"
    }

    // Take a toast off the screen by summary substring, used by the
    // first-run notifications once their action has been clicked.
    function dismiss(summary: string): string {
      var needle = String(summary || "")
      if (!needle) return "none"
      var hit = false
      for (var i = popupModel.count - 1; i >= 0; i--) {
        var row = popupModel.get(i)
        if (row && String(row.summary || "").indexOf(needle) !== -1) {
          service.dismissPopup(i)
          hit = true
        }
      }
      return hit ? "ok" : "none"
    }

    function ping(): string { return "ok" }
  }

  // ---------------------------------------------------- server

  NotificationServer {
    id: server
    keepOnReload: false
    imageSupported: true
    actionsSupported: true
    bodyMarkupSupported: true
    bodyHyperlinksSupported: true
    persistenceSupported: true

    onNotification: function(notification) {
      service.handleNotification(notification)
    }
  }

  // -------------------------------------------------------------- popup UI
  //
  // One PanelWindow per placed output that is connected, or the first screen
  // when none are (see LayoutModel.screensForPlacements). Layer is Overlay,
  // exclusionMode Ignore, no keyboard focus.

  // Every window shows every row, so a hover on any screen holds that row on
  // all of them. Counted by row key because two screens can hover at once.
  property var hoveredRows: ({})

  function setRowHovered(key, hovered) {
    var next = Object.assign({}, hoveredRows)
    var count = (next[key] || 0) + (hovered ? 1 : -1)
    if (count > 0) next[key] = count
    else delete next[key]
    hoveredRows = next
  }

  Variants {
    model: service.popupScreens

    PanelWindow {
      id: popupWindow
      required property var modelData
      screen: modelData

      readonly property string screenName: modelData ? String(modelData.name || "") : ""
      readonly property bool screenHasBar: service.barScreenNames.indexOf(screenName) >= 0
      readonly property var placementConfig: LayoutModel.popupPlacementForScreen(
        LayoutModel.findPlacement(service.notificationPlacements, screenName),
        screenHasBar ? service.barPosition : "",
        service.barClearance,
        Theme.popupMargin)
      readonly property int columnAlignment: {
        if (placementConfig.align === "left") return Qt.AlignLeft
        if (placementConfig.align === "center") return Qt.AlignHCenter
        return Qt.AlignRight
      }

      visible: popupModel.count > 0

      WlrLayershell.namespace: "evo-notifications"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"

      anchors { top: true; bottom: true; left: true; right: true }

      mask: Region { item: popupColumn }

      ColumnLayout {
        id: popupColumn
        spacing: Theme.space(8)

        anchors.top: placementConfig.vertical === "top" ? parent.top : undefined
        anchors.bottom: placementConfig.vertical === "bottom" ? parent.bottom : undefined
        anchors.left: placementConfig.align === "left" ? parent.left : undefined
        anchors.right: placementConfig.align === "right" ? parent.right : undefined
        anchors.horizontalCenter: placementConfig.align === "center" ? parent.horizontalCenter : undefined
        anchors.topMargin: placementConfig.margins.top
        anchors.bottomMargin: placementConfig.margins.bottom
        anchors.leftMargin: placementConfig.margins.left
        anchors.rightMargin: placementConfig.margins.right

        Repeater {
          model: popupModel

          delegate: Item {
            id: cardSlot
            required property int index
            required property string app
            required property string appIcon
            required property string summary
            required property string body
            required property string image
            required property string glyph
            required property int urgency
            required property double expireTimeout
            required property double timestamp
            required property double originalId

            Layout.preferredWidth: card.implicitWidth
            Layout.alignment: popupWindow.columnAlignment
            implicitHeight: card.implicitHeight

            readonly property string rowKey: NotificationLogic.imageStem({ timestamp: cardSlot.timestamp, originalId: cardSlot.originalId })
            readonly property real lifetime: service.durationFor(cardSlot.urgency, cardSlot.expireTimeout)
            property real remainingLifetime: 1.0
            readonly property bool ticking: cardSlot.lifetime > 0 && !service.hoveredRows[cardSlot.rowKey]
            property bool hoverCounted: false

            Component.onDestruction: if (hoverCounted) service.setRowHovered(rowKey, false)
            onSummaryChanged: cardSlot.remainingLifetime = 1.0
            onBodyChanged: cardSlot.remainingLifetime = 1.0
            onImageChanged: cardSlot.remainingLifetime = 1.0

            Timer {
              interval: 50
              repeat: true
              running: cardSlot.ticking
              onTriggered: {
                if (cardSlot.lifetime <= 0) return
                cardSlot.remainingLifetime -= 50.0 / cardSlot.lifetime
                if (cardSlot.remainingLifetime <= 0) {
                  cardSlot.remainingLifetime = 0
                  service.expirePopup(cardSlot.index)
                }
              }
            }

            NotificationCard {
              id: card
              anchors.horizontalCenter: popupWindow.columnAlignment === Qt.AlignHCenter ? parent.horizontalCenter : undefined
              anchors.left: popupWindow.columnAlignment === Qt.AlignLeft ? parent.left : undefined
              anchors.right: popupWindow.columnAlignment === Qt.AlignRight ? parent.right : undefined
              app: cardSlot.app
              appIcon: cardSlot.appIcon
              summary: cardSlot.summary
              body: cardSlot.body
              image: cardSlot.image
              urgency: cardSlot.urgency
              timestamp: cardSlot.timestamp
              cornerRadius: service.cornerRadius
              fontFamily: service.shell && service.shell.bar ? service.shell.bar.fontFamily : ""
              glyph: cardSlot.glyph

              onHoveredChanged: {
                if (hovered === cardSlot.hoverCounted) return
                cardSlot.hoverCounted = hovered
                service.setRowHovered(cardSlot.rowKey, hovered)
              }
              onCloseRequested: service.dismissPopup(cardSlot.index)
              onCardClicked: service.invokePopupDefault(cardSlot.index)
            }
          }
        }
      }
    }
  }
}
