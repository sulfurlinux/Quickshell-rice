import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Scope {
    id: root
    property string selectedPlayerName: ""
    readonly property var players: Mpris.players.values
    readonly property var player: {
        const selected = players.find(candidate => candidate.dbusName === selectedPlayerName);
        return selected || players.find(candidate => candidate.isPlaying) || players[0] || null;
    }
    property var resources: null
    property var spectrum: []
    property bool cavaAvailable: false

    function cyclePlayer() {
        if (players.length === 0) return;
        const current = players.indexOf(player);
        selectedPlayerName = players[(current + 1) % players.length].dbusName;
    }

    Process {
        running: true
        command: ["python3", "-u", decodeURIComponent(
            Qt.resolvedUrl("resources.py").toString().replace(/^file:\/\//, ""))]
        stdout: SplitParser {
            onRead: data => {
                try { root.resources = JSON.parse(data); }
                catch (error) { console.warn("Bar resources: " + error); }
            }
        }
        stderr: SplitParser { onRead: data => console.warn("Bar resources: " + data) }
        onExited: (exitCode, exitStatus) => {
            root.resources = null;
            console.warn("Bar resource monitor stopped (exit " + exitCode + ")");
        }
    }

    Process {
        running: true
        command: ["cava", "-p", decodeURIComponent(
            Qt.resolvedUrl("cava-bar.conf").toString().replace(/^file:\/\//, ""))]
        stdout: SplitParser {
            onRead: data => {
                const values = data.trim().split(";").filter(value => value !== "").map(Number);
                if (values.length !== 12 || values.some(value => !Number.isFinite(value))) return;
                root.spectrum = values.map(value => Math.max(0, Math.min(100, value)));
                root.cavaAvailable = true;
            }
        }
        stderr: SplitParser { onRead: data => console.warn("Bar Cava: " + data) }
        onExited: (exitCode, exitStatus) => {
            root.cavaAvailable = false;
            root.spectrum = [];
            console.warn("Bar Cava stopped (exit " + exitCode + ")");
        }
    }
}
