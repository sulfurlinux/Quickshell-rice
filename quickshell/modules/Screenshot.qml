import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property string screenshotDir: Quickshell.env("HOME") + "/Pictures/Screenshots"

    readonly property bool busy: captureProcess.running

    function capture(target, action) {
        if (busy) return;

        const script = Qt.resolvedUrl("screenshot.sh").toString();
        captureProcess.command = ["bash", decodeURIComponent(script.replace(/^file:\/\//, "")),
            target, action, screenshotDir];
        captureProcess.running = true;
    }

    function fullScreen() { capture("screen", "save"); }
    function selectArea() { capture("area", "save"); }
    function fullScreenClipboard() { capture("screen", "copy"); }
    function selectAreaClipboard() { capture("area", "copy"); }
    function selectAreaSaveAndCopy() { capture("area", "copysave"); }

    Process {
        id: captureProcess
        stderr: SplitParser {
            onRead: data => console.warn("Screenshot: " + data)
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && exitCode !== 130)
                console.warn("Screenshot failed (exit " + exitCode + ").");
        }
    }
}
