import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

PanelWindow {
    id: root

    property var theme
    property var launcher
    property var screenshot
    property var services

    readonly property string currentTime: services ? services.currentTime : "--:--"
    readonly property var sinkAudio: services ? services.sinkAudio : null
    readonly property var sourceAudio: services ? services.sourceAudio : null
    readonly property string sinkVolume: sinkAudio ? Math.round(sinkAudio.volume * 100) + "%" : "--"
    readonly property bool sinkMuted: sinkAudio ? sinkAudio.muted : false
    readonly property string sourceVolume: sourceAudio ? Math.round(sourceAudio.volume * 100) + "%" : "--"
    readonly property bool sourceMuted: sourceAudio ? sourceAudio.muted : false

    property bool canScrollSink: true
    property bool canScrollSource: true

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 40
    color: theme ? theme.background : "#1e1e2e"

    Timer {
        id: sinkScrollTimer
        interval: 125
        repeat: false
        onTriggered: root.canScrollSink = true
    }

    Timer {
        id: sourceScrollTimer
        interval: 125
        repeat: false
        onTriggered: root.canScrollSource = true
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Text {
            id: clock
            anchors.centerIn: parent
            text: root.currentTime
            color: root.theme ? root.theme.text : "#cdd6f4"
            font.pixelSize: 15
            font.bold: true
        }

        Flickable {
            id: workspaces
            anchors.left: parent.left
            width: Math.max(0, Math.min(workspaceRow.width, clock.x - resources.implicitWidth - 46))
            anchors.leftMargin: 10

            anchors.verticalCenter: parent.verticalCenter
            height: 28
            contentWidth: workspaceRow.width
            contentHeight: 28
            clip: true
            interactive: contentWidth > width
            boundsBehavior: Flickable.StopAtBounds
            Row {
                spacing: 6
                id: workspaceRow

                Repeater {
                    model: Hyprland.workspaces

                    Rectangle {
                        required property var modelData

                        width: Math.max(28, workspaceLabel.implicitWidth + 16)
                        height: 28
                        radius: 6

                        color: modelData.active
                            ? (theme ? theme.accent : "#cba6f7")
                            : (theme ? theme.surface : "#313244")

                        Text {
                            id: workspaceLabel
                            anchors.centerIn: parent
                            text: {
                                let name = modelData.name || ""

                                if (name.startsWith("special:")) {
                                    let scratchpadName = name.slice(8)
                                    return scratchpadName.charAt(0).toUpperCase() + scratchpadName.slice(1)
                                }

                                return modelData.id
                            }
                            color: modelData.active
                                ? (theme ? theme.background : "#1e1e2e")
                                : (theme ? theme.text : "#cdd6f4")
                            font.pixelSize: 13
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: modelData.activate()
                        }
                    }
                }
            }

        }

        Item {
            anchors.left: workspaces.right
            anchors.right: clock.left
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            clip: true
            BarResources {
                id: resources
                anchors.centerIn: parent
                theme: root.theme
                services: root.services
            }
        }

        Item {
            id: musicSpace
            anchors.left: clock.right
            anchors.right: audioControls.left
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            clip: true

            RowLayout {
                anchors.centerIn: parent
                width: Math.max(0, Math.min(parent.width - 16,
                    (music.visible ? 300 : 0) + (spectrum.visible ? 70 : 0)
                    + (music.visible && spectrum.visible ? 8 : 0)))
                height: 28
                spacing: 8

                BarMusic {
                    id: music
                    theme: root.theme
                    services: root.services
                    Layout.fillWidth: true
                    Layout.minimumWidth: 100
                    Layout.maximumWidth: 300
                }

                BarSpectrum {
                    id: spectrum
                    theme: root.theme
                    services: root.services
                    visible: musicSpace.width >= 220 && root.services && root.services.cavaAvailable
                }
            }
        }

        RowLayout {
            id: audioControls
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Rectangle {
                implicitHeight: 28
                implicitWidth: micRow.implicitWidth + 12
                radius: 6
                color: theme ? theme.surface : "#313244"

                RowLayout {
                    id: micRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: root.sourceMuted ? "" : ""
                        font.pixelSize: 16
                        font.bold: true
                        color: theme ? theme.text : "#cdd6f4"
                    }

                    Text {
                        text: root.sourceVolume
                        color: theme ? theme.text : "#cdd6f4"
                        font.pixelSize: 12
                        font.bold: true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.sourceAudio !== null
                    onWheel: (wheel) => {
                        if (!root.canScrollSource || wheel.angleDelta.y === 0) return;
                        root.canScrollSource = false;
                        sourceScrollTimer.start();

                        root.services.changeVolume(true, wheel.angleDelta.y > 0 ? 0.05 : -0.05);
                    }
                    onClicked: {
                        root.services.toggleMuted(true);
                    }
                }
            }

            Rectangle {
                implicitHeight: 28
                implicitWidth: sinkRow.implicitWidth + 12
                radius: 6
                color: theme ? theme.surface : "#313244"

                RowLayout {
                    id: sinkRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: root.sinkMuted ? "" : ""
                        font.pixelSize: 16
                        font.bold: true
                        color: theme ? theme.text : "#cdd6f4"
                    }

                    Text {
                        text: root.sinkVolume
                        color: theme ? theme.text : "#cdd6f4"
                        font.pixelSize: 12
                        font.bold: true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.sinkAudio !== null
                    onWheel: (wheel) => {
                        if (!root.canScrollSink || wheel.angleDelta.y === 0) return;
                        root.canScrollSink = false;
                        sinkScrollTimer.start();

                        root.services.changeVolume(false, wheel.angleDelta.y > 0 ? 0.05 : -0.05);
                    }
                    onClicked: {
                        root.services.toggleMuted(false);
                    }
                }
            }
        }
    }
}
