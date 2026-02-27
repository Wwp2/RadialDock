import QtQuick
import QtQuick.Controls

Item {
    id: ring
    property real openProgress: 1.0
    property bool isOpen: true
    property int draggedIndex: -1
    property int hoverIndex: -1
    property int removingIndex: -1
    property int removeIndexPending: -1
    property real dragDistance: 0.0

    readonly property real centerX: width / 2
    readonly property real centerY: height / 2
    readonly property real orbitRadius: Math.min(width, height) * 0.37
    readonly property real removeThreshold: Math.min(width, height) * 0.49
    readonly property bool removeCandidate: draggedIndex >= 0 && dragDistance > removeThreshold

    ListModel {
        id: ringItems
        ListElement { label: "Steam"; color: "#FF7B6C" }
        ListElement { label: "Discord"; color: "#8D9BFF" }
        ListElement { label: "Downloads"; color: "#63D5C2" }
        ListElement { label: "Photos"; color: "#F9B26E" }
        ListElement { label: "VS Code"; color: "#62B9FF" }
        ListElement { label: "Music"; color: "#DD8DFF" }
        ListElement { label: "Maps"; color: "#83E37B" }
        ListElement { label: "Docs"; color: "#F0DF87" }
    }

    function angleForSlot(slotIndex, total) {
        var count = Math.max(total, 1)
        return (slotIndex / count) * Math.PI * 2
    }

    function slotPosition(slotIndex) {
        var total = Math.max(ringItems.count, 1)
        var angle = angleForSlot(slotIndex, total) - Math.PI / 2
        return {
            x: centerX + Math.cos(angle) * orbitRadius,
            y: centerY + Math.sin(angle) * orbitRadius
        }
    }

    function slotForIndex(itemIndex) {
        if (draggedIndex < 0 || hoverIndex < 0 || itemIndex === draggedIndex) {
            return itemIndex
        }
        if (draggedIndex < hoverIndex) {
            if (itemIndex > draggedIndex && itemIndex <= hoverIndex) {
                return itemIndex - 1
            }
        } else if (hoverIndex < draggedIndex) {
            if (itemIndex >= hoverIndex && itemIndex < draggedIndex) {
                return itemIndex + 1
            }
        }
        return itemIndex
    }

    function nearestSlotForPoint(px, py) {
        if (ringItems.count <= 1) {
            return 0
        }
        var dx = px - centerX
        var dy = py - centerY
        var angle = Math.atan2(dy, dx) + Math.PI / 2
        if (angle < 0) {
            angle += Math.PI * 2
        }
        var slot = Math.round((angle / (Math.PI * 2)) * ringItems.count) % ringItems.count
        return slot
    }

    function isRemoveCandidateAt(px, py) {
        var dx = px - centerX
        var dy = py - centerY
        var distance = Math.sqrt((dx * dx) + (dy * dy))
        return distance > removeThreshold
    }

    function startDrag(itemIndex) {
        draggedIndex = itemIndex
        hoverIndex = itemIndex
        dragDistance = 0.0
        removingIndex = -1
    }

    function updateDrag(itemIndex, px, py) {
        if (draggedIndex !== itemIndex) {
            return
        }
        var dx = px - centerX
        var dy = py - centerY
        dragDistance = Math.sqrt((dx * dx) + (dy * dy))
        if (isRemoveCandidateAt(px, py)) {
            hoverIndex = -1
            return
        }
        hoverIndex = nearestSlotForPoint(px, py)
    }

    function finishDrag(itemIndex, px, py) {
        if (draggedIndex !== itemIndex) {
            return
        }

        if (isRemoveCandidateAt(px, py)) {
            removingIndex = itemIndex
            removeIndexPending = itemIndex
            hoverIndex = -1
            removeTimer.restart()
            return
        }

        if (hoverIndex >= 0 && hoverIndex !== draggedIndex) {
            ringItems.move(draggedIndex, hoverIndex, 1)
        }
        resetDragState()
    }

    function resetDragState() {
        draggedIndex = -1
        hoverIndex = -1
        dragDistance = 0.0
        removingIndex = -1
        removeIndexPending = -1
    }

    Timer {
        id: removeTimer
        interval: 130
        repeat: false
        onTriggered: {
            if (ring.removeIndexPending >= 0 && ring.removeIndexPending < ringItems.count) {
                ringItems.remove(ring.removeIndexPending, 1)
            }
            ring.resetDragState()
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: ring.width * 0.86
        height: ring.height * 0.86
        radius: width / 2
        color: "transparent"
        border.color: "#2DFFFFFF"
        border.width: 1
        opacity: 0.45 * ring.openProgress
    }

    Rectangle {
        anchors.centerIn: parent
        width: ring.width * 0.96
        height: ring.height * 0.96
        radius: width / 2
        color: "transparent"
        border.color: ring.removeCandidate ? "#D96A6A" : "#00FFFFFF"
        border.width: 2
        opacity: ring.draggedIndex >= 0 ? 0.8 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
        Behavior on border.color {
            ColorAnimation { duration: 120 }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: ring.width * 0.54
        height: ring.height * 0.54
        radius: width / 2
        color: "transparent"
        border.color: "#3FE6FFBF"
        border.width: 1
        opacity: 0.55 * ring.openProgress
    }

    Repeater {
        id: iconRepeater
        model: ringItems
        delegate: Item {
            required property int index
            required property string label
            required property color color
            readonly property int total: iconRepeater.count
            readonly property int targetSlot: ring.slotForIndex(index)
            readonly property var targetPos: ring.slotPosition(targetSlot)
            readonly property real revealStart: (index / Math.max(total, 1)) * 0.36
            readonly property real revealValue: Math.max(0.0, Math.min(1.0, (ring.openProgress - revealStart) / (1.0 - revealStart)))
            property bool dragging: false
            property real dragCenterX: targetPos.x
            property real dragCenterY: targetPos.y
            property real pointerOffsetX: 0.0
            property real pointerOffsetY: 0.0

            width: 60
            height: 60
            x: dragging ? dragCenterX - width / 2 : targetPos.x - width / 2
            y: dragging ? dragCenterY - height / 2 : targetPos.y - height / 2
            z: dragging ? 200 : 100 - index
            opacity: ring.removingIndex === index ? 0.0 : revealValue
            scale: ring.removingIndex === index
                   ? 0.55
                   : (dragging ? 1.12 : (0.65 + (0.35 * revealValue)))

            Behavior on x {
                enabled: !dragging
                NumberAnimation { duration: 210; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                enabled: !dragging
                NumberAnimation { duration: 210; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 170; easing.type: Easing.OutBack }
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.rgba(0.13, 0.18, 0.25, 0.9)
                border.color: color
                border.width: ring.hoverIndex === index && ring.draggedIndex >= 0 ? 2 : 1

                Behavior on border.color {
                    ColorAnimation { duration: 110 }
                }

                Text {
                    anchors.centerIn: parent
                    text: label
                    color: "#E8F8FF"
                    font.pixelSize: 9
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    width: parent.width - 10
                }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                enabled: ring.removingIndex < 0
                hoverEnabled: true
                preventStealing: true
                acceptedButtons: Qt.LeftButton
                cursorShape: dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                onPressed: function(mouse) {
                    var p = dragArea.mapToItem(ring, mouse.x, mouse.y)
                    dragging = true
                    pointerOffsetX = p.x - dragCenterX
                    pointerOffsetY = p.y - dragCenterY
                    ring.startDrag(index)
                    ring.updateDrag(index, dragCenterX, dragCenterY)
                    mouse.accepted = true
                }

                onPositionChanged: function(mouse) {
                    if (!dragging) {
                        return
                    }
                    var p = dragArea.mapToItem(ring, mouse.x, mouse.y)
                    dragCenterX = p.x - pointerOffsetX
                    dragCenterY = p.y - pointerOffsetY
                    ring.updateDrag(index, dragCenterX, dragCenterY)
                }

                onReleased: function() {
                    if (!dragging) {
                        return
                    }
                    dragging = false
                    ring.finishDrag(index, dragCenterX, dragCenterY)
                }

                onCanceled: {
                    if (!dragging) {
                        return
                    }
                    dragging = false
                    ring.resetDragState()
                }
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 124
        height: 124
        radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#DD1A2938" }
            GradientStop { position: 1.0; color: "#B0121C28" }
        }
        border.color: "#8BE0F4FF"
        border.width: 1
        scale: 0.9 + (0.1 * ring.openProgress)
        opacity: 0.8 + (0.2 * ring.openProgress)

        Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutBack }
        }
        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        Text {
            anchors.centerIn: parent
            text: ring.removeCandidate ? "Release to\nRemove" : "Radial Dock"
            color: "#E8F8FF"
            font.pixelSize: ring.removeCandidate ? 14 : 16
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
