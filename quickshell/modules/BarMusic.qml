import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property var theme
    property var services
    readonly property var player: services ? services.player : null
    visible: player !== null
    implicitHeight: 28
    implicitWidth: 300
    radius: 6
    color: theme ? theme.surface : "#313244"
    Behavior on color { enabled: root.visible; ColorAnimation { duration: 180 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 8
        spacing: 2
        BarButton {
            theme: root.theme
            label: "󰒮"
            enabled: root.player !== null && root.player.canGoPrevious
            onClicked: if (root.player && root.player.canGoPrevious) root.player.previous()
        }
        BarButton {
            theme: root.theme
            label: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
            enabled: root.player !== null && root.player.canTogglePlaying
            onClicked: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying()
        }
        BarButton {
            theme: root.theme
            label: "󰒭"
            enabled: root.player !== null && root.player.canGoNext
            onClicked: if (root.player && root.player.canGoNext) root.player.next()
        }
        Text {
            id: track
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.leftMargin: 4
            text: root.player ? (root.player.trackTitle || root.player.identity)
                + (root.player.trackArtist ? " — " + root.player.trackArtist : "") : ""
            color: root.theme ? root.theme.text : "#cdd6f4"
            font.pixelSize: 12
            elide: Text.ElideRight
            MouseArea {
                id: trackPointer
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) root.services.cyclePlayer();
                    else if (root.player && root.player.canRaise) root.player.raise();
                }
            }
        }
    }
}
