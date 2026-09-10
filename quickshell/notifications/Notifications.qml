import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

PanelWindow {
    id: root

    property var theme
    property int notificationTimeout: 5000

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
    implicitHeight: notificationColumn.implicitHeight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    NotificationServer {
        id: server

        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: false
        keepOnReload: false

        onNotification: notification => {
            notification.tracked = true
        }
    }

    ColumnLayout {
        id: notificationColumn

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        Repeater {
            model: server.trackedNotifications

            delegate: Rectangle {
                required property var modelData

                Layout.fillWidth: true
                implicitHeight: contentColumn.implicitHeight + 24
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

                ColumnLayout {
                    id: contentColumn

                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

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

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: root.theme ? root.theme.text : "#cdd6f4"
                                font.pixelSize: 18
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    mouse.accepted = true
                                    modelData.dismiss()
                                }
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

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    z: -1
                    onClicked: modelData.actions.length > 0
                        ? modelData.actions[0].invoke()
                        : undefined
                }
            }
        }
    }
}
