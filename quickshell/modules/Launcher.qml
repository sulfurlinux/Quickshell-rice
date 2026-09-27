import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: root

    property var theme
    signal wallpaperSelected(string path)
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

    readonly property var allApps: DesktopEntries.applications.values.map(entry => ({
        name: entry.name,
        exec: "desktop_entry:" + entry.id,
        searchName: entry.name.toLowerCase(),
        searchCommand: entry.command.join(" ").toLowerCase()
    }))
    onAllAppsChanged: {
        if (root.visible && !searchInput.text.trim().startsWith("/")) root.filterApps();
    }
    property var appHistory: ({})
    property string lastFilterQuery: ""
    property bool historyReady: false
    property bool historySaving: false
    property bool historyDirty: false
    property var pendingHistory: ({})

    FileView {
        id: historyFile
        path: Quickshell.env("HOME") + "/.cache/quickshell_app_history.json"
        printErrors: false
        atomicWrites: true
        onLoaded: {
            let history = {};
            try {
                const parsed = JSON.parse(historyFile.text());
                if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
                    for (const name of Object.keys(parsed)) {
                        if (Number.isSafeInteger(parsed[name]) && parsed[name] >= 0)
                            history[name] = parsed[name];
                    }
                }
            } catch (error) { console.warn("Launcher history: invalid JSON: " + error); }
            root.acceptHistory(history);
        }
        onLoadFailed: root.acceptHistory({})
        onSaved: {
            root.historySaving = false;
            root.saveHistory();
        }
        onSaveFailed: error => {
            root.historySaving = false;
            root.historyDirty = true;
            console.warn("Launcher history: save failed (" + error + ")");
        }
    }

    function acceptHistory(history) {
        for (const name of Object.keys(root.pendingHistory))
            history[name] = (history[name] || 0) + root.pendingHistory[name];
        root.pendingHistory = {};
        root.appHistory = history;
        root.historyReady = true;
        root.saveHistory();
        if (root.visible && !searchInput.text.trim().startsWith("/")) root.filterApps();
    }

    function recordAppLaunch(name) {
        const history = Object.assign({}, root.appHistory);
        history[name] = (history[name] || 0) + 1;
        root.appHistory = history;
        if (!root.historyReady) {
            const pending = Object.assign({}, root.pendingHistory);
            pending[name] = (pending[name] || 0) + 1;
            root.pendingHistory = pending;
        }
        root.historyDirty = true;
        root.saveHistory();
    }

    function saveHistory() {
        if (!root.historyReady || root.historySaving || !root.historyDirty) return;
        root.historyDirty = false;
        root.historySaving = true;
        historyFile.setText(JSON.stringify(root.appHistory));
    }
    property var wallpapers: []
    property bool wallpapersLoaded: false
    property bool wallpaperIndexStarted: false
    property var clipboardEntries: []
    property bool clipboardLoaded: false
    property string clipboardError: ""
    property var clipboardThumbnails: ({})
    property string clipboardDatabaseKey: ""
    readonly property string clipboardPreviewPython: Quickshell.env("HOME") + "/.cache/quickshell_venv/bin/python3"
    property var thumbnailQueue: []
    property var thumbnailRequest: null
    property bool thumbnailWorkerReady: false

    function requestClipboardThumbnail(identifier, key) {
        if (root.clipboardThumbnails[key]
            || (root.thumbnailRequest && root.thumbnailRequest.key === key
                && root.thumbnailRequest.database === root.clipboardDatabaseKey)
            || root.thumbnailQueue.some(request => request.key === key
                && request.database === root.clipboardDatabaseKey)) return;
        root.thumbnailQueue = root.thumbnailQueue.concat([{
            id: identifier, key: key, database: root.clipboardDatabaseKey
        }]);
        Qt.callLater(root.pumpThumbnailQueue);
    }

    function pumpThumbnailQueue() {
        if (root.thumbnailRequest || !root.visible || !root.inClipboardMenu) return;
        const currentKeys = [];
        const visibleKeys = [];
        for (let i = 0; i < appListModel.count; i++) {
            const row = appListModel.get(i);
            if (!row.clipboardImage) continue;
            currentKeys.push(row.thumbnailKey);
            const item = appList.itemAtIndex(i);
            if (item && item.previewVisible) visibleKeys.push(row.thumbnailKey);
        }
        root.thumbnailQueue = root.thumbnailQueue.filter(request =>
            request.database === root.clipboardDatabaseKey && !root.clipboardThumbnails[request.key]
            && currentKeys.includes(request.key)
            && root.clipboardEntries.some(entry => root.thumbnailKey(entry) === request.key));
        // Re-evaluate priority before every decode, including after scrolling.
        root.thumbnailQueue = root.thumbnailQueue.slice().sort((a, b) =>
            Number(visibleKeys.includes(b.key)) - Number(visibleKeys.includes(a.key)));
        if (root.thumbnailQueue.length === 0) return;
        if (!thumbnailWorker.running) {
            thumbnailWorker.running = true;
            return;
        }
        if (!root.thumbnailWorkerReady) return;
        root.thumbnailRequest = root.thumbnailQueue[0];
        root.thumbnailQueue = root.thumbnailQueue.slice(1);
        thumbnailWorker.write(JSON.stringify(root.thumbnailRequest) + "\n");
    }

    Process {
        id: thumbnailWorker
        command: [root.clipboardPreviewPython, "-u", root.clipboardScript, "preview-worker"]
        stdinEnabled: true
        onStarted: {
            root.thumbnailWorkerReady = true;
            root.pumpThumbnailQueue();
        }
        stdout: SplitParser {
            onRead: data => {
                try {
                    const result = JSON.parse(data);
                    root.rememberClipboardThumbnail(result.key, result.source, result.database);
                } catch (error) { console.warn("Clipboard thumbnail worker: " + error); }
                root.thumbnailRequest = null;
                root.pumpThumbnailQueue();
            }
        }
        stderr: SplitParser { onRead: data => console.warn("Clipboard thumbnail worker: " + data) }
        onExited: (exitCode, exitStatus) => {
            root.thumbnailWorkerReady = false;
            root.thumbnailRequest = null;
            root.thumbnailQueue = [];
            if (exitCode !== 0) console.warn("Clipboard thumbnail worker stopped (exit " + exitCode + ")");
        }
    }

    function thumbnailKey(entry) {
        return entry.id + ":" + entry.preview;
    }

    function retainClipboardThumbnails(entries, database) {
        const retained = {};
        const keys = entries.filter(entry => entry.isImage).map(entry => root.thumbnailKey(entry));
        if (database === root.clipboardDatabaseKey) {
            for (const key of Object.keys(root.clipboardThumbnails)) {
                if (keys.includes(key)) retained[key] = root.clipboardThumbnails[key];
            }
        }
        root.clipboardDatabaseKey = database;
        root.clipboardThumbnails = retained;
    }

    function rememberClipboardThumbnail(key, source, database) {
        if (!source || database !== root.clipboardDatabaseKey
            || !root.clipboardEntries.some(entry => root.thumbnailKey(entry) === key)) return;
        const updated = Object.assign({}, root.clipboardThumbnails);
        delete updated[key];
        updated[key] = source;
        const keys = Object.keys(updated);
        while (keys.length > 64) delete updated[keys.shift()];
        root.clipboardThumbnails = updated;
    }
    property var runningApps: []
    property bool runningAppsLoaded: false
    property string runningAppsError: ""
    readonly property string runningAppsScript: decodeURIComponent(
        Qt.resolvedUrl("running_apps.py").toString().replace(/^file:\/\//, ""))
    readonly property bool inKillMenu: /^\/pkill(?:\s|$)/.test(searchInput.text.toLowerCase().trim())
    readonly property string clipboardScript: decodeURIComponent(
        Qt.resolvedUrl("clipboard.py").toString().replace(/^file:\/\//, ""))
    readonly property bool inClipboardMenu: /^\/clipboard(?:\s|$)/.test(searchInput.text.toLowerCase().trim())
    onInClipboardMenuChanged: if (!inClipboardMenu) root.thumbnailQueue = []
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
        { name: "/pkill", exec: "list_running_apps", desc: "Terminate a running app" },
        { name: "/power", exec: "list_power_actions", desc: "Power and session actions" },
        { name: "/wallpaper", exec: "list_wallpapers", desc: "Select a wallpaper" }
    ]

    ListModel {
        id: appListModel
    }

    function resultKey(row) {
        return row.exec || row.name;
    }

    function updateResults(results) {
        const keys = results.map(root.resultKey);
        for (let i = appListModel.count - 1; i >= 0; i--) {
            if (!keys.includes(root.resultKey(appListModel.get(i)))) appListModel.remove(i);
        }
        for (let i = 0; i < results.length; i++) {
            const row = Object.assign({ path: "", count: 0, clipboardImage: false, thumbnailKey: "" }, results[i]);
            let existing = i;
            while (existing < appListModel.count
                && root.resultKey(appListModel.get(existing)) !== keys[i]) existing++;
            if (existing === appListModel.count) {
                appListModel.insert(i, row);
            } else {
                if (existing !== i) appListModel.move(existing, i, 1);
                for (const role of Object.keys(row)) {
                    if (appListModel.get(i)[role] !== row[role]) appListModel.setProperty(i, role, row[role]);
                }
            }
        }
        if (appListModel.count > results.length)
            appListModel.remove(results.length, appListModel.count - results.length);
    }

    Process { id: execProcess }


    Process {
        id: loadRunningAppsProcess
        command: ["python3", root.runningAppsScript, "list"]
        stderr: SplitParser { onRead: data => console.warn("Running apps: " + data) }
        stdout: SplitParser {
            onRead: data => {
                try {
                    const result = JSON.parse(data);
                    root.runningApps = result.apps;
                    root.runningAppsError = result.error;
                } catch (error) {
                    root.runningAppsError = "Apps unavailable — see qs logs";
                    console.warn("Running apps: " + error);
                }
                root.runningAppsLoaded = true;
                if (root.inKillMenu) root.filterApps();
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.runningAppsError = "Apps unavailable — see qs logs";
                root.runningAppsLoaded = true;
                if (root.inKillMenu) root.filterApps();
            }
        }
    }

    Process {
        id: terminateAppProcess
        stderr: SplitParser { onRead: data => console.warn("Terminate app: " + data) }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) root.visible = false;
            else {
                root.runningAppsError = "Could not stop app — see qs logs";
                if (root.inKillMenu) root.filterApps();
            }
        }
    }

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
                    root.retainClipboardThumbnails(result.entries, result.databaseKey || "");
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

    function refreshWallpapers() {
        // An empty folder URL may initially index the working directory.
        // Do not mark that initial model as the loaded wallpaper list.
        if (!root.wallpaperIndexStarted || wallpaperFolder.status !== FolderListModel.Ready) return;
        const entries = [];
        for (let i = 0; i < wallpaperFolder.count; i++) {
            entries.push({
                name: wallpaperFolder.get(i, "fileName"),
                path: wallpaperFolder.get(i, "fileUrl").toString(),
                exec: "wallpaper_select:" + wallpaperFolder.get(i, "filePath")
            });
        }
        root.wallpapers = entries;
        root.wallpapersLoaded = true;
        if (root.visible && wallpaperQuery(searchInput.text.toLowerCase().trim())) {
            root.filterApps();
        }
    }

    FolderListModel {
        id: wallpaperFolder
        folder: root.wallpaperIndexStarted
            ? "file://" + Quickshell.env("HOME").split("/").map(part => encodeURIComponent(part)).join("/") + "/Pictures/Wallpapers"
            : ""
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        caseSensitive: false
        showDirs: false
        showHidden: true
        sortField: FolderListModel.Name
        onStatusChanged: Qt.callLater(root.refreshWallpapers)
        onCountChanged: Qt.callLater(root.refreshWallpapers)
    }

    Connections {
        target: wallpaperFolder
        function onRowsInserted() { Qt.callLater(root.refreshWallpapers); }
        function onRowsRemoved() { Qt.callLater(root.refreshWallpapers); }
        function onModelReset() { Qt.callLater(root.refreshWallpapers); }
        function onDataChanged() { Qt.callLater(root.refreshWallpapers); }
    }

    function filterApps() {

        let query = searchInput.text.toLowerCase().trim()

        let matched = []

        if (root.inKillMenu) {
            if (!runningAppsLoaded && !loadRunningAppsProcess.running) loadRunningAppsProcess.running = true;
            const appFilter = query.slice("/pkill".length).trim();
            if (!runningAppsLoaded || runningAppsError) {
                matched.push({ name: runningAppsError || "Loading running apps…", path: "", exec: "", count: 0 });
            } else {
                for (const app of runningApps) {
                    const label = app.name + (app.title ? " — " + app.title : "") + " (PID " + app.pid + ")";
                    if (label.toLowerCase().includes(appFilter) && matched.length < 49) {
                        matched.push({ name: label, path: "", count: 0,
                            exec: "pkill_app:" + app.pid + ":" + app.identity });
                    }
                }
                if (matched.length === 0) matched.push({ name: "No matching running apps", path: "", exec: "", count: 0 });
            }
            matched.push({ name: "← Back to commands", path: "", exec: "power_back", count: 0 });
        } else if (/^\/clipboard(?:\s|$)/.test(query)) {
            if (!clipboardLoaded && !loadClipboardProcess.running) loadClipboardProcess.running = true;
            const clipboardFilter = query.slice("/clipboard".length).trim();
            if (!clipboardLoaded || clipboardError) {
                matched.push({ name: clipboardError || "Loading clipboard history…", path: "", exec: "", count: 0 });
            } else {
                for (let i = 0; i < clipboardEntries.length && matched.length < 49; i++) {
                    const entry = clipboardEntries[i];
                    if (entry.preview.toLowerCase().includes(clipboardFilter)) {
                        matched.push({ name: entry.preview, path: "", exec: "clipboard_copy:" + entry.id, count: 0,
                            clipboardImage: entry.isImage === true,
                            thumbnailKey: root.thumbnailKey(entry) });
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
            root.wallpaperIndexStarted = true;
            if (!wallpapersLoaded) {
                matched.push({ name: "Loading wallpapers…", path: "", exec: "", count: 0,
                    clipboardImage: false, thumbnailKey: "" });
            } else {
                const wallpaperFilter = query.slice("/wallpaper".length).trim();
                for (let i = 0; i < wallpapers.length; i++) {
                    const wallpaper = wallpapers[i];
                    if (wallpaper.name.toLowerCase().includes(wallpaperFilter)) {
                        matched.push({
                            name: wallpaper.name,
                            path: wallpaper.path,
                            exec: wallpaper.exec,
                            count: 0,
                            clipboardImage: false,
                            thumbnailKey: ""
                        });
                    }
                }
                if (matched.length === 0) {
                    matched.push({
                        name: wallpapers.length === 0 ? "No wallpapers in ~/Pictures/Wallpapers" : "No matching wallpapers",
                        path: "", exec: "", count: 0, clipboardImage: false, thumbnailKey: ""
                    });
                }
            }
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
                if (query === "" || app.searchName.includes(query) || app.searchCommand.includes(query)) {
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

        root.updateResults(wallpaperQuery(query) ? matched : matched.slice(0, 50));
        if (query !== root.lastFilterQuery) root.resetScroll();
        root.lastFilterQuery = query;
    }

    function launchApp(appName, execCmd) {
        if (!execCmd || execCmd.trim() === "") return;

        if (execCmd === "list_running_apps") {
            root.runningAppsLoaded = false;
            root.runningAppsError = "";
            searchInput.text = "/pkill ";
            searchInput.forceActiveFocus();
            root.filterApps();
            return;
        }
        if (execCmd.startsWith("pkill_app:")) {
            const selection = execCmd.slice("pkill_app:".length).split(":");
            if (selection.length !== 2 || !selection.every(value => /^\d+$/.test(value))
                || terminateAppProcess.running) return;
            terminateAppProcess.exec(["python3", root.runningAppsScript, "terminate", selection[0], selection[1]]);
            return;
        }

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


        if (execCmd.startsWith("wallpaper_select:")) {
            root.wallpaperSelected(execCmd.slice("wallpaper_select:".length))
            root.visible = false
            return;
        }

        if (execCmd === "list_wallpapers") {
            searchInput.text = "/wallpaper "
            return;
        }

        if (!execCmd.startsWith("systemctl") && !execCmd.startsWith("loginctl") && !execCmd.startsWith("hyprlock")) {
            root.recordAppLaunch(appName.split(" — ")[0]);
        }

        if (execCmd.startsWith("desktop_entry:")) {
            const entry = DesktopEntries.byId(execCmd.slice("desktop_entry:".length));
            if (!entry) {
                root.filterApps();
                return;
            }
            entry.execute();
            root.visible = false;
            return;
        }

        let safeCmd = execCmd.replace(/'/g, "'\\''")
        execProcess.command = ["sh", "-c", "nohup " + safeCmd + " >/dev/null 2>&1 &"]
        execProcess.running = true
        root.visible = false
    }

    onVisibleChanged: {
        if (visible) {
            root.focusScreen()
            root.clipboardLoaded = false
            root.clipboardError = ""
            root.runningAppsLoaded = false
            root.runningAppsError = ""
            searchInput.text = ""
            filterApps()
            root.resetScroll()
            Qt.callLater(() => {
                if (root.visible) searchInput.forceActiveFocus();
            })
        } else {
            root.thumbnailQueue = [];
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
                            if (root.inPowerMenu || root.inClipboardMenu || root.inKillMenu) searchInput.text = "/";
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
                reuseItems: true
                currentIndex: -1
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: false
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    required property var model
                    required property int index

                    readonly property bool hasClipboardImage: model.clipboardImage === true
                    readonly property string clipboardImageSource: root.clipboardThumbnails[model.thumbnailKey] || ""
                    readonly property string previewKey: model.thumbnailKey
                    property bool pooled: false
                    readonly property bool previewVisible: root.visible && !pooled
                        && y + height > appList.contentY && y < appList.contentY + appList.height
                    function refreshPreview() {
                        if (!pooled && hasClipboardImage && !clipboardImageSource)
                            root.requestClipboardThumbnail(model.exec.slice("clipboard_copy:".length), model.thumbnailKey);
                    }
                    Component.onCompleted: Qt.callLater(refreshPreview)
                    onPreviewKeyChanged: Qt.callLater(refreshPreview)
                    onHasClipboardImageChanged: Qt.callLater(refreshPreview)
                    onPreviewVisibleChanged: if (previewVisible) Qt.callLater(refreshPreview)
                    onClipboardImageSourceChanged: {
                        if (!clipboardImageSource) Qt.callLater(refreshPreview);
                    }
                    ListView.onPooled: pooled = true
                    ListView.onReused: {
                        pooled = false;
                        Qt.callLater(refreshPreview);
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
