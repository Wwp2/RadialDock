import QtQuick

Item {
    id: tile
    property alias text: title.text
    property url imageSource: ""

    width: 96
    height: 96
    scale: tileMouse.containsMouse ? 1.08 : 1.0

    Behavior on scale {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: "#DD1F2C3A"
        border.color: tileMouse.containsMouse ? "#A3F7E7AE" : "#55FFFFFF"
        border.width: 1
    }

    Image {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 10
        width: 44
        height: 44
        source: imageSource
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Text {
        id: title
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        color: "#EAF4FF"
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }

    HoverHandler {
        id: tileMouse
    }
}
