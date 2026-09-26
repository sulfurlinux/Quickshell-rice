import Quickshell
import Quickshell.Io
import QtQuick
import "./modules" as Rice

Scope {
    id: root

    property bool showOnAllScreens: true
    property string primaryMonitorName: "DP-1"
    readonly property var primaryScreen: Quickshell.screens.find(s => s.name === primaryMonitorName)
        ?? Quickshell.screens[0] ?? null

    property var currentTheme: {
        "background": "#1e1e2e",
        "surface": "#313244",
        "text": "#cdd6f4",
        "subtext": "#a6adc8",
        "accent": "#cba6f7"
    }

    property string selectedWallpaper: ""
    property string wallpaperSource: ""
    property bool wallpaperSelectionRequested: false
    property string requestedWallpaper: ""
    readonly property string wallpaperScript: decodeURIComponent(
        Qt.resolvedUrl("modules/wallpaper.py").toString().replace(/^file:\/\//, ""))
    readonly property string colorScript: decodeURIComponent(
        Qt.resolvedUrl("modules/extract_color.py").toString().replace(/^file:\/\//, ""))

    function applyWallpaperResult(data) {
        try {
            const result = JSON.parse(data);
            if (root.wallpaperSelectionRequested && result.request !== root.requestedWallpaper) return;
            root.selectedWallpaper = result.path;
            root.wallpaperSource = result.source;
            if (result.path) colorProcess.exec([
                Quickshell.env("HOME") + "/.cache/quickshell_venv/bin/python3",
                root.colorScript, result.path
            ].concat(root.wallpaperSelectionRequested ? ["--selected"] : []));
        } catch (error) { console.warn("Wallpaper: " + error); }
    }

    Process {
        running: true
        command: ["python3", root.wallpaperScript, "restore"]
        stdout: SplitParser {
            onRead: data => {
                if (!root.wallpaperSelectionRequested) root.applyWallpaperResult(data);
            }
        }
        stderr: SplitParser { onRead: data => console.warn("Wallpaper: " + data) }
    }

    Process {
        id: selectWallpaperProcess
        stdout: SplitParser { onRead: data => root.applyWallpaperResult(data) }
        stderr: SplitParser { onRead: data => console.warn("Wallpaper selection: " + data) }
    }

    Process {
        id: colorProcess
        stdout: SplitParser {
            onRead: data => {
                try {
                    const result = JSON.parse(data);
                    if (result.wallpaper === root.selectedWallpaper && result.theme.accent)
                        root.currentTheme = result.theme;
                } catch (error) { console.warn("Wallpaper theme: " + error); }
            }
        }
        stderr: SplitParser { onRead: data => console.warn("Wallpaper theme: " + data) }
    }

    Rice.Screenshot {
        id: screenshotTool
    }

    Rice.BarServices { id: barServices }

    Rice.Launcher {
        id: globalLauncher
        onWallpaperSelected: path => {
            root.wallpaperSelectionRequested = true;
            root.requestedWallpaper = path;
            root.selectedWallpaper = "";
            colorProcess.running = false;
            selectWallpaperProcess.exec(["python3", root.wallpaperScript, "select", path]);
        }
        theme: root.currentTheme
    }

    Process {
        command: ["wl-paste", "--type", "text", "--watch", "cliphist", "store"]
        running: true
        stderr: SplitParser {
            onRead: data => console.warn("Clipboard text recorder: " + data)
        }
        onExited: (exitCode, exitStatus) => {
            console.warn("Clipboard text recorder stopped (exit " + exitCode + ")")
        }
    }

    Process {
        command: ["wl-paste", "--type", "image", "--watch", "cliphist", "store"]
        running: true
        stderr: SplitParser {
            onRead: data => console.warn("Clipboard image recorder: " + data)
        }
        onExited: (exitCode, exitStatus) => {
            console.warn("Clipboard image recorder stopped (exit " + exitCode + ")")
        }
    }

    Rice.Notifications {
        id: notificationCenter
        theme: root.currentTheme
        targetScreen: root.primaryScreen
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            globalLauncher.visible = !globalLauncher.visible
        }

        function clipboard(): void {
            globalLauncher.openClipboard()
        }
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void {
            notificationCenter.centerVisible = !notificationCenter.centerVisible
        }

        function close(): void {
            notificationCenter.centerVisible = false
        }
    }

    IpcHandler {
        target: "screenshot"

        function select(): void {
            screenshotTool.selectArea()
        }

        function full(): void {
            screenshotTool.fullScreen()
        }

        function copy(): void {
            screenshotTool.selectAreaClipboard()
        }

        function copyFull(): void {
            screenshotTool.fullScreenClipboard()
        }

        function selectAndCopy(): void {
            screenshotTool.selectAreaSaveAndCopy()
        }
    }

    Variants {
        model: showOnAllScreens
            ? Quickshell.screens
            : (primaryScreen ? [primaryScreen] : [])

        delegate: Component {
            Rice.Wallpaper {
                wallpaperSource: root.wallpaperSource
                required property var modelData
                screen: modelData
            }
        }
    }

    Variants {
        model: showOnAllScreens
            ? Quickshell.screens
            : (primaryScreen ? [primaryScreen] : [])

        delegate: Component {
            Rice.Bar {
                services: barServices
                required property var modelData

                screen: modelData
                theme: root.currentTheme
                launcher: globalLauncher
                screenshot: screenshotTool
            }
        }
    }
}
