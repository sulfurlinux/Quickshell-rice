import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

Scope {
    id: root

    property var theme
    property int notificationTimeout: 5000
    property bool centerVisible: false
    property bool doNotDisturb: false
    property var history: []
    property var historyLocks: []
    readonly property int historyLimit: 100

    Component {
        id: lockComponent

        RetainableLock {}
    }

    function addToHistory(notification) {
        root.removeFromHistory(notification)
        const lock = lockComponent.createObject(root, {
            object: notification,
            locked: true
        })

        historyLocks.push({ id: notification.id, lock: lock })
        const entry = {
            notification: notification,
            receivedAt: notification.lastGeneration ? null : new Date()
        }
        history = [entry, ...history]
        while (history.length > historyLimit) {
            root.removeFromHistory(history[history.length - 1].notification)
        }
    }

    function removeFromHistory(notification) {
        history = history.filter(entry => entry.notification.id !== notification.id)

        for (let i = historyLocks.length - 1; i >= 0; --i) {
            if (historyLocks[i].id === notification.id) {
                historyLocks[i].lock.locked = false
                historyLocks[i].lock.destroy()
                historyLocks.splice(i, 1)
            }
        }
    }

    function clearHistory() {
        const entries = [...history]
        history = []

        for (const entry of entries) {
            if (entry.notification.tracked) {
                entry.notification.dismiss()
            }
        }

        for (const item of historyLocks) {
            item.lock.locked = false
            item.lock.destroy()
        }

        historyLocks = []
    }

    NotificationServer {
        id: server

        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: false
        keepOnReload: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true
            root.addToHistory(notification)
        }
    }

    PanelWindow {
        id: popupWindow
        visible: !root.doNotDisturb && popupColumn.implicitHeight > 0

        screen: Quickshell.screens.primary

        anchors {
            top: true
            right: true
        }

        margins {
            top: 52
            right: 16
        }

        implicitWidth: 380
        implicitHeight: popupColumn.implicitHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        ColumnLayout {
            id: popupColumn

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            Repeater {
                model: server.trackedNotifications

                delegate: Rectangle {
                    required property var modelData
                    property bool popupVisible: false
                    Component.onCompleted: popupVisible = !root.doNotDisturb && !modelData.lastGeneration
                    Connections {
                        target: root
                        function onDoNotDisturbChanged() {
                            if (root.doNotDisturb) popupVisible = false;
                        }
                    }

                    Layout.fillWidth: true
                    implicitHeight: popupVisible ? popupContent.implicitHeight + 24 : 0
                    radius: 10
                    color: root.theme ? root.theme.surface : "#313244"
                    border.width: 1
                    border.color: root.theme ? root.theme.accent : "#cba6f7"
                    visible: popupVisible

                    Timer {
                        interval: root.notificationTimeout
                        running: popupVisible
                        repeat: false
                        onTriggered: popupVisible = false
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onClicked: {
                            if (modelData.actions.length > 0) {
                                modelData.actions[0].invoke()
                            }
                        }
                    }

                    ColumnLayout {
                        id: popupContent

                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Image {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                source: modelData.appIcon
                                    ? Quickshell.iconPath(modelData.appIcon, "application-x-executable")
                                    : ""
                                visible: source.length > 0
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.appName
                                color: root.theme ? root.theme.subtext : "#a6adc8"
                                font.pixelSize: 12
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                color: "transparent"
                                z: 2

                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: root.theme ? root.theme.text : "#cdd6f4"
                                    font.pixelSize: 18
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: modelData.dismiss()
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.summary
                            color: root.theme ? root.theme.text : "#cdd6f4"
                            font.pixelSize: 14
                            font.bold: true
                            wrapMode: Text.Wrap
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: modelData.body
                            color: root.theme ? root.theme.text : "#cdd6f4"
                            font.pixelSize: 13
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                            maximumLineCount: 4
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        id: centerWindow

        visible: root.centerVisible
        focusable: root.centerVisible
        screen: Quickshell.screens.primary

        anchors {
            top: true
            right: true
            bottom: true
        }

        margins {
            top: 52
            right: 16
            bottom: 16
        }

        implicitWidth: 460
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: root.theme ? root.theme.background : "#1e1e2e"
            border.width: 1
            border.color: root.theme ? root.theme.accent : "#cba6f7"
            focus: root.centerVisible

            Keys.onEscapePressed: root.centerVisible = false

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Notifications"
                        color: root.theme ? root.theme.text : "#cdd6f4"
                        font.pixelSize: 20
                        font.bold: true
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Button {
                        id: dndButton
                        text: root.doNotDisturb ? "DND on" : "DND off"
                        checkable: true
                        checked: root.doNotDisturb
                        onToggled: root.doNotDisturb = checked
                        implicitWidth: implicitContentWidth + 20
                        implicitHeight: 28
                        Accessible.name: "Do not disturb"
                        ToolTip.visible: hovered
                        ToolTip.text: "Hide notification popups; keep notifications in history"

                        contentItem: Text {
                            text: dndButton.text
                            color: root.doNotDisturb
                                ? (root.theme ? root.theme.background : "#1e1e2e")
                                : (root.theme ? root.theme.text : "#cdd6f4")
                            font.pixelSize: 11
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            radius: 6
                            color: root.doNotDisturb
                                ? (root.theme ? root.theme.accent : "#cba6f7")
                                : (root.theme ? root.theme.surface : "#313244")
                            border.width: 1
                            border.color: dndButton.visualFocus || dndButton.hovered
                                ? (root.theme ? root.theme.text : "#cdd6f4") : "transparent"
                        }
                    }

                    Rectangle {
                        implicitWidth: clearText.implicitWidth + 20
                        height: 28
                        radius: 6
                        color: root.theme ? root.theme.surface : "#313244"

                        Text {
                            id: clearText
                            anchors.centerIn: parent
                            text: "Clear all"
                            color: root.theme ? root.theme.text : "#cdd6f4"
                            font.pixelSize: 11
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.clearHistory()
                        }
                    }

                    Rectangle {
                        implicitWidth: closeText.implicitWidth + 20
                        height: 28
                        radius: 6
                        color: root.theme ? root.theme.surface : "#313244"

                        Text {
                            id: closeText
                            anchors.centerIn: parent
                            text: "Close"
                            color: root.theme ? root.theme.text : "#cdd6f4"
                            font.pixelSize: 11
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.centerVisible = false
                        }
                    }
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        id: historyList

                        model: root.history
                        spacing: 8

                        delegate: Rectangle {
                            required property var modelData
                            readonly property var notification: modelData.notification

                            width: historyList.width
                            implicitHeight: historyContent.implicitHeight + 24
                            radius: 10
                            color: root.theme ? root.theme.surface : "#313244"
                            border.width: 1
                            border.color: root.theme ? root.theme.overlay : "#45475a"

                            TapHandler {
                                acceptedButtons: Qt.LeftButton
                                onTapped: {
                                    if (notification.actions.length > 0) {
                                        notification.actions[0].invoke()
                                    }
                                }
                            }

                            ColumnLayout {
                                id: historyContent

                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Image {
                                        Layout.preferredWidth: 24
                                        Layout.preferredHeight: 24
                                        source: notification.appIcon
                                            ? Quickshell.iconPath(notification.appIcon, "application-x-executable")
                                            : ""
                                        visible: source.length > 0
                                        fillMode: Image.PreserveAspectFit
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: notification.appName
                                        color: root.theme ? root.theme.subtext : "#a6adc8"
                                        font.pixelSize: 12
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: modelData.receivedAt
                                            ? Qt.formatDateTime(modelData.receivedAt, "dd MMM · HH:mm")
                                            : "Before reload"
                                        color: root.theme ? root.theme.subtext : "#a6adc8"
                                        font.pixelSize: 11
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 6
                                        color: root.theme ? root.theme.surface : "#313244"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "×"
                                            color: root.theme ? root.theme.text : "#cdd6f4"
                                            font.pixelSize: 16
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.removeFromHistory(notification)
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: notification.summary
                                    color: root.theme ? root.theme.text : "#cdd6f4"
                                    font.pixelSize: 14
                                    font.bold: true
                                    wrapMode: Text.Wrap
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: text.length > 0
                                    text: notification.body
                                    color: root.theme ? root.theme.text : "#cdd6f4"
                                    font.pixelSize: 13
                                    wrapMode: Text.Wrap
                                    textFormat: Text.PlainText
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.history.length === 0
                    text: "No notifications"
                    horizontalAlignment: Text.AlignHCenter
                    color: root.theme ? root.theme.subtext : "#a6adc8"
                    font.pixelSize: 14
                }
            }
        }
    }
}
