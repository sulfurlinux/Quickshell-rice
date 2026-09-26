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

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: loadThemeProcess.running = true
    }

    Process {
        id: loadThemeProcess
        command: ["python3", "-c", "
import os, json
path = os.path.expanduser('~/.cache/quickshell_theme.json')
if os.path.exists(path):
    try:
        with open(path, 'r') as f:
            print(f.read())
    except:
        print('')
"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    let parsed = JSON.parse(data.trim())
                    if (parsed.accent) {
                        root.currentTheme = parsed
                    }
                } catch(e) {}
            }
        }
    }

    Rice.Screenshot {
        id: screenshotTool
    }

    Rice.Launcher {
        id: globalLauncher
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
                required property var modelData

                screen: modelData
                theme: root.currentTheme
                launcher: globalLauncher
                screenshot: screenshotTool
            }
        }
    }
}
