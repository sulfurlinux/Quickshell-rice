import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property var theme
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    property var allApps: []
    property var appHistory: {}

    property var systemCommands: [
        { name: "/reboot", exec: "systemctl reboot", desc: "System neu starten" },
        { name: "/shutdown", exec: "systemctl poweroff", desc: "PC herunterfahren" },
        { name: "/lock", exec: "hyprlock", desc: "Bildschirm sperren" },
        { name: "/logout", exec: "loginctl terminate-user $USER", desc: "Aus Session abmelden" },
        { name: "/wallpaper", exec: "list_wallpapers", desc: "Wallpaper auswählen" }
    ]

    ListModel {
        id: appListModel
    }

    Process { id: execProcess }
    Process { id: saveHistoryProcess }

    function resetScroll() {
        if (appList.count > 0) {
            appList.currentIndex = 0
            appList.positionViewAtIndex(0, ListView.Beginning)
        }
    }

    Process {
        id: loadHistoryProcess
        command: ["python3", "-c", "
import json, os
path = os.path.expanduser('~/.cache/quickshell_app_history.json')
if os.path.exists(path):
    try:
        with open(path, 'r') as f:
            print(f.read())
    except:
        print('{}')
else:
    print('{}')
"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.appHistory = JSON.parse(data.trim())
                } catch(e) {
                    root.appHistory = {}
                }
            }
        }
    }

    Process {
        id: loadAppsProcess
        command: ["python3", "-c", "
import glob, configparser, json, os

files = glob.glob('/usr/share/applications/*.desktop') + glob.glob(os.path.expanduser('~/.local/share/applications/*.desktop'))
apps = {}

for f in files:
    try:
        cp = configparser.ConfigParser(interpolation=None)
        cp.read(f, encoding='utf-8')
        if 'Desktop Entry' in cp:
            e = cp['Desktop Entry']
            if e.get('NoDisplay') != 'true' and e.get('Type') == 'Application':
                name = e.get('Name')
                cmd = e.get('Exec')
                if name and cmd:
                    clean_cmd = ' '.join([w for w in cmd.split() if not w.startswith('%')])
                    apps[name] = clean_cmd
    except Exception:
        pass

res = [{'name': k, 'exec': v} for k, v in sorted(apps.items())]
print(json.dumps(res))
"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.allApps = JSON.parse(data)
                    root.filterApps()
                } catch(e) {}
            }
        }
    }

    Process {
        id: loadWallpapersProcess
        command: ["python3", "-c", "
import os, json
path = os.path.expanduser('~/Pictures/Wallpapers')
images = []
if os.path.exists(path):
    valid_exts = ('.png', '.jpg', '.jpeg', '.webp')
    images = [f for f in os.listdir(path) if f.lower().endswith(valid_exts)]
res = [{'name': img, 'path': 'file://' + os.path.join(path, img), 'exec': 'wallpaper_select:' + os.path.join(path, img)} for img in sorted(images)]
print(json.dumps(res))
"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    let wallpapers = JSON.parse(data)
                    appListModel.clear()
                    for (let i = 0; i < wallpapers.length; i++) {
                        appListModel.append({
                            name: wallpapers[i].name,
                            path: wallpapers[i].path,
                            exec: wallpapers[i].exec,
                            count: 0
                        })
                    }
                    root.resetScroll()
                } catch(e) {}
            }
        }
    }

    function filterApps() {
        appListModel.clear()
        let query = searchInput.text.toLowerCase().trim()

        let matched = []

        if (query.startsWith("/wallpaper")) {
            loadWallpapersProcess.running = true
            return;
        } else if (query.startsWith("/")) {
            for (let i = 0; i < systemCommands.length; i++) {
                let cmd = systemCommands[i]
                if (query === "/" || cmd.name.toLowerCase().includes(query) || cmd.desc.toLowerCase().includes(query)) {
                    matched.push({
                        name: cmd.name + " — " + cmd.desc,
                        path: "",
                        exec: cmd.exec,
                        count: 0
                    })
                }
            }
        } else {
            for (let i = 0; i < allApps.length; i++) {
                let app = allApps[i]
                if (query === "" || app.name.toLowerCase().includes(query) || app.exec.toLowerCase().includes(query)) {
                    let usageCount = root.appHistory[app.name] || 0
                    matched.push({
                        name: app.name,
                        path: "",
                        exec: app.exec,
                        count: usageCount
                    })
                }
            }

            matched.sort((a, b) => {
                if (b.count !== a.count) {
                    return b.count - a.count
                }
                return a.name.localeCompare(b.name)
            })
        }

        let limit = Math.min(matched.length, 50)
        for (let i = 0; i < limit; i++) {
            appListModel.append(matched[i])
        }

        root.resetScroll()
    }

    function launchApp(appName, execCmd) {
        if (!execCmd || execCmd.trim() === "") return;

        // Wallpaper auswählen – speichert nur den Pfad, die echte Farbe holt sich das Python-Pillow-Skript
        if (execCmd.startsWith("wallpaper_select:")) {
            let imgPath = execCmd.replace("wallpaper_select:", "")
            let pyScript = `
import os
img_path = "` + imgPath + `"
cache_dir = os.path.expanduser('~/.cache')
wp_file = os.path.join(cache_dir, 'quickshell_wallpaper.txt')
with open(wp_file, 'w') as f:
    f.write(img_path)
`
            execProcess.command = ["python3", "-c", pyScript]
            execProcess.running = true
            root.visible = false
            return;
        }

        if (execCmd === "list_wallpapers") {
            searchInput.text = "/wallpaper "
            return;
        }

        if (!execCmd.startsWith("systemctl") && !execCmd.startsWith("loginctl") && !execCmd.startsWith("hyprlock")) {
            let pureAppName = appName.split(" — ")[0]
            if (!root.appHistory[pureAppName]) {
                root.appHistory[pureAppName] = 0
            }
            root.appHistory[pureAppName]++

            let historyJson = JSON.stringify(root.appHistory)
            saveHistoryProcess.command = ["python3", "-c", "
import json, os
path = os.path.expanduser('~/.cache/quickshell_app_history.json')
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, 'w') as f:
    f.write('" + historyJson.replace(/'/g, "\\'") + "')
"]
            saveHistoryProcess.running = true
        }

        let safeCmd = execCmd.replace(/'/g, "'\\''")
        execProcess.command = ["sh", "-c", "nohup " + safeCmd + " >/dev/null 2>&1 &"]
        execProcess.running = true
        root.visible = false
    }

    onVisibleChanged: {
        if (visible) {
            searchInput.text = ""
            loadHistoryProcess.running = true
            if (allApps.length === 0) {
                loadAppsProcess.running = true
            } else {
                filterApps()
            }
            root.resetScroll()
            searchInput.forceActiveFocus()
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    Rectangle {
        anchors.centerIn: parent
        width: 540
        height: 460
        radius: 12
        color: theme ? theme.background : "#1e1e2e"
        border.color: theme ? theme.accent : "#cba6f7"
        border.width: 2

        MouseArea {
            anchors.fill: parent
            onClicked: (mouse) => mouse.accepted = true
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // --- SUCHLEISTE ---
            Rectangle {
                Layout.fillWidth: true
                height: 42
                radius: 8
                color: theme ? theme.surface : "#313244"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Text {
                        text: "🔍"
                        font.pixelSize: 14
                    }

                    TextField {
                        id: searchInput
                        Layout.fillWidth: true
                        placeholderText: "App suchen oder / für Befehle..."
                        placeholderTextColor: theme ? theme.subtext : "#a6adc8"
                        color: theme ? theme.text : "#cdd6f4"
                        font.pixelSize: 14
                        background: null

                        onTextChanged: root.filterApps()

                        Keys.onDownPressed: {
                            if (appList.currentIndex < appList.count - 1) {
                                appList.currentIndex++
                            }
                        }

                        Keys.onUpPressed: {
                            if (appList.currentIndex > 0) {
                                appList.currentIndex--
                            }
                        }

                        Keys.onEscapePressed: root.visible = false

                        onAccepted: {
                            if (appList.count > 0 && appList.currentIndex >= 0) {
                                let selectedApp = appListModel.get(appList.currentIndex)
                                root.launchApp(selectedApp.name, selectedApp.exec)
                            } else if (searchInput.text.trim() !== "") {
                                root.launchApp(searchInput.text.trim(), searchInput.text.trim())
                            }
                        }
                    }
                }
            }

            // --- APP LISTE ---
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    id: appList
                    anchors.fill: parent
                    spacing: 6
                    model: appListModel
                    currentIndex: 0

                    delegate: Rectangle {
                        required property var model
                        required property int index

                        width: appList.width
                        height: model.path !== undefined && model.path !== "" ? 48 : 40
                        radius: 6

                        property bool isSelected: index === appList.currentIndex

                        color: isSelected
                            ? (theme ? theme.accent : "#cba6f7")
                            : (itemMouse.containsMouse ? (theme ? theme.surface : "#313244") : "transparent")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            Item {
                                width: model.path !== undefined && model.path !== "" ? 64 : 28
                                height: model.path !== undefined && model.path !== "" ? 36 : 28
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 4
                                    color: "#11111b"
                                    visible: model.path !== undefined && model.path !== ""
                                    border.color: isSelected ? (theme ? theme.background : "#1e1e2e") : (theme ? theme.accent : "#cba6f7")
                                    border.width: 1

                                    Image {
                                        id: thumbImage
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        source: (model.path !== undefined && model.path !== "") ? model.path : ""
                                        fillMode: Image.PreserveAspectCrop
                                        visible: source != ""
                                        clip: true
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: model.path === undefined || model.path === "" ? (model.name.startsWith("/") ? "⚙️" : "🚀") : ""
                                    font.pixelSize: 14
                                    visible: model.path === undefined || model.path === ""
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: (model.path !== undefined && model.path !== "") ? model.name : model.name
                                color: isSelected
                                    ? (theme ? theme.background : "#1e1e2e")
                                    : (theme ? theme.text : "#cdd6f4")
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: appList.currentIndex = index
                            onClicked: root.launchApp(model.name, model.exec)
                        }
                    }
                }
            }
        }
    }
}
