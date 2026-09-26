import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: wallpaperRoot
    property string wallpaperSource: ""
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
        fillMode: Image.PreserveAspectCrop
        smooth: true
    }
}