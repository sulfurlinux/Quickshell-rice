import Quickshell
import Quickshell.Io
import QtQuick
import "."
import "./bars"
import "./notifications"

Scope {
    id: root

    property bool showOnAllScreens: true
    property string primaryMonitorName: "DP-1"

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

    Screenshot {
        id: screenshotTool
    }

    Launcher {
        id: globalLauncher
        theme: root.currentTheme
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            globalLauncher.visible = !globalLauncher.visible
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
    }

    Notifications {
        theme: root.currentTheme
    }

    Variants {
        model: showOnAllScreens
            ? Quickshell.screens
            : [Quickshell.screens.find(s => s.name === primaryMonitorName) ?? Quickshell.screens.primary]

        delegate: Component {
            Wallpaper {
                required property var modelData
                screen: modelData
            }
        }
    }

    Variants {
        model: showOnAllScreens
            ? Quickshell.screens
            : [Quickshell.screens.find(s => s.name === primaryMonitorName) ?? Quickshell.screens.primary]

        delegate: Component {
            Bar {
                required property var modelData

                screen: modelData
                theme: root.currentTheme
                launcher: globalLauncher
                screenshot: screenshotTool
            }
        }
    }
}
