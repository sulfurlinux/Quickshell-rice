import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: wallpaperRoot
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

    readonly property string homePath: Quickshell.env("HOME")
    property string wallpaperPath: ""
    property string absoluteWallpaperPath: ""

    function applyWallpaper(p) {
        validateWallpaperProcess.exec(["python3", "-c",
            "import os,sys; p=sys.argv[1]; print(p if os.path.isfile(p) else '')", p.trim()])
    }

    FileView {
        id: wallpaperFile
        path: wallpaperRoot.homePath + "/.cache/quickshell_wallpaper.txt"
        watchChanges: true
        blockLoading: true

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

    Process {
        id: validateWallpaperProcess
        stdout: SplitParser {
            onRead: data => {
                const path = data.trim();
                if (path === wallpaperRoot.absoluteWallpaperPath) return;
                wallpaperRoot.absoluteWallpaperPath = path;
                wallpaperRoot.wallpaperPath = path ? "file://" + path : "";
                if (path) {
                    const script = decodeURIComponent(Qt.resolvedUrl("extract_color.py").toString().replace(/^file:\/\//, ""));
                    colorProcess.exec([wallpaperRoot.homePath + "/.cache/quickshell_venv/bin/python3", script, path]);
                }
            }
        }
    }

    Process {
        running: true
        command: ["python3", "-c",
            "import os
cached = ''
try:
    with open(os.path.expanduser('~/.cache/quickshell_wallpaper.txt')) as f:
        cached = f.read().strip()
except OSError:
    pass
default = os.path.expanduser('~/Pictures/Wallpapers/wallpaper.png')
print(next((p for p in (cached, default) if p and os.path.isfile(p)), ''))"]
        stdout: SplitParser {
            onRead: data => {
                if (!wallpaperRoot.absoluteWallpaperPath && !validateWallpaperProcess.running && data.trim())
                    wallpaperRoot.applyWallpaper(data);
            }
        }
    }

    Image {
        anchors.fill: parent
        source: wallpaperRoot.wallpaperPath
        fillMode: Image.PreserveAspectCrop
        smooth: true

        onStatusChanged: {
            if (status === Image.Error) {
                wallpaperRoot.wallpaperPath = ""
                wallpaperRoot.absoluteWallpaperPath = ""
            }
        }
    }
}
