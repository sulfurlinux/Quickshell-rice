import QtQuick

Item {
    id: root
    property var theme
    property var services
    property bool requested: true
    property var registeredServices: null
    function syncDemand() {
        if (registeredServices && registeredServices !== services)
            registeredServices.setSpectrumDemand(root, false);
        registeredServices = services || null;
        if (registeredServices) registeredServices.setSpectrumDemand(root, requested);
    }
    onRequestedChanged: syncDemand()
    onServicesChanged: syncDemand()
    Component.onCompleted: syncDemand()
    Component.onDestruction: if (registeredServices) registeredServices.setSpectrumDemand(root, false)
    visible: requested && services !== null && services !== undefined && services.cavaAvailable
    implicitWidth: 70
    implicitHeight: 24
    Row {
        anchors.centerIn: parent
        height: 24
        spacing: 2
        Repeater {
            model: 12
            Item {
                required property int index
                width: 4
                height: 24
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: 4
                    radius: 1
                    height: Math.max(2, root.services ? (root.services.spectrum[index] || 0) * 0.24 : 2)
                    color: root.theme ? root.theme.accent : "#cba6f7"
                    Behavior on height { NumberAnimation { duration: 60 } }
                }
            }
        }
    }
}
