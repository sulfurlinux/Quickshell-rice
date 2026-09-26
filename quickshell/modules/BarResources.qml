import QtQuick

Rectangle {
    id: root
    property var theme
    property var services
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
        color: root.theme ? root.theme.text : "#cdd6f4"
        font.pixelSize: 11
        font.bold: true
    }
}
