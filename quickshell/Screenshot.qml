pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: screenshot

    property string screenshotDir: StandardPaths.writableLocation(StandardPaths.PicturesLocation) + "/Screenshots"

    function ensureDir() {
        Quickshell.execDetached(["mkdir", "-p", screenshotDir])
    }

    function timestamp() {
        return Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss")
    }

    function fullScreen() {
        ensureDir()
        Quickshell.execDetached(["sh", "-c", "grim -t png '" + screenshotDir + "/Screenshot_" + timestamp() + ".png'"])
    }

    function selectArea() {
        ensureDir()
        Quickshell.execDetached(["sh", "-c", "grim -g \"$(slurp)\" -t png '" + screenshotDir + "/Screenshot_" + timestamp() + ".png'"])
    }

    function fullScreenClipboard() {
        Quickshell.execDetached(["sh", "-c", "grim - | wl-copy --type image/png"])
    }

    function selectAreaClipboard() {
        Quickshell.execDetached(["sh", "-c", "grim -g \"$(slurp)\" - | wl-copy --type image/png"])
    }
}
