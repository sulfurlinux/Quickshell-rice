import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string screenshotDir: Quickshell.env("HOME") + "/Pictures/Screenshots"

    function timestamp() {
        return Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss")
    }

    function run(command) {
        Quickshell.execDetached(command)
    }

    function fullScreen() {
        run(["sh", "-c", "mkdir -p \"$HOME/Pictures/Screenshots\" && grim \"$HOME/Pictures/Screenshots/Screenshot_" + timestamp() + ".png\""])
    }

    function selectArea() {
        run(["sh", "-c", "mkdir -p \"$HOME/Pictures/Screenshots\" && geometry=$(slurp) && [ -n \"$geometry\" ] && grim -g \"$geometry\" \"$HOME/Pictures/Screenshots/Screenshot_" + timestamp() + ".png\""])
    }

    function fullScreenClipboard() {
        run(["sh", "-c", "grim - | wl-copy --type image/png"])
    }

    function selectAreaClipboard() {
        run(["sh", "-c", "geometry=$(slurp) && [ -n \"$geometry\" ] && grim -g \"$geometry\" - | wl-copy --type image/png"])
    }

    function selectAreaSaveAndCopy() {
        run(["sh", "-c", "mkdir -p \"$HOME/Pictures/Screenshots\" && geometry=$(slurp) && [ -n \"$geometry\" ] && grim -g \"$geometry\" \"$HOME/Pictures/Screenshots/Screenshot_" + timestamp() + ".png\" && grim -g \"$geometry\" - | wl-copy --type image/png"])
    }
}
