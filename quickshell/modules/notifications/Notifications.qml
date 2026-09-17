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
    property var history: []
    property var historyLocks: []
    readonly property int historyLimit: 100

    screen: Quickshell.screens.primary

    Component {
        id: lockComponent

        RetainableLock {}
    }

    function addToHistory(notification) {
        const lock = lockComponent.createObject(root, {
            object: notification,
            locked: true
        })

        historyLocks.push({ id: notification.id, lock: lock })
        history = [notification, ...history].slice(0, historyLimit)
    }

    function removeFromHistory(notification) {
        history = history.filter(entry => entry.id !== notification.id)

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
            if (entry.tracked) {
                entry.dismiss()
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

                    Layout.fillWidth: true
                    implicitHeight: popupContent.implicitHeight + 24
                    radius: 10
                    color: root.theme ? root.theme.surface : "#313244"
                    border.width: 1
                    border.color: root.theme ? root.theme.accent : "#cba6f7"

                    Timer {
                        interval: root.notificationTimeout
                        running: true
                        repeat: false
                        onTriggered: modelData.expire()
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

                    Item { Layout.fillWidth: true }

                    Text {
                        text: root.history.length > 0
                            ? root.history.length + " stored"
                            : "No notifications"
                        color: root.theme ? root.theme.subtext : "#a6adc8"
                        font.pixelSize: 12
                    }

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 30
                        radius: 8
                        color: root.theme ? root.theme.surface : "#313244"
                        visible: root.history.length > 0

                        Text {
                            anchors.centerIn: parent
                            text: "Clear all"
                            color: root.theme ? root.theme.text : "#cdd6f4"
                            font.pixelSize: 12
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.clearHistory()
                        }
                    }
                }

                ListView {
                    id: historyView

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: ScriptModel {
                        values: root.history
                        objectProp: "id"
                    }

                    delegate: Rectangle {
                        required property var modelData

                        width: historyView.width
                        implicitHeight: historyContent.implicitHeight + 24
                        radius: 10
                        color: root.theme ? root.theme.surface : "#313244"
                        border.width: 1
                        border.color: root.theme ? root.theme.accent : "#cba6f7"

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            onClicked: {
                                if (modelData.tracked && modelData.actions.length > 0) {
                                    modelData.actions[0].invoke()
                                }
                            }
                        }

                        ColumnLayout {
                            id: historyContent

                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 5

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Image {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
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

                                Text {
                                    text: modelData.tracked ? "Active" : ""
                                    color: root.theme ? root.theme.accent : "#cba6f7"
                                    font.pixelSize: 11
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
                                        onClicked: root.removeFromHistory(modelData)
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.summary
                                color: root.theme ? root.theme.text : "#cdd6f4"
                                font.pixelSize: 15
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
                            }
                        }
                    }
                }
            }
        }
    }
}
