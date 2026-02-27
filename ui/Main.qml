import QtQuick
import QtQuick.Window
import QtQuick.Controls

Window {
    id: overlay
    width: 500
    height: 500
    visible: false
    opacity: 0.0
    color: "transparent"
    title: "Radial Dock"
    flags: Qt.FramelessWindowHint | Qt.Tool | Qt.WindowStaysOnTopHint
    property bool overlayOpen: false
    property real openProgress: 0.0
    property bool closing: false
    property bool externalDragActive: false

    function showAtCursor(cx, cy) {
        var targetX = cx - width / 2
        var targetY = cy - height / 2
        x = Math.max(0, Math.min(targetX, Screen.width - width))
        y = Math.max(0, Math.min(targetY, Screen.height - height))
        overlayOpen = true
        closing = false
        openProgress = 0.0
        stage.scale = 0.82
        opacity = 0.0
        visible = true
        raise()
        requestActivate()
        closeAnim.stop()
        openAnim.restart()
    }

    function hideOverlay() {
        if (!visible || closing) {
            return
        }
        closing = true
        overlayOpen = false
        openAnim.stop()
        closeAnim.restart()
    }

    function toggleAtCursor(cx, cy) {
        if (visible) {
            hideOverlay()
        } else {
            showAtCursor(cx, cy)
        }
    }

    Connections {
        target: backend
        function onHotkeyTriggered(x, y) {
            overlay.toggleAtCursor(x, y)
        }
        function onHideRequested() {
            overlay.hideOverlay()
        }
    }

    // Keep overlay open while dragging from external apps (Explorer).
    // Close behavior is handled by Esc, hotkey toggle, or overlay background click.

    Shortcut {
        sequence: "Esc"
        onActivated: overlay.hideOverlay()
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: overlay
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 160
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: stage
            property: "scale"
            from: 0.82
            to: 1.0
            duration: 220
            easing.type: Easing.OutBack
        }
        NumberAnimation {
            target: overlay
            property: "openProgress"
            from: 0.0
            to: 1.0
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation {
            target: overlay
            property: "opacity"
            to: 0.0
            duration: 130
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: stage
            property: "scale"
            to: 0.9
            duration: 130
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: overlay
            property: "openProgress"
            to: 0.0
            duration: 130
            easing.type: Easing.InCubic
        }
        onFinished: {
            overlay.visible = false
            overlay.closing = false
        }
    }

    Item {
        id: stage
        z: 1
        anchors.centerIn: parent
        width: 390
        height: 390

        Rectangle {
            id: backdrop
            anchors.fill: parent
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#D9162130" }
                GradientStop { position: 1.0; color: "#A40F151E" }
            }
            border.color: "#84C2F4D4"
            border.width: 1
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: function(mouse) {
                mouse.accepted = true
            }
        }

        RadialRing {
            id: ringWidget
            anchors.fill: parent
            anchors.margins: 18
            openProgress: overlay.openProgress
            isOpen: overlay.overlayOpen
        }

        DropArea {
            id: externalDropArea
            anchors.fill: parent

            onEntered: function(drag) {
                if (drag.hasUrls) {
                    overlay.externalDragActive = true
                    drag.accepted = true
                }
            }

            onExited: {
                overlay.externalDragActive = false
            }

            onDropped: function(drop) {
                overlay.externalDragActive = false
                if (!drop.hasUrls) {
                    return
                }
                ringWidget.addDroppedUrls(drop.urls)
                drop.accepted = true
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: externalDropArea.containsDrag ? "#C76DFFAD" : "#00FFFFFF"
            opacity: externalDropArea.containsDrag ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
            }
            Behavior on border.color {
                ColorAnimation { duration: 100 }
            }
        }
    }

    MouseArea {
        z: 0
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        propagateComposedEvents: false
        onPressed: function(mouse) {
            mouse.accepted = true
        }
        onClicked: overlay.hideOverlay()
    }
}
