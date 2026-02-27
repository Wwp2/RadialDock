import QtQuick
import QtQuick.Controls

Item {
    id: settings
    width: 260
    height: 120

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: "#E11A2430"
        border.color: "#66FFFFFF"
        border.width: 1
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Text {
            text: "Settings"
            color: "#EAF4FF"
            font.pixelSize: 15
            font.bold: true
        }

        Row {
            spacing: 8
            Text {
                text: "Refresh on open"
                color: "#DDEAFF"
                font.pixelSize: 12
            }
            Switch {
                checked: appModel.refreshOnOpen
                onToggled: appModel.refreshOnOpen = checked
            }
        }
    }
}
