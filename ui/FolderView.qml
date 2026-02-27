import QtQuick
import QtQuick.Controls

Item {
    id: folderView
    property var entries: []

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: "#C3111720"
        border.color: "#55FFFFFF"
        border.width: 1
    }

    GridView {
        anchors.fill: parent
        anchors.margins: 12
        model: entries
        cellWidth: 104
        cellHeight: 104
        clip: true
        delegate: Tile {
            text: modelData.label || "Item"
            imageSource: modelData.icon || ""
        }
    }
}
