import QtQuick
import QtQuick.Controls

Item {
    id: ring

    readonly property var demoItems: [
        { "label": "Steam" },
        { "label": "Discord" },
        { "label": "Downloads" },
        { "label": "Photos" },
        { "label": "VS Code" },
        { "label": "Music" }
    ]

    Repeater {
        id: iconRepeater
        model: ring.demoItems
        delegate: Rectangle {
            required property var modelData
            readonly property int total: iconRepeater.count
            readonly property real indexAngle: (index / Math.max(total, 1)) * Math.PI * 2
            width: 58
            height: 58
            radius: width / 2
            color: "#D6263345"
            border.color: "#8AF5F5FF"
            border.width: 1
            x: ring.width / 2 + Math.cos(indexAngle - Math.PI / 2) * (ring.width * 0.36) - width / 2
            y: ring.height / 2 + Math.sin(indexAngle - Math.PI / 2) * (ring.height * 0.36) - height / 2

            Behavior on x {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            Text {
                anchors.centerIn: parent
                text: modelData.label
                color: "#E8F8FF"
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                width: parent.width - 10
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 120
        height: 120
        radius: width / 2
        color: "#C7141E2B"
        border.color: "#70FFFFFF"
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: "Radial Dock"
            color: "#E8F8FF"
            font.pixelSize: 16
            font.bold: true
        }
    }
}
