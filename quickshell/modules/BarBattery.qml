import QtQuick
import Quickshell.Services.UPower

Rectangle {
    id: root

    property var theme
    property var services
    property bool requested: true
    readonly property var device: services ? services.battery : null
    readonly property int chargePercent: device && device.ready
        ? Math.round(device.percentage) : 0
    readonly property bool charging: device && device.ready
        && (device.state === UPowerDeviceState.Charging
            || device.state === UPowerDeviceState.PendingCharge)
    readonly property string batteryIcon: charging ? ""
        : chargePercent >= 90 ? ""
        : chargePercent >= 60 ? ""
        : chargePercent >= 30 ? ""
        : chargePercent >= 10 ? "" : ""

    visible: requested && device !== null && device.ready && device.isLaptopBattery
    implicitWidth: batteryMetrics.advanceWidth + 14
    implicitHeight: 28
    radius: 6
    color: theme ? theme.surface : "#313244"
    Behavior on color { enabled: root.visible; ColorAnimation { duration: 180 } }

    TextMetrics {
        id: batteryMetrics
        font: label.font
        text: " 100%"
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.batteryIcon + " " + root.chargePercent + "%"
        color: root.theme ? root.theme.text : "#cdd6f4"
        font.pixelSize: 12
        font.bold: true
    }
}
