import QtQuick

Rectangle {
    id: root
    property var theme
    property string label: ""
    signal clicked()
    implicitWidth: 24
    implicitHeight: 24
    radius: 4
    color: "transparent"
    opacity: enabled ? 1 : 0.35
    scale: pointer.pressed ? 0.92 : 1
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 150 } }
    Text {
        anchors.centerIn: parent
        text: root.label
        font.pixelSize: 14
        color: root.theme ? root.theme.text : "#cdd6f4"
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
