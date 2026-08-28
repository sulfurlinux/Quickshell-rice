import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: wallpaperRoot
    visible: true

    color: "#000000" // Verhindert den "Flashbang" beim Start

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property string wallpaperPath: "file:///home/sulfur/Pictures/Wallpapers/wallpaper.png"
    property string absoluteWallpaperPath: "/home/sulfur/Pictures/Wallpapers/wallpaper.png"

    function applyWallpaper(p) {
        let trimmedPath = p.trim()
        if (trimmedPath !== "" && wallpaperRoot.absoluteWallpaperPath !== trimmedPath) {
            wallpaperRoot.absoluteWallpaperPath = trimmedPath
            wallpaperRoot.wallpaperPath = "file://" + trimmedPath

            let scriptPath = Qt.resolvedUrl("extract_color.py").toString().replace("file://", "")
            colorProcess.command = ["/home/sulfur/.cache/quickshell_venv/bin/python3", scriptPath, trimmedPath]
            colorProcess.running = true
        }
    }

    FileView {
        id: wallpaperFile
        path: "/home/sulfur/.cache/quickshell_wallpaper.txt"
        watchChanges: true
        blockLoading: true

        onLoaded: {
            let content = wallpaperFile.text()
            if (content) {
                wallpaperRoot.applyWallpaper(content)
            }
        }

        onFileChanged: {
            wallpaperFile.reload()
            let content = wallpaperFile.text()
            if (content) {
                wallpaperRoot.applyWallpaper(content)
            }
        }
    }

    Process {
        id: colorProcess
    }

    Image {
        anchors.fill: parent
        source: wallpaperRoot.wallpaperPath
        fillMode: Image.PreserveAspectCrop
        smooth: true

        onStatusChanged: {
            if (status === Image.Error) {
                console.log("Encountered Error while loading the Wallpaper: " + wallpaperRoot.wallpaperPath)
            }
        }
    }
}
