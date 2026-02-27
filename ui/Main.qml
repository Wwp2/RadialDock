import QtQuick
import QtQuick.Window
import QtQuick.Controls

Window {
    id: overlay
    property int outerPadding: 110
    property int baseStageWidth: 390
    property int baseStageHeight: 390
    property real animationSpeedScale: (typeof appModel !== "undefined" && appModel.animationSpeedScale)
                                       ? appModel.animationSpeedScale
                                       : 0.2
    property bool animationsEnabled: (typeof appModel !== "undefined")
                                     ? appModel.animationsEnabled
                                     : true
    readonly property int maxStageWidth: Math.max(baseStageWidth, Screen.width - outerPadding - 20)
    readonly property int maxStageHeight: Math.max(baseStageHeight, Screen.height - outerPadding - 20)
    property int targetStageWidth: Math.min(
                                       maxStageWidth,
                                       ringWidget ? ringWidget.preferredStageWidth : baseStageWidth
                                   )
    property int targetStageHeight: Math.min(
                                        maxStageHeight,
                                        ringWidget ? ringWidget.preferredStageHeight : baseStageHeight
                                    )

    width: targetStageWidth + outerPadding
    height: targetStageHeight + outerPadding
    visible: false
    opacity: 0.0
    color: "transparent"
    title: "Radial Dock"
    flags: Qt.FramelessWindowHint | Qt.Tool | Qt.WindowStaysOnTopHint
    property bool overlayOpen: false
    property real openProgress: 0.0
    property bool closing: false

    function animDuration(baseDuration) {
        if (!animationsEnabled) {
            return 0
        }
        return Math.max(1, Math.round(baseDuration * animationSpeedScale))
    }

    function clampWindowToScreen() {
        var maxX = Math.max(0, Screen.width - width)
        var maxY = Math.max(0, Screen.height - height)
        x = Math.max(0, Math.min(x, maxX))
        y = Math.max(0, Math.min(y, maxY))
    }

    function handleBackAction() {
        if (ringWidget && ringWidget.settingsOpen) {
            ringWidget.closeSettingsView()
            return
        }
        if (ringWidget && ringWidget.folderOpen) {
            ringWidget.closeFolderView()
            return
        }
        hideOverlay()
    }

    function animateBackFromFolder() {
        if (!ringWidget || !ringWidget.folderOpen) {
            return
        }
        ringWidget.applyFolderClosed()
        closing = false
        overlayOpen = true
        closeAnim.stop()
        opacity = 0.0
        openProgress = 0.0
        stage.scale = 0.82
        openAnim.restart()
    }

    function animateBackFromSettings() {
        if (!ringWidget || !ringWidget.settingsOpen) {
            return
        }
        ringWidget.applySettingsClosed()
        closing = false
        overlayOpen = true
        closeAnim.stop()
        opacity = 0.0
        openProgress = 0.0
        stage.scale = 0.82
        openAnim.restart()
    }

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
        onActivated: overlay.handleBackAction()
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: overlay
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: overlay.animDuration(160)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: stage
            property: "scale"
            from: 0.82
            to: 1.0
            duration: overlay.animDuration(220)
            easing.type: Easing.OutBack
        }
        NumberAnimation {
            target: overlay
            property: "openProgress"
            from: 0.0
            to: 1.0
            duration: overlay.animDuration(300)
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation {
            target: overlay
            property: "opacity"
            to: 0.0
            duration: overlay.animDuration(130)
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: stage
            property: "scale"
            to: 0.9
            duration: overlay.animDuration(130)
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: overlay
            property: "openProgress"
            to: 0.0
            duration: overlay.animDuration(130)
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
        width: overlay.targetStageWidth
        height: overlay.targetStageHeight

        Behavior on width {
            NumberAnimation { duration: overlay.animDuration(120); easing.type: Easing.OutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: overlay.animDuration(120); easing.type: Easing.OutCubic }
        }

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
            acceptedButtons: Qt.LeftButton
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
            animationSpeedScale: overlay.animationSpeedScale
            animationsEnabled: overlay.animationsEnabled
            onFolderBackRequested: overlay.animateBackFromFolder()
            onSettingsBackRequested: overlay.animateBackFromSettings()
        }

        DropArea {
            id: externalDropArea
            anchors.fill: parent

            onEntered: function(drag) {
                if (drag.hasUrls) {
                    drag.accepted = true
                }
            }

            onDropped: function(drop) {
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

        MouseArea {
            z: 1200
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: function(mouse) {
                mouse.accepted = true
                overlay.handleBackAction()
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
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                overlay.handleBackAction()
                return
            }
            overlay.hideOverlay()
        }
    }

    onWidthChanged: clampWindowToScreen()
    onHeightChanged: clampWindowToScreen()
}
