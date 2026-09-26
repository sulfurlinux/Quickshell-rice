import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    property var theme
    property string label: ""
    property string hint: ""
    signal clicked()
    implicitWidth: 24
    implicitHeight: 24
    radius: 4
    color: pointer.containsMouse && enabled ? (theme ? theme.accent : "#cba6f7") : "transparent"
    opacity: enabled ? 1 : 0.35
    Text {
        anchors.centerIn: parent
        text: root.label
        font.pixelSize: 14
        color: pointer.containsMouse && root.enabled
            ? (root.theme ? root.theme.background : "#1e1e2e")
            : (root.theme ? root.theme.text : "#cdd6f4")
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
    ToolTip.visible: pointer.containsMouse && hint !== ""
    ToolTip.text: hint
    ToolTip.delay: 500
}
