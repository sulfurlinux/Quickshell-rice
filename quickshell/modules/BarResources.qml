import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    property var theme
    property var services
    property bool showDisk: true
    readonly property var stats: services ? services.resources : null
    implicitWidth: label.implicitWidth + 14
    implicitHeight: 28
    radius: 6
    color: theme ? theme.surface : "#313244"
    Text {
        id: label
        anchors.centerIn: parent
        text: "CPU " + (root.stats ? root.stats.cpu + "%" : "--")
            + "  RAM " + (root.stats ? root.stats.memory + "%" : "--")
            + (root.showDisk ? "  DISK " + (root.stats ? root.stats.disk + "%" : "--") : "")
        color: root.theme ? root.theme.text : "#cdd6f4"
        font.pixelSize: 11
        font.bold: true
    }
    MouseArea { id: pointer; anchors.fill: parent; hoverEnabled: true }
    ToolTip.visible: pointer.containsMouse
    ToolTip.text: stats ? "CPU: " + stats.cpu + "%\nRAM: " + stats.memoryUsedGiB
        + " / " + stats.memoryTotalGiB + " GiB\nDisk (/): " + stats.diskUsedGiB
        + " / " + stats.diskTotalGiB + " GiB" : "Resource monitor unavailable — see qs logs"
    ToolTip.delay: 500
}
