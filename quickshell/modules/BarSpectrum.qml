import QtQuick

Item {
    id: root
    property var theme
    property var services
    visible: services !== null && services !== undefined && services.cavaAvailable
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
