import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: root

    property var theme
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    property var allApps: []
    property var appHistory: ({})
    property var wallpapers: []
    property bool wallpapersLoaded: false
    property var pendingPowerAction: null
    readonly property int resultsHeight: {
        let total = 0;
        for (let i = 0; i < appListModel.count; i++) {
            const result = appListModel.get(i);
            total += result.path ? 48 : 40;
        }
        return total + Math.max(0, appListModel.count - 1) * appList.spacing;
    }

    function focusScreen() {
        const monitor = Hyprland.focusedMonitor;
        const focusedScreen = monitor
            ? Quickshell.screens.find(candidate => candidate.name === monitor.name)
            : null;
        if (focusedScreen) root.screen = focusedScreen;
    }

    readonly property bool inPowerMenu: /^\/power(?:\s|$)/.test(searchInput.text.toLowerCase().trim())

    property var powerCommands: [
        { name: "/shutdown", exec: "systemctl poweroff", desc: "Shut down the PC" },
        { name: "/reboot", exec: "systemctl reboot", desc: "Restart the system" },
        { name: "/lock", exec: "hyprlock", desc: "Lock the screen" },
        { name: "/logout", exec: "loginctl terminate-user $USER", desc: "Log out of the session" }
    ]

    property var systemCommands: [
        { name: "/power", exec: "list_power_actions", desc: "Power and session actions" },
        { name: "/wallpaper", exec: "list_wallpapers", desc: "Select a wallpaper" }
    ]

    ListModel {
        id: appListModel
    }

    Process { id: execProcess }
    Process { id: saveHistoryProcess }

    function resetScroll() {
        appList.currentIndex = appList.count > 0 ? 0 : -1
        appList.contentY = appList.originY
    }

    function moveSelection(direction) {
        if (appList.count === 0) return;
        appList.currentIndex = Math.max(0, Math.min(appList.count - 1,
            appList.currentIndex + direction));
        appList.positionViewAtIndex(appList.currentIndex, ListView.Contain);
    }

    function wallpaperQuery(query) {
        return /^\/wallpaper(?:\s|$)/.test(query);
    }

    function acceptWallpapers(data) {
        root.wallpapers = JSON.parse(data);
        root.wallpapersLoaded = true;
        if (wallpaperQuery(searchInput.text.toLowerCase().trim())) {
            root.filterApps();
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
                    if (!searchInput.text.trim().startsWith("/")) root.filterApps()
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
                    root.acceptWallpapers(data)
                } catch(e) {}
            }
        }
    }

    function filterApps() {
        appListModel.clear()
        let query = searchInput.text.toLowerCase().trim()

        let matched = []

        if (/^\/power(?:\s|$)/.test(query)) {
            const powerFilter = query.slice("/power".length).trim();
            for (let i = 0; i < powerCommands.length; i++) {
                const cmd = powerCommands[i];
                if (cmd.name.toLowerCase().includes(powerFilter) || cmd.desc.toLowerCase().includes(powerFilter)) {
                    matched.push({
                        name: cmd.name + " — " + cmd.desc,
                        path: "",
                        exec: cmd.exec,
                        count: 0
                    });
                }
            }
            matched.push({ name: "← Back to commands", path: "", exec: "power_back", count: 0 });
        } else if (wallpaperQuery(query)) {
            if (!wallpapersLoaded) {
                if (!loadWallpapersProcess.running) loadWallpapersProcess.running = true;
            } else {
                const wallpaperFilter = query.slice("/wallpaper".length).trim();
                for (let i = 0; i < wallpapers.length; i++) {
                    const wallpaper = wallpapers[i];
                    if (wallpaper.name.toLowerCase().includes(wallpaperFilter)) {
                        appListModel.append({
                            name: wallpaper.name,
                            path: wallpaper.path,
                            exec: wallpaper.exec,
                            count: 0
                        });
                    }
                }
            }
            root.resetScroll()
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

    function powerAction(execCmd) {
        switch (execCmd.trim().replace(/\s+/g, " ")) {
        case "systemctl reboot":
            return { label: "Restart", command: ["systemctl", "reboot"] };
        case "loginctl terminate-user $USER":
            return { label: "Log out", command: ["loginctl", "terminate-user", Quickshell.env("USER")] };
        default:
            return null;
        }
    }

    function confirmPowerAction() {
        const action = root.pendingPowerAction;
        root.pendingPowerAction = null;
        if (!action) return;
        execProcess.command = action.command;
        execProcess.running = true;
        root.visible = false;
    }

    function launchApp(appName, execCmd) {
        if (!execCmd || execCmd.trim() === "") return;

        if (execCmd === "list_power_actions") {
            searchInput.text = "/power ";
            searchInput.forceActiveFocus();
            return;
        }
        if (execCmd === "power_back") {
            searchInput.text = "/";
            searchInput.forceActiveFocus();
            return;
        }
        // Keep existing slash shortcuts usable without listing them at the top level.
        const shortcut = powerCommands.find(cmd => cmd.name === execCmd.trim().toLowerCase());
        if (shortcut) execCmd = shortcut.exec;

        const action = powerAction(execCmd);
        if (action) {
            root.pendingPowerAction = action;
            powerConfirmation.open();
            return;
        }

        // Choose wallpaper – stores only the path; the Python Pillow script gets the actual color
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
            root.focusScreen()
            root.wallpapersLoaded = false
            searchInput.text = ""
            loadHistoryProcess.running = true
            if (allApps.length === 0) {
                loadAppsProcess.running = true
            } else {
                filterApps()
            }
            root.resetScroll()
            Qt.callLater(() => {
                if (root.visible) searchInput.forceActiveFocus();
            })
        } else {
            powerConfirmation.close();
            root.pendingPowerAction = null;
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    Dialog {
        id: powerConfirmation
        parent: launcherCard
        anchors.centerIn: parent
        width: Math.max(0, Math.min(360, root.width - 32))
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape
        title: root.pendingPowerAction ? root.pendingPowerAction.label + "?" : "Confirm action"

        background: Rectangle {
            radius: 12
            color: theme ? theme.background : "#1e1e2e"
            border.color: theme ? theme.accent : "#cba6f7"
            border.width: 2
        }
        header: Label {
            text: powerConfirmation.title
            color: theme ? theme.text : "#cdd6f4"
            font.bold: true
            font.pixelSize: 18
            padding: 16
        }
        contentItem: Label {
            text: "This will close your session. Unsaved work may be lost."
            color: theme ? theme.text : "#cdd6f4"
            wrapMode: Text.WordWrap
        }
        footer: DialogButtonBox {
            padding: 16
            spacing: 8
            background: Item {}

            Button {
                id: cancelPowerAction
                text: "Cancel"
                implicitWidth: Math.max(96, implicitContentWidth + 24)
                implicitHeight: 36
                contentItem: Text {
                    text: cancelPowerAction.text
                    color: theme ? theme.text : "#cdd6f4"
                    font: cancelPowerAction.font
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 6
                    color: cancelPowerAction.down
                        ? Qt.darker(theme ? theme.surface : "#313244", 1.15)
                        : cancelPowerAction.hovered
                            ? Qt.lighter(theme ? theme.surface : "#313244", 1.15)
                            : (theme ? theme.surface : "#313244")
                    border.width: 1
                    border.color: cancelPowerAction.visualFocus
                        ? (theme ? theme.accent : "#cba6f7") : "transparent"
                }
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
                Keys.onReturnPressed: powerConfirmation.reject()
                Keys.onEnterPressed: powerConfirmation.reject()
            }
            Button {
                id: confirmPowerButton
                text: root.pendingPowerAction ? root.pendingPowerAction.label : "Confirm"
                implicitWidth: Math.max(96, implicitContentWidth + 24)
                implicitHeight: 36
                contentItem: Text {
                    text: confirmPowerButton.text
                    color: theme ? theme.background : "#1e1e2e"
                    font: confirmPowerButton.font
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 6
                    color: confirmPowerButton.down
                        ? Qt.darker(theme ? theme.accent : "#cba6f7", 1.15)
                        : confirmPowerButton.hovered
                            ? Qt.lighter(theme ? theme.accent : "#cba6f7", 1.1)
                            : (theme ? theme.accent : "#cba6f7")
                    border.width: 1
                    border.color: confirmPowerButton.visualFocus
                        ? (theme ? theme.text : "#cdd6f4") : "transparent"
                }
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
                Keys.onReturnPressed: powerConfirmation.accept()
                Keys.onEnterPressed: powerConfirmation.accept()
            }
            onAccepted: powerConfirmation.accept()
            onRejected: powerConfirmation.reject()
        }
        onOpened: cancelPowerAction.forceActiveFocus()
        onAccepted: root.confirmPowerAction()
        onClosed: {
            root.pendingPowerAction = null;
            if (root.visible) searchInput.forceActiveFocus();
        }
    }

    Rectangle {
        id: launcherCard
        anchors.centerIn: parent
        width: Math.max(0, Math.min(540, parent.width - 32))
        height: Math.max(0, Math.min(460, parent.height - 32,
            74 + (appListModel.count > 0 ? 12 + root.resultsHeight : 0)))
        radius: 12
        color: theme ? theme.background : "#1e1e2e"
        border.color: theme ? theme.accent : "#cba6f7"
        border.width: 2
        clip: true

        Behavior on height {
            enabled: root.visible
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: (mouse) => mouse.accepted = true
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Search bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                Layout.minimumHeight: 42
                radius: 8
                color: theme ? theme.surface : "#313244"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Text {
                        text: ""
                        color: searchInput.color
                        font.pixelSize: 14
                    }

                    TextField {
                        id: searchInput
                        Layout.fillWidth: true
                        placeholderText: "Launcher"
                        placeholderTextColor: theme ? theme.subtext : "#a6adc8"
                        color: theme ? theme.text : "#cdd6f4"
                        font.pixelSize: 14
                        background: null

                        onTextChanged: root.filterApps()

                        Keys.onDownPressed: root.moveSelection(1)
                        Keys.onUpPressed: root.moveSelection(-1)

                        Keys.onEscapePressed: {
                            if (root.inPowerMenu) searchInput.text = "/";
                            else root.visible = false;
                        }

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

            // App List
            ListView {
                id: appList
                visible: count > 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.minimumHeight: 0
                clip: true
                spacing: 6
                model: appListModel
                currentIndex: -1
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: false
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

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
                                text: model.path === undefined || model.path === "" ? (model.name.startsWith("/") ? "" : "󱓞") : ""
                                color: resultLabel.color
                                font.pixelSize: 14
                                visible: model.path === undefined || model.path === ""
                            }
                        }

                        Text {
                            id: resultLabel
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
                        onClicked: {
                            appList.currentIndex = index;
                            root.launchApp(model.name, model.exec);
                        }
                    }
                }
            }
        }
    }
}
