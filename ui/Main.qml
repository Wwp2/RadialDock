import QtQuick
import QtQuick.Window
import QtQuick.Controls

Window {
    id: overlay
    width: 440
    height: 440
    visible: false
    color: "transparent"
    title: "Radial Dock"
    flags: Qt.FramelessWindowHint | Qt.Tool | Qt.WindowStaysOnTopHint

    function showAtCursor(cx, cy) {
        var targetX = cx - width / 2
        var targetY = cy - height / 2
        x = Math.max(0, Math.min(targetX, Screen.width - width))
        y = Math.max(0, Math.min(targetY, Screen.height - height))
        opacity = 0.0
        visible = true
        raise()
        requestActivate()
        openAnim.start()
    }

    function hideOverlay() {
        if (!visible) {
            return
        }
        closeAnim.start()
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

    onActiveChanged: {
        if (!active && visible) {
            hideOverlay()
        }
    }

    Shortcut {
        sequence: "Esc"
        onActivated: overlay.hideOverlay()
    }

    NumberAnimation {
        id: openAnim
        target: overlay
        property: "opacity"
        from: 0.0
        to: 1.0
        duration: 140
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: closeAnim
        NumberAnimation {
            target: overlay
            property: "opacity"
            to: 0.0
            duration: 120
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: overlay.visible = false
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse.accepted = true
        onClicked: overlay.hideOverlay()
    }

    Rectangle {
        id: backdrop
        anchors.centerIn: parent
        width: 330
        height: 330
        radius: width / 2
        color: "#BF121923"
        border.color: "#5AF2F4A2"
        border.width: 1

        RadialRing {
            anchors.fill: parent
            anchors.margins: 22
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: mouse.accepted = true
        }
    }
}
