import QtQuick

Rectangle {
    id: root
    property var theme
    property var services
    property bool requested: true
    property var registeredServices: null
    function syncDemand() {
        if (registeredServices && registeredServices !== services)
            registeredServices.setResourceDemand(root, false);
        registeredServices = services || null;
        if (registeredServices) registeredServices.setResourceDemand(root, requested);
    }
    onRequestedChanged: syncDemand()
    onServicesChanged: syncDemand()
    Component.onCompleted: syncDemand()
    Component.onDestruction: if (registeredServices) registeredServices.setResourceDemand(root, false)
    visible: requested
    readonly property var stats: services ? services.resources : null
    implicitWidth: resourceMetrics.advanceWidth + 14
    implicitHeight: 28
    radius: 6
    color: theme ? theme.surface : "#313244"
    Behavior on color { enabled: root.visible; ColorAnimation { duration: 180 } }
    TextMetrics {
        id: resourceMetrics
        font: label.font
        text: "CPU 100%  RAM 100%"
    }
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
