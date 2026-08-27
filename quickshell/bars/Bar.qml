import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

PanelWindow {
    id: root

    property var theme
    property var launcher

    property string currentTime: "--:--"
    property string sinkVolume: "0%"
    property bool sinkMuted: false
    property string sourceVolume: "0%"
    property bool sourceMuted: false

    property bool canScrollSink: true
    property bool canScrollSource: true

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 40
    color: theme ? theme.background : "#1e1e2e"

    // Clock
    Process {
        id: timeProcess
        command: ["date", "+%H:%M"]
        stdout: SplitParser {
            onRead: data => root.currentTime = data.trim()
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: timeProcess.running = true
    }

    // Audio sink, volume and mute status of the speaker
    Process {
        id: sinkProcess
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                let text = data.trim()
                root.sinkMuted = text.includes("[MUTED]")
                let match = text.match(/([0-9.]+)/)
                if (match) {
                    let vol = Math.round(parseFloat(match[1]) * 100)
                    root.sinkVolume = vol + "%"
                }
            }
        }
    }

    // Audio source, volume and mute status of the microphone
    Process {
        id: sourceProcess
        command: ["wpctl", "get-volume", "@DEFAULT_SOURCE@"]
        stdout: SplitParser {
            onRead: data => {
                let text = data.trim()
                root.sourceMuted = text.includes("[MUTED]")
                let match = text.match(/([0-9.]+)/)
                if (match) {
                    let vol = Math.round(parseFloat(match[1]) * 100)
                    root.sourceVolume = vol + "%"
                }
            }
        }
    }

    Process { id: audioExec }

    function updateAudio() {
        sinkProcess.running = true
        sourceProcess.running = true
    }

    Timer {
        interval: 150
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateAudio()
    }

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

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.topMargin: 6
            anchors.bottomMargin: 6
            spacing: 12

            // Workspaces (left)
            Row {
                spacing: 6
                Layout.alignment: Qt.AlignLeft

                Repeater {
                    model: Hyprland.workspaces

                    Rectangle {
                        required property var modelData

                        width: 28
                        height: 28
                        radius: 6

                        color: modelData.active
                            ? (theme ? theme.accent : "#cba6f7")
                            : (theme ? theme.surface : "#313244")

                        Text {
                            anchors.centerIn: parent
                            text: modelData.id
                            color: modelData.active
                                ? (theme ? theme.background : "#1e1e2e")
                                : (theme ? theme.text : "#cdd6f4")
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: Hyprland.dispatch("workspace " + modelData.id)
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            // Clock (center)
            Text {
                text: root.currentTime
                color: theme ? theme.text : "#cdd6f4"
                font.pixelSize: 14
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Item {
                Layout.fillWidth: true
            }

            // Audio (right)
            RowLayout {
                spacing: 8
                Layout.alignment: Qt.AlignRight

                // Microphone
                Rectangle {
                    height: 28
                    implicitWidth: micRow.implicitWidth + 12
                    radius: 6
                    color: theme ? theme.surface : "#313244"

                    RowLayout {
                        id: micRow
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: root.sourceMuted ? "M" : "MIC"
                            font.pixelSize: 11
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
                        onWheel: (wheel) => {
                            if (!root.canScrollSource) return;
                            root.canScrollSource = false;
                            sourceScrollTimer.start();

                            let arg = wheel.angleDelta.y > 0 ? "5%+" : "5%-";
                            audioExec.command = ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_SOURCE@", arg];
                            audioExec.running = true;
                            root.updateAudio();
                        }
                        onClicked: {
                            audioExec.command = ["wpctl", "set-mute", "@DEFAULT_SOURCE@", "toggle"];
                            audioExec.running = true;
                            root.updateAudio();
                        }
                    }
                }

                // Speaker
                Rectangle {
                    height: 28
                    implicitWidth: sinkRow.implicitWidth + 12
                    radius: 6
                    color: theme ? theme.surface : "#313244"

                    RowLayout {
                        id: sinkRow
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: root.sinkMuted ? "M" : "VOL"
                            font.pixelSize: 11
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
                        onWheel: (wheel) => {
                            if (!root.canScrollSink) return;
                            root.canScrollSink = false;
                            sinkScrollTimer.start();

                            let arg = wheel.angleDelta.y > 0 ? "5%+" : "5%-";
                            audioExec.command = ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", arg];
                            audioExec.running = true;
                            root.updateAudio();
                        }
                        onClicked: {
                            audioExec.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"];
                            audioExec.running = true;
                            root.updateAudio();
                        }
                    }
                }
            }
        }
    }
}
