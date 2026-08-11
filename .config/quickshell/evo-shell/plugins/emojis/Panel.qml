import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../Commons"

Item {
    id: root

    property var shell: null
    property bool opened: false

    readonly property var allEmojis: [
        // faces
        "😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃",
        "😉", "😊", "😇", "🥰", "😍", "🤩", "😘", "😋", "😛", "😜",
        "🤪", "😝", "🤑", "🤗", "🤭", "🤫", "🤔", "🤐", "🤨", "😐",
        "😑", "😶", "😏", "😒", "🙄", "😬", "😌", "😔", "😪", "🤤",
        "😴", "😷", "🤒", "🤕", "🤢", "🤮", "🥵", "🥶", "🥴", "😵",
        "🤯", "🤠", "🥳", "🥸", "😎", "🤓", "🧐", "😕", "😟", "🙁",
        "😮", "😯", "😲", "😳", "🥺", "😦", "😧", "😨", "😰", "😥",
        "😢", "😭", "😱", "😖", "😣", "😞", "😓", "😩", "😫", "🥱",
        "😤", "😡", "😠", "🤬",
        // hands
        "👋", "🤚", "🖐️", "✋", "🖖", "👌", "🤌", "🤏", "✌️", "🤞",
        "🤟", "🤘", "🤙", "👈", "👉", "👆", "👇", "☝️", "👍", "👎",
        "✊", "👊", "🤛", "🤜", "👏", "🙌", "🫶", "👐", "🙏", "✍️",
        "🤝", "💪", "🦾",
        // hearts & symbols
        "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔",
        "❤️‍🔥", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟", "💯",
        "✅", "❌", "⚠️", "❗", "❓", "‼️", "⁉️", "🔴", "🟠", "🟡",
        "🟢", "🔵", "🟣", "⚫", "⚪",
        // nature & weather
        "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯",
        "🦁", "🐮", "🐷", "🐸", "🐵", "🐔", "🐧", "🐦", "🦄", "🐝",
        "🦋", "🐢", "🐍", "🐙", "🦑", "🐠", "🐟", "🐬", "🐳", "🦈",
        "🌵", "🌲", "🌳", "🌴", "🌱", "🌿", "🍀", "🌷", "🌹", "🌺",
        "🌸", "🌼", "🌻", "🌞", "🌙", "⭐", "🌟", "✨", "⚡", "🔥",
        "🌈", "☀️", "☁️", "🌧️", "⛈️", "❄️", "☃️", "🌊",
        // food & drink
        "🍏", "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🍒",
        "🍑", "🥭", "🍍", "🥥", "🍅", "🥑", "🥦", "🌶️", "🌽", "🥕",
        "🍞", "🥐", "🧀", "🥚", "🍳", "🥓", "🍗", "🍖", "🌭", "🍔",
        "🍟", "🍕", "🌮", "🌯", "🥗", "🍝", "🍜", "🍣", "🍱", "🍙",
        "🍰", "🎂", "🍪", "🍫", "🍬", "🍭", "🍿", "🥜", "☕", "🍵",
        "🧃", "🥤", "🍺", "🍻", "🥂", "🍷", "🍸",
        // activities
        "⚽", "🏀", "🏈", "⚾", "🎾", "🏐", "🎱", "🏓", "🏸", "🥅",
        "🎯", "🎮", "🕹️", "🎲", "🧩", "🎭", "🎨", "🎬", "🎤", "🎧",
        "🎼", "🎹", "🥁", "🎷", "🎺", "🎸", "🎻", "🎵", "🎶", "🎉",
        "🎊", "🎁", "🎈", "🏆", "🥇", "🥈", "🥉", "🏅",
        // tech & office
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

    readonly property int gridColumns: 8
    readonly property int cellHeight: 48
    readonly property int cellSpacing: 6
    readonly property int emojiFontSize: 30

    readonly property var displayEmojis: UsageMemory.sortByUsage(
        allEmojis, "emojis", function(e) { return e }, function(e) { return e }
    )

    function open(payloadJson) {
        UsageMemory.reload()
        opened = true
    }

    function close() {
        opened = false
    }

    function dismiss() {
        if (shell) shell.hide("evo.emojis")
        else close()
    }

    function pick(emoji) {
        UsageMemory.bump("emojis", emoji)
        Quickshell.execDetached(["bash", "-lc", "printf '%s' " + Util.shellQuote(emoji) + " | wl-copy"])
        dismiss()
    }

    PanelWindow {
        visible: root.opened
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.namespace: "evo-emojis"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Shortcut {
            sequence: "Escape"
            enabled: root.opened
            context: Qt.ApplicationShortcut
            onActivated: root.dismiss()
        }

        Rectangle {
            anchors.centerIn: parent
            width: 520
            height: 400
            color: Theme.background
            border.color: Theme.accent

            Flickable {
                id: emojiFlickable
                anchors.fill: parent
                anchors.margins: 12
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                contentHeight: emojiGrid.height

                readonly property int cellWidth: Math.floor(
                    (width - root.cellSpacing * (root.gridColumns - 1)) / root.gridColumns
                )

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

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: root.emojiFontSize
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.pick(modelData)
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: root.dismiss()
        }
    }
}
