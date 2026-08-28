import Quickshell
import Quickshell.Io
import QtQuick
import "."
import "./bars"

Scope {
    id: root

    // Config toggle
    property bool showOnAllScreens: true
    property string primaryMonitorName: "DP-1"

    // Central dynamic theme object with fallback colors
    property var currentTheme: {
        "background": "#1e1e2e",
        "surface": "#313244",
        "text": "#cdd6f4",
        "subtext": "#a6adc8",
        "accent": "#cba6f7"
    }

    // Timer that regularly checks whether a new wallpaper theme has been written
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

    // Instantiate the launcher once centrally and pass the dynamic theme to it
    Launcher {
        id: globalLauncher
        theme: root.currentTheme
    }

    // IPC handler for the hotkey
    IpcHandler {
        target: "launcher"

        function toggle(): void {
            globalLauncher.visible = !globalLauncher.visible
        }
    }

    // --- WALLPAPER ON ALL/SELECTED MONITORS ---
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

    // --- BAR ON ALL/SELECTED MONITORS ---
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
            }
        }
    }
}
