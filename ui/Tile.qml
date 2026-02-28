import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: tile
    property alias text: title.text
    property url imageSource: ""
    property string itemPath: ""
    property string itemKind: "file"
    signal activated()
    readonly property int previewRevision: (typeof appModel !== "undefined" && appModel)
                                           ? appModel.previewVersion
                                           : 0
    readonly property var imageExtensions: [
        ".png",
        ".jpg",
        ".jpeg",
        ".bmp",
        ".gif",
        ".webp",
        ".tif",
        ".tiff"
    ]
    readonly property bool fullBleedImage: {
        if ((itemKind || "").toLowerCase() !== "file" || !itemPath) {
            return false
        }
        var normalized = String(itemPath).toLowerCase()
        for (var i = 0; i < imageExtensions.length; i++) {
            if (normalized.endsWith(imageExtensions[i])) {
                return true
            }
        }
        return false
    }
    readonly property url resolvedImageSource: {
        var _ = previewRevision
        if (typeof appModel !== "undefined" && appModel && appModel.iconDataUrl && itemPath) {
            return appModel.iconDataUrl(itemPath, itemKind || "file", tile.text || "Item")
        }
        return imageSource
    }

    width: 96
    height: 96
    scale: tileMouse.containsMouse ? 1.14 : 1.0

    Behavior on scale {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: "#DD1F2C3A"
        border.width: 0
    }

    Item {
        visible: fullBleedImage
        anchors.fill: parent
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: tile.width
                height: tile.height
                radius: 14
                color: "white"
            }
        }

        Image {
            anchors.fill: parent
            source: tile.resolvedImageSource
            fillMode: Image.PreserveAspectCrop
            smooth: true
            asynchronous: true
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 24
            color: "#7A0C1218"
        }
    }

    Image {
        visible: !fullBleedImage
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 10
        width: 44
        height: 44
        source: tile.resolvedImageSource
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
    }

    Text {
        id: title
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: fullBleedImage ? 6 : 8
        anchors.leftMargin: fullBleedImage ? 6 : 0
        anchors.rightMargin: fullBleedImage ? 6 : 0
        color: "#EAF4FF"
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: "transparent"
        border.color: tileMouse.containsMouse ? "#A3F7E7AE" : "#55FFFFFF"
        border.width: 1
    }

    HoverHandler {
        id: tileMouse
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: tile.activated()
    }
}
