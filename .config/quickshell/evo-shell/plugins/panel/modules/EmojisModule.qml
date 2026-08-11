import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../../Commons"

Item {
    id: root

    property var panel: null
    property var shell: null

    readonly property var allEmojis: [
        "😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃",
        "😉", "😊", "😇", "🥰", "😍", "🤩", "😘", "😋", "😛", "😜",
        "🤪", "😝", "🤑", "🤗", "🤭", "🤫", "🤔", "🤐", "🤨", "😐",
        "😑", "😶", "😏", "😒", "🙄", "😬", "😌", "😔", "😪", "🤤",
        "😴", "😷", "🤒", "🤕", "🤢", "🤮", "🥵", "🥶", "🥴", "😵",
        "🤯", "🤠", "🥳", "🥸", "😎", "🤓", "🧐", "😕", "😟", "🙁",
        "😮", "😯", "😲", "😳", "🥺", "😦", "😧", "😨", "😰", "😥",
        "😢", "😭", "😱", "😖", "😣", "😞", "😓", "😩", "😫", "🥱",
        "😤", "😡", "😠", "🤬",
        "👋", "🤚", "🖐️", "✋", "🖖", "👌", "🤌", "🤏", "✌️", "🤞",
        "🤟", "🤘", "🤙", "👈", "👉", "👆", "👇", "☝️", "👍", "👎",
        "✊", "👊", "🤛", "🤜", "👏", "🙌", "🫶", "👐", "🙏", "✍️",
        "🤝", "💪", "🦾",
        "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔",
        "❤️‍🔥", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟", "💯",
        "✅", "❌", "⚠️", "❗", "❓", "‼️", "⁉️", "🔴", "🟠", "🟡",
        "🟢", "🔵", "🟣", "⚫", "⚪",
        "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯",
        "🦁", "🐮", "🐷", "🐸", "🐵", "🐔", "🐧", "🐦", "🦄", "🐝",
        "🦋", "🐢", "🐍", "🐙", "🦑", "🐠", "🐟", "🐬", "🐳", "🦈",
        "🌵", "🌲", "🌳", "🌴", "🌱", "🌿", "🍀", "🌷", "🌹", "🌺",
        "🌸", "🌼", "🌻", "🌞", "🌙", "⭐", "🌟", "✨", "⚡", "🔥",
        "🌈", "☀️", "☁️", "🌧️", "⛈️", "❄️", "☃️", "🌊",
        "🍏", "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🍒",
        "🍑", "🥭", "🍍", "🥥", "🍅", "🥑", "🥦", "🌶️", "🌽", "🥕",
        "🍞", "🥐", "🧀", "🥚", "🍳", "🥓", "🍗", "🍖", "🌭", "🍔",
        "🍟", "🍕", "🌮", "🌯", "🥗", "🍝", "🍜", "🍣", "🍱", "🍙",
        "🍰", "🎂", "🍪", "🍫", "🍬", "🍭", "🍿", "🥜", "☕", "🍵",
        "🧃", "🥤", "🍺", "🍻", "🥂", "🍷", "🍸",
        "⚽", "🏀", "🏈", "⚾", "🎾", "🏐", "🎱", "🏓", "🏸", "🥅",
        "🎯", "🎮", "🕹️", "🎲", "🧩", "🎭", "🎨", "🎬", "🎤", "🎧",
        "🎼", "🎹", "🥁", "🎷", "🎺", "🎸", "🎻", "🎵", "🎶", "🎉",
        "🎊", "🎁", "🎈", "🏆", "🥇", "🥈", "🥉", "🏅",
        "💻", "🖥️", "⌨️", "🖱️", "💾", "💿", "📱", "📲", "☎️", "📞",
        "📷", "📸", "📹", "🎥", "📺", "📻", "⏰", "⌛", "⏳", "🔋",
        "🔌", "💡", "🔦", "💰", "💳", "💎", "🔧", "🔨", "⚙️", "🔑",
        "🗝️", "🚪", "🛏️", "🛋️", "🚽", "🧼", "🧴", "✉️", "📧", "📦",
        "📎", "📌", "📍", "✂️", "📝", "✏️", "📚", "📖", "🔍", "🔎",
        "🔒", "🔓", "🔗", "🧲", "🧪", "🧬", "💊", "💉", "🩺", "🚀",
        "🛸", "🌍", "🌎", "🌏", "🗺️", "🧭", "⛵", "🚗", "🚕", "🚙",
        "🚌", "🚎", "🏎️", "🚓", "🚑", "🚒", "🚐", "🚚", "🚛", "🚜",
        "🚲", "🛵", "🏍️", "🚂", "✈️", "🛫", "🛬", "🚁", "🚢", "⚓",
        "🏠", "🏡", "🏢", "🏣", "🏥", "🏦", "🏨", "🏪", "🏫", "🏬"
    ]

    readonly property int gridColumns: 5
    readonly property int cellHeight: 44
    readonly property int cellSpacing: 6
    readonly property int emojiFontSize: 26
    readonly property bool active: panel && panel.opened && panel.activeModule === "emojis"

    readonly property var displayEmojis: UsageMemory.sortByUsage(
        allEmojis, "emojis", function(e) { return e }, function(e) { return e }
    )

    function pick(emoji) {
        UsageMemory.bump("emojis", emoji)
        Quickshell.execDetached(["bash", "-lc", "printf '%s' " + Util.shellQuote(emoji) + " | wl-copy"])
        if (panel) panel.dismiss()
    }

    function onActivated() {
        UsageMemory.reload()
        Qt.callLater(function() {
            if (root.active)
                focusSink.forceActiveFocus()
        })
    }

    Item {
        id: focusSink
        anchors.fill: parent
        focus: root.active
        Keys.enabled: root.active
        Keys.onEscapePressed: if (panel) panel.dismiss()

        ColumnLayout {
            anchors.fill: parent
            spacing: 10

            FramedPanel {
                label: "Emojis"
                contentFill: true
                Layout.fillWidth: true
                Layout.fillHeight: true

                Flickable {
                    id: emojiFlickable
                    anchors.fill: parent
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    contentWidth: width
                    contentHeight: emojiGrid.height

                    readonly property int cellWidth: Math.max(1, Math.floor(
                        (width - root.cellSpacing * (root.gridColumns - 1)) / root.gridColumns
                    ))

                    Grid {
                        id: emojiGrid
                        width: parent.width
                        columns: root.gridColumns
                        spacing: root.cellSpacing

                        Repeater {
                            model: root.displayEmojis

                            Item {
                                required property var modelData
                                width: emojiFlickable.cellWidth
                                height: root.cellHeight

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 4
                                    color: emojiMouse.containsMouse ? Theme.panelMantle : "transparent"
                                    border.color: emojiMouse.containsMouse ? Theme.accent : "transparent"
                                    border.width: 1
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.pixelSize: root.emojiFontSize
                                }

                                MouseArea {
                                    id: emojiMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.pick(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
