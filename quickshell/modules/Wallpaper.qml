import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: wallpaperRoot
    property string wallpaperSource: ""
    property size decodeSize: Qt.size(1920, 1080)
    visible: true
    color: "#1e1e2e"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    Image {
        anchors.fill: parent
        source: wallpaperRoot.wallpaperSource
        asynchronous: true
        cache: true
        sourceSize: wallpaperRoot.decodeSize
        fillMode: Image.PreserveAspectCrop
        smooth: true
    }
}
