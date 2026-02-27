import QtQuick
import QtQuick.Controls

Item {
    id: folderView
    property var entries: []
    property string title: "Folder"
    property bool compactMode: false
    signal tileActivated(string path, string kind)

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: "#DD101822"
        border.color: "#88C5DFFF"
        border.width: 1
    }

    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 10
        height: 20

        Text {
            id: folderTitleText
            anchors.left: parent.left
            anchors.right: backHint.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: folderView.title
            color: "#EAF4FF"
            font.pixelSize: 13
            elide: Text.ElideMiddle
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignLeft
        }

        Text {
            id: modeText
            anchors.right: parent.right
            anchors.left: backHint.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: folderView.compactMode ? "Compact list mode" : "Tile mode"
            color: "#9FC4D8"
            font.pixelSize: 11
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }

        Text {
            id: backHint
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            text: "Right click: Back"
            color: "#89A4B2"
            font.pixelSize: 9
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
        }
    }

    GridView {
        visible: !folderView.compactMode
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        model: entries
        cellWidth: 104
        cellHeight: 104
        clip: true
        delegate: Tile {
            text: modelData.label || "Item"
            imageSource: modelData.icon || ""
            onActivated: folderView.tileActivated(modelData.path || "", modelData.kind || "file")
        }
    }

    ListView {
        visible: folderView.compactMode
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        clip: true
        model: entries
        spacing: 2

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        delegate: Item {
            width: ListView.view.width
            height: 24

            Rectangle {
                anchors.fill: parent
                radius: 5
                color: compactMouse.containsMouse ? "#373F4A" : "#242E3A"
                border.color: compactMouse.containsMouse ? "#6EA6C4" : "#304050"
                border.width: 1
            }

            Image {
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                source: modelData.icon || ""
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 26
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.label || "Item"
                color: "#EAF4FF"
                font.pixelSize: 10
                elide: Text.ElideRight
            }

            HoverHandler {
                id: compactMouse
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onClicked: folderView.tileActivated(modelData.path || "", modelData.kind || "file")
            }
        }
    }
}
