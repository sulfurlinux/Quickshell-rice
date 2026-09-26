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
    property var clipboardEntries: []
    property bool clipboardLoaded: false
    property string clipboardError: ""
    readonly property string clipboardScript: decodeURIComponent(
        Qt.resolvedUrl("clipboard.py").toString().replace(/^file:\/\//, ""))
    readonly property bool inClipboardMenu: /^\/clipboard(?:\s|$)/.test(searchInput.text.toLowerCase().trim())
    readonly property int resultsHeight: {
        let total = 0;
        for (let i = 0; i < appListModel.count; i++) {
            const result = appListModel.get(i);
            total += result.path || result.clipboardImage ? 48 : 40;
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
        { name: "/clipboard", exec: "list_clipboard", desc: "Clipboard history" },
        { name: "/power", exec: "list_power_actions", desc: "Power and session actions" },
        { name: "/wallpaper", exec: "list_wallpapers", desc: "Select a wallpaper" }
    ]

    ListModel {
        id: appListModel
    }

    Process { id: execProcess }
    Process { id: saveHistoryProcess }

    function openClipboard() {
        root.visible = true;
        root.clipboardLoaded = false;
        root.clipboardError = "";
        searchInput.text = "/clipboard ";
        root.filterApps();
        Qt.callLater(() => { if (root.visible) searchInput.forceActiveFocus(); });
    }

    Process {
        id: loadClipboardProcess
        command: ["python3", root.clipboardScript, "list"]
        stderr: SplitParser { onRead: data => console.warn("Clipboard: " + data) }
        stdout: SplitParser {
            onRead: data => {
                try {
                    const result = JSON.parse(data);
                    root.clipboardEntries = result.entries;
                    root.clipboardError = result.error;
                    root.clipboardLoaded = true;
                    if (root.inClipboardMenu) root.filterApps();
                } catch (error) {
                    root.clipboardLoaded = true;
                    root.clipboardError = "History unavailable — see qs logs";
                    if (root.inClipboardMenu) root.filterApps();
                    console.warn("Could not read clipboard history: " + error);
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.clipboardLoaded = true;
                root.clipboardError = "History unavailable — see qs logs";
                console.warn("Clipboard history process exited with code " + exitCode);
                if (root.inClipboardMenu) root.filterApps();
            }
        }
    }

    Process {
        id: restoreClipboardProcess
        stderr: SplitParser { onRead: data => console.warn("Clipboard: " + data) }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) root.visible = false;
            else {
                root.clipboardError = "Copy failed — see qs logs";
                if (root.inClipboardMenu) root.filterApps();
            }
        }
    }

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

        if (/^\/clipboard(?:\s|$)/.test(query)) {
            if (!clipboardLoaded && !loadClipboardProcess.running) loadClipboardProcess.running = true;
            const clipboardFilter = query.slice("/clipboard".length).trim();
            if (!clipboardLoaded || clipboardError) {
                matched.push({ name: clipboardError || "Loading clipboard history…", path: "", exec: "", count: 0 });
            } else {
                for (let i = 0; i < clipboardEntries.length && matched.length < 49; i++) {
                    const entry = clipboardEntries[i];
                    if (entry.preview.toLowerCase().includes(clipboardFilter)) {
                        matched.push({ name: entry.preview, path: "", exec: "clipboard_copy:" + entry.id, count: 0,
                            clipboardImage: entry.isImage === true });
                    }
                }
                if (matched.length === 0) matched.push({
                    name: clipboardEntries.length === 0 ? "Clipboard history is empty" : "No matching clipboard entries",
                    path: "", exec: "", count: 0
                });
            }
            matched.push({ name: "← Back to commands", path: "", exec: "power_back", count: 0 });
        } else if (/^\/power(?:\s|$)/.test(query)) {
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
                            count: 0,
                            clipboardImage: false
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
            matched[i].clipboardImage = matched[i].clipboardImage === true;
            appListModel.append(matched[i])
        }

        root.resetScroll()
    }

    function launchApp(appName, execCmd) {
        if (!execCmd || execCmd.trim() === "") return;

        if (execCmd === "list_clipboard") {
            root.openClipboard();
            return;
        }
        if (execCmd.startsWith("clipboard_copy:")) {
            const identifier = execCmd.slice("clipboard_copy:".length);
            if (!/^\d+$/.test(identifier) || restoreClipboardProcess.running) return;
            restoreClipboardProcess.command = ["python3", root.clipboardScript, "copy", identifier];
            restoreClipboardProcess.running = true;
            return;
        }

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
            root.clipboardLoaded = false
            root.clipboardError = ""
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
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
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
                            if (root.inPowerMenu || root.inClipboardMenu) searchInput.text = "/";
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

                    readonly property bool hasClipboardImage: model.clipboardImage === true
                    property string clipboardImageSource: ""

                    Process {
                        running: hasClipboardImage
                        command: ["python3", root.clipboardScript, "preview",
                            model.exec.slice("clipboard_copy:".length)]
                        stdout: SplitParser {
                            onRead: data => {
                                try { clipboardImageSource = JSON.parse(data).source; }
                                catch (error) { console.warn("Clipboard thumbnail: " + error); }
                            }
                        }
                        stderr: SplitParser { onRead: data => console.warn("Clipboard thumbnail: " + data) }
                    }

                    width: appList.width
                    height: hasClipboardImage || (model.path !== undefined && model.path !== "") ? 48 : 40
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
                            Layout.preferredWidth: hasClipboardImage || model.path !== "" ? 64 : 28
                            Layout.preferredHeight: hasClipboardImage || model.path !== "" ? 36 : 28
                            Layout.alignment: Qt.AlignVCenter

                            Rectangle {
                                anchors.fill: parent
                                radius: 4
                                color: "#11111b"
                                visible: hasClipboardImage || (model.path !== undefined && model.path !== "")
                                border.color: isSelected ? (theme ? theme.background : "#1e1e2e") : (theme ? theme.accent : "#cba6f7")
                                border.width: 1

                                Image {
                                    id: thumbImage
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    source: hasClipboardImage ? clipboardImageSource
                                        : ((model.path !== undefined && model.path !== "") ? model.path : "")
                                    sourceSize.width: 128
                                    sourceSize.height: 72
                                    asynchronous: true
                                    fillMode: hasClipboardImage ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                                    visible: source != ""
                                    clip: true
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: model.path === undefined || model.path === ""
                                    ? (model.exec.startsWith("clipboard_copy:") ? "󰅍" : (model.name.startsWith("/") ? "" : "󱓞")) : ""
                                color: resultLabel.color
                                font.pixelSize: 14
                                visible: !hasClipboardImage && (model.path === undefined || model.path === "")
                            }
                        }

                        Text {
                            id: resultLabel
                            Layout.fillWidth: true
                            text: (model.path !== undefined && model.path !== "") ? model.name : model.name
                            textFormat: Text.PlainText
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
