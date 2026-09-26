import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: wallpaperRoot
    property string wallpaperSource: ""
    property size decodeSize: Qt.size(1920, 1080)
    property int transitionDuration: 350
    property bool firstActive: true

    onWallpaperSourceChanged: Qt.callLater(loadRequestedWallpaper)
    Component.onCompleted: loadRequestedWallpaper()

    function loadRequestedWallpaper() {
        if (crossfade.running || !wallpaperSource) return;
        const current = firstActive ? firstImage : secondImage;
        const next = firstActive ? secondImage : firstImage;
        if (current.source.toString() === wallpaperSource) {
            next.source = "";
            return;
        }
        next.opacity = 0;
        next.source = wallpaperSource;
        imageReady(next);
    }

    function imageReady(image) {
        const current = firstActive ? firstImage : secondImage;
        const next = firstActive ? secondImage : firstImage;
        if (image !== next || crossfade.running
            || image.source.toString() !== wallpaperSource) return;
        if (image.status === Image.Error) {
            console.warn("Wallpaper: cannot load " + image.source);
            image.source = "";
            return;
        }
        if (image.status !== Image.Ready) return;
        if (!current.source.toString()) {
            image.opacity = 1;
            firstActive = !firstActive;
            return;
        }
        crossfade.target = image;
        crossfade.start();
    }

    NumberAnimation {
        id: crossfade
        property: "opacity"
        from: 0
        to: 1
        duration: wallpaperRoot.transitionDuration
        easing.type: Easing.InOutCubic
        onFinished: {
            const previous = wallpaperRoot.firstActive ? firstImage : secondImage;
            previous.opacity = 0;
            previous.source = "";
            wallpaperRoot.firstActive = !wallpaperRoot.firstActive;
            wallpaperRoot.loadRequestedWallpaper();
        }
    }
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
        id: firstImage
        anchors.fill: parent
        z: wallpaperRoot.firstActive ? 0 : 1
        opacity: 0
        asynchronous: true
        cache: true
        sourceSize: wallpaperRoot.decodeSize
        fillMode: Image.PreserveAspectCrop
        smooth: true
        onStatusChanged: wallpaperRoot.imageReady(firstImage)
    }
    Image {
        id: secondImage
        anchors.fill: parent
        z: wallpaperRoot.firstActive ? 1 : 0
        opacity: 0
        asynchronous: true
        cache: true
        sourceSize: wallpaperRoot.decodeSize
        fillMode: Image.PreserveAspectCrop
        smooth: true
        onStatusChanged: wallpaperRoot.imageReady(secondImage)
    }
}
