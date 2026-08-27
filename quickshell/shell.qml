import Quickshell
import Quickshell.Io
import QtQuick
import "."
import "./bars"

Scope {
    id: root

    // Config-Toggle
    property bool showOnAllScreens: true
    property string primaryMonitorName: "DP-1"

    // Zentrales, dynamisches Theme-Objekt mit Fallback-Farben
    property var currentTheme: {
        "background": "#1e1e2e",
        "surface": "#313244",
        "text": "#cdd6f4",
        "subtext": "#a6adc8",
        "accent": "#cba6f7"
    }

    // Timer, der regelmäßig prüft, ob ein neues Wallpaper-Theme geschrieben wurde
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

    // Instanziere den Launcher einmal zentral und übergebe das dynamische Theme
    Launcher {
        id: globalLauncher
        theme: root.currentTheme
    }

    // IPC-Handler für den Hotkey
    IpcHandler {
        target: "launcher"

        function toggle(): void {
            globalLauncher.visible = !globalLauncher.visible
        }
    }

    // --- WALLPAPER AUF ALLEN/GEWÄHLTEN MONITOREN ---
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

    // --- BAR AUF ALLEN/GEWÄHLTEN MONITOREN ---
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
