import QtQuick
import QtQuick.Window
import QtQuick.Controls

Window {
    id: overlay
    property int outerPadding: 110
    property int baseStageWidth: 390
    property int baseStageHeight: 390
    property int backdropResizeBaseDuration: 600
    property int folderBackdropKickoffDelay: 16
    property real animationSpeedScale: (typeof appModel !== "undefined" && appModel && appModel.animationSpeedScale)
                                       ? appModel.animationSpeedScale
                                       : 0.2
    property bool animationsEnabled: (typeof appModel !== "undefined" && appModel)
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
    property bool mainRevealActive: false
    property bool snapBackdropResize: false
    property bool startupMessageVisible: false
    property bool mainSceneVisible: true
    property bool folderSceneVisible: false
    property bool folderSceneReturningToMain: false
    property real folderSceneCenterX: 0
    property real folderSceneCenterY: 0
    property bool folderBackdropVisible: false
    property real folderBackdropX: 0
    property real folderBackdropY: 0
    property real folderBackdropWidth: baseStageWidth
    property real folderBackdropHeight: baseStageHeight
    property real folderBackdropOpacity: 0.0
    property bool folderBackdropExpanding: false

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

    function shouldShowStartupMessage() {
        return !!(typeof appModel !== "undefined" && appModel && appModel.startupMessageEnabled)
    }

    function positionFolderScene() {
        var targetX = Math.round(folderSceneCenterX - (folderSceneWindow.width / 2))
        var targetY = Math.round(folderSceneCenterY - (folderSceneWindow.height / 2))
        var clampedSceneX = Math.max(0, Math.min(targetX, Screen.width - folderSceneWindow.width))
        var clampedSceneY = Math.max(0, Math.min(targetY, Screen.height - folderSceneWindow.height))
        folderSceneWindow.x = clampedSceneX
        folderSceneWindow.y = clampedSceneY
    }

    function syncFolderBackdropToScene() {
        folderBackdropX = folderSceneWindow.x
        folderBackdropY = folderSceneWindow.y
        folderBackdropWidth = folderSceneWindow.width
        folderBackdropHeight = folderSceneWindow.height
    }

    function showFolderBackdrop() {
        var startWidth = Math.max(1, backdrop.width)
        var startHeight = Math.max(1, backdrop.height)
        folderBackdropExpandAnim.stop()
        folderBackdropExpandTimer.stop()
        folderBackdropExpanding = animationsEnabled
        folderBackdropX = Math.round(folderSceneCenterX - (startWidth / 2))
        folderBackdropY = Math.round(folderSceneCenterY - (startHeight / 2))
        folderBackdropWidth = startWidth
        folderBackdropHeight = startHeight
        folderBackdropOpacity = 1.0
        folderBackdropVisible = true
        if (animationsEnabled) {
            folderBackdropExpandTimer.restart()
        } else {
            folderBackdropExpanding = false
            syncFolderBackdropToScene()
        }
    }

    function hideFolderBackdrop() {
        folderBackdropExpandAnim.stop()
        folderBackdropExpandTimer.stop()
        folderBackdropExpanding = false
        folderBackdropVisible = false
        folderBackdropOpacity = 0.0
    }

    function showFolderScene() {
        folderSceneReturningToMain = false
        folderSceneCenterX = x + (width / 2)
        folderSceneCenterY = y + (height / 2)
        positionFolderScene()
        showFolderBackdrop()
        mainSceneVisible = false
        folderSceneVisible = true
        folderSceneWindow.raise()
    }

    function handleBackAction() {
        if (startupMessageVisible) {
            startupMessageVisible = false
            return
        }
        if (ringWidget && ringWidget.groupNamingVisible) {
            ringWidget.cancelGroupNaming()
            return
        }
        if (ringWidget && ringWidget.groupOpen) {
            ringWidget.closeGroupView()
            return
        }
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

    function playMainRingReveal() {
        closing = false
        overlayOpen = true
        mainRevealActive = true
        mainSceneVisible = true
        closeAnim.stop()
        opacity = 0.0
        openProgress = 0.0
        stage.scale = 0.82
        visible = true
        raise()
        requestActivate()
        openAnim.restart()
    }

    function returnToMainRing(source) {
        if (!ringWidget) {
            return
        }

        mainRevealActive = true
        if (source === "folder") {
            if (!ringWidget.folderOpen) {
                mainRevealActive = false
                return
            }
            snapBackdropResize = true
            ringWidget.applyFolderClosed()
        } else if (source === "settings") {
            if (!ringWidget.settingsOpen) {
                mainRevealActive = false
                return
            }
            snapBackdropResize = true
            ringWidget.applySettingsClosed()
        }

        playMainRingReveal()
    }

    function animateBackFromFolder() {
        if (!ringWidget || !ringWidget.folderOpen) {
            return
        }
        folderSceneReturningToMain = true
        hideFolderBackdrop()
        folderSceneVisible = false
        if (!animationsEnabled) {
            ringWidget.applyFolderClosed()
            folderSceneReturningToMain = false
            playMainRingReveal()
            return
        }
        folderSceneReturnTimer.restart()
    }

    function animateBackFromSettings() {
        returnToMainRing("settings")
    }

    function showAtCursor(cx, cy) {
        if (typeof appModel !== "undefined" && appModel && appModel.refreshEnabledData) {
            appModel.refreshEnabledData()
        }
        if (ringWidget) {
            ringWidget.resetToMainView()
        }
        startupMessageVisible = shouldShowStartupMessage()
        var targetX = cx - width / 2
        var targetY = cy - height / 2
        x = Math.max(0, Math.min(targetX, Screen.width - width))
        y = Math.max(0, Math.min(targetY, Screen.height - height))
        snapBackdropResize = false
        playMainRingReveal()
    }

    function showCenteredStartup() {
        if (typeof appModel !== "undefined" && appModel && appModel.refreshEnabledData) {
            appModel.refreshEnabledData()
        }
        if (ringWidget) {
            ringWidget.resetToMainView()
        }
        x = Math.max(0, Math.round((Screen.width - width) / 2))
        y = Math.max(0, Math.round((Screen.height - height) / 2))
        startupMessageVisible = shouldShowStartupMessage()
        snapBackdropResize = false
        playMainRingReveal()
    }

    function hideOverlay() {
        if (!visible || closing) {
            return
        }
        hideFolderBackdrop()
        folderSceneVisible = false
        folderSceneReturningToMain = false
        mainSceneVisible = true
        closing = true
        overlayOpen = false
        mainRevealActive = false
        snapBackdropResize = false
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
        function onShortcutLaunchRequested() {
            overlay.showCenteredStartup()
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
        onFinished: {
            overlay.mainRevealActive = false
            overlay.snapBackdropResize = false
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
            overlay.mainSceneVisible = true
            overlay.folderSceneVisible = false
            overlay.folderSceneReturningToMain = false
            if (ringWidget) {
                ringWidget.resetToMainView()
            }
        }
    }

    Timer {
        id: folderSceneReturnTimer
        interval: overlay.animDuration(130)
        repeat: false
        onTriggered: {
            if (ringWidget) {
                ringWidget.applyFolderClosed()
            }
            overlay.folderSceneReturningToMain = false
            overlay.playMainRingReveal()
        }
    }

    Timer {
        id: folderBackdropExpandTimer
        interval: overlay.folderBackdropKickoffDelay
        repeat: false
        onTriggered: {
            folderBackdropXAnim.from = overlay.folderBackdropX
            folderBackdropXAnim.to = folderSceneWindow.x
            folderBackdropYAnim.from = overlay.folderBackdropY
            folderBackdropYAnim.to = folderSceneWindow.y
            folderBackdropWidthAnim.from = overlay.folderBackdropWidth
            folderBackdropWidthAnim.to = folderSceneWindow.width
            folderBackdropHeightAnim.from = overlay.folderBackdropHeight
            folderBackdropHeightAnim.to = folderSceneWindow.height
            folderBackdropExpandAnim.restart()
            folderSceneWindow.raise()
        }
    }

    ParallelAnimation {
        id: folderBackdropExpandAnim
        NumberAnimation {
            id: folderBackdropXAnim
            target: overlay
            property: "folderBackdropX"
            duration: overlay.animDuration(overlay.backdropResizeBaseDuration)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: folderBackdropYAnim
            target: overlay
            property: "folderBackdropY"
            duration: overlay.animDuration(overlay.backdropResizeBaseDuration)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: folderBackdropWidthAnim
            target: overlay
            property: "folderBackdropWidth"
            duration: overlay.animDuration(overlay.backdropResizeBaseDuration)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: folderBackdropHeightAnim
            target: overlay
            property: "folderBackdropHeight"
            duration: overlay.animDuration(overlay.backdropResizeBaseDuration)
            easing.type: Easing.OutCubic
        }
        onFinished: {
            overlay.folderBackdropExpanding = false
            overlay.syncFolderBackdropToScene()
            folderSceneWindow.raise()
        }
    }

    Window {
        id: folderBackdropWindow
        transientParent: overlay
        visible: overlay.folderBackdropVisible || opacity > 0.0
        x: overlay.folderBackdropX
        y: overlay.folderBackdropY
        width: overlay.folderBackdropWidth
        height: overlay.folderBackdropHeight
        opacity: overlay.folderBackdropOpacity
        color: "transparent"
        flags: Qt.FramelessWindowHint | Qt.Tool | Qt.WindowStaysOnTopHint | Qt.WindowTransparentForInput

        Behavior on opacity {
            NumberAnimation {
                duration: overlay.animDuration(130)
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Math.min(width, height) / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#D9162130" }
                GradientStop { position: 1.0; color: "#A40F151E" }
            }
            border.color: "#84C2F4D4"
            border.width: 1
        }
    }

    Window {
        id: folderSceneWindow
        transientParent: overlay
        visible: overlay.folderSceneVisible || opacity > 0.0
        width: Math.min(Screen.width - 20, ringWidget ? ringWidget.folderPanelWidth : overlay.baseStageWidth)
        height: Math.min(Screen.height - 20, ringWidget ? ringWidget.folderPanelHeight : overlay.baseStageHeight)
        opacity: overlay.folderSceneVisible ? 1.0 : 0.0
        color: "transparent"
        flags: Qt.FramelessWindowHint | Qt.Tool | Qt.WindowStaysOnTopHint

        onWidthChanged: {
            overlay.positionFolderScene()
            if (overlay.folderBackdropVisible && !overlay.folderBackdropExpanding) {
                overlay.syncFolderBackdropToScene()
            }
        }
        onHeightChanged: {
            overlay.positionFolderScene()
            if (overlay.folderBackdropVisible && !overlay.folderBackdropExpanding) {
                overlay.syncFolderBackdropToScene()
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: overlay.animDuration(130)
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: function(mouse) {
                mouse.accepted = true
                overlay.handleBackAction()
            }
        }

        FolderView {
            anchors.fill: parent
            title: ringWidget ? ringWidget.folderTitle : "Folder"
            entries: ringWidget ? ringWidget.folderEntries : []
            loading: ringWidget ? ringWidget.folderLoading : false
            refreshStatus: ringWidget ? ringWidget.folderRefreshStatus : ""
            compactMode: ringWidget ? ringWidget.compactListMode : false
            onTileActivated: function(path, kind) {
                if (ringWidget) {
                    ringWidget.openFolderEntry(path, kind)
                }
            }
        }
    }

    Item {
        id: stage
        z: 1
        anchors.centerIn: parent
        width: overlay.targetStageWidth
        height: overlay.targetStageHeight
        opacity: overlay.mainSceneVisible ? 1.0 : 0.0
        property real targetBackdropWidth: width
        property real targetBackdropHeight: height
        property real backdropVisualWidth: targetBackdropWidth
        property real backdropVisualHeight: targetBackdropHeight

        Behavior on opacity {
            enabled: overlay.animationsEnabled && !(overlay.mainSceneVisible && overlay.mainRevealActive)
            NumberAnimation {
                duration: overlay.animDuration(120)
                easing.type: Easing.OutCubic
            }
        }

        Behavior on backdropVisualWidth {
            enabled: overlay.animationsEnabled && !overlay.snapBackdropResize
            NumberAnimation {
                duration: overlay.animDuration(overlay.backdropResizeBaseDuration)
                easing.type: Easing.OutCubic
            }
        }
        Behavior on backdropVisualHeight {
            enabled: overlay.animationsEnabled && !overlay.snapBackdropResize
            NumberAnimation {
                duration: overlay.animDuration(overlay.backdropResizeBaseDuration)
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            id: backdrop
            anchors.centerIn: parent
            width: stage.backdropVisualWidth
            height: stage.backdropVisualHeight
            radius: Math.min(width, height) / 2
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
            mainRevealActive: overlay.mainRevealActive
            onFolderBackRequested: overlay.animateBackFromFolder()
            onSettingsBackRequested: overlay.animateBackFromSettings()
        }

        Connections {
            target: ringWidget
            function onFolderSceneOpened() {
                overlay.showFolderScene()
            }
            function onFolderSceneClosed() {
                overlay.hideFolderBackdrop()
                overlay.folderSceneVisible = false
                overlay.folderSceneReturningToMain = false
            }
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

        Rectangle {
            id: startupCard
            z: 1800
            visible: overlay.startupMessageVisible
            anchors.centerIn: parent
            width: Math.min(parent.width - 36, 360)
            height: 292
            radius: 16
            color: "#F41A2430"
            border.color: "#88D5E6F4"
            border.width: 1

            Column {
                z: 1
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Text {
                    text: "Welcome To RadialDock"
                    color: "#F2FAFF"
                    font.pixelSize: 16
                    font.bold: true
                }

                Text {
                    width: parent.width
                    text: "RadialDock is a quick launcher that opens a radial menu near your cursor so you can start apps, open files, and browse pinned folders fast."
                    color: "#D5E7F3"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    text: "Default launch shortcut: Ctrl+Space. You can change it in the Settings panel by clicking the center of the radial menu."
                    color: "#D5E7F3"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    text: "To get started, drag files, folders, or shortcuts from Explorer into the ring to add them. Drag a pinned item out of the ring to remove it."
                    color: "#D5E7F3"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    text: "You can also create groups of icons. First click and hold on the center of the radial dock to enter group edit mode. You can then combine your icons together and rename groups."
                    color: "#D5E7F3"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    text: "Right click works as a back button. Press Esc, right click or click outside the menu to close it."
                    color: "#A8C1D4"
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }

                Item {
                    width: parent.width
                    height: 1
                }

                CheckBox {
                    id: startupDisableCheckbox
                    text: "Turn Off Startup Message"
                    checked: (typeof appModel !== "undefined" && appModel)
                             ? !appModel.startupMessageEnabled
                             : false
                    onToggled: {
                        if (typeof appModel !== "undefined" && appModel) {
                            appModel.startupMessageEnabled = !checked
                        }
                    }
                }

                Rectangle {
                    width: 118
                    height: 32
                    radius: 6
                    color: startupContinueMouse.pressed ? "#2A3946" : (startupContinueMouse.containsMouse ? "#324555" : "#273643")
                    border.color: startupContinueMouse.containsMouse ? "#6B90AA" : "#4A6478"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Continue"
                        color: "#EAF4FF"
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: startupContinueMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        onClicked: overlay.startupMessageVisible = false
                    }
                }
            }

            MouseArea {
                z: 0
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: function(mouse) {
                    mouse.accepted = true
                }
                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                        overlay.handleBackAction()
                    }
                    mouse.accepted = true
                }
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
