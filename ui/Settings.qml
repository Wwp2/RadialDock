import QtQuick
import QtQuick.Controls

Item {
    id: settings
    signal clearAllConfirmed()
    signal resetDefaultsConfirmed()
    property bool confirmClear: false
    property bool confirmReset: false
    property bool capturingHotkey: false
    property bool hotkeyCaptureReady: false
    property string displayedHotkey: "Ctrl+Space"
    property string hotkeyStatus: ""
    property bool hotkeyError: false
    property string transferStatus: ""
    property bool transferError: false

    function clampSpeed(value) {
        return Math.max(0.1, Math.min(10.0, value))
    }

    function clampThreshold(value) {
        return Math.max(1, Math.min(5000, value))
    }

    function commitSpeed() {
        if (typeof appModel === "undefined" || !appModel) {
            return
        }
        var parsed = Number.parseFloat(speedField.text)
        if (Number.isNaN(parsed)) {
            speedField.text = Number(appModel.animationSpeedScale).toFixed(2)
            return
        }
        parsed = clampSpeed(parsed)
        appModel.animationSpeedScale = parsed
        speedField.text = Number(parsed).toFixed(2)
    }

    function commitThreshold() {
        if (typeof appModel === "undefined" || !appModel) {
            return
        }
        var parsed = Number.parseInt(thresholdField.text)
        if (Number.isNaN(parsed)) {
            thresholdField.text = String(appModel.folderCompactThreshold)
            return
        }
        parsed = clampThreshold(parsed)
        appModel.folderCompactThreshold = parsed
        thresholdField.text = String(parsed)
    }

    function beginHotkeyCapture() {
        capturingHotkey = true
        hotkeyCaptureReady = false
        hotkeyError = false
        hotkeyStatus = "Press a key or mouse button..."
        hotkeyCaptureTarget.forceActiveFocus()
        hotkeyCaptureArmTimer.restart()
    }

    function finishHotkeyCapture(shortcutText) {
        if (typeof backend === "undefined" || !backend || !backend.trySetHotkey) {
            capturingHotkey = false
            hotkeyCaptureReady = false
            hotkeyError = true
            hotkeyStatus = "Shortcut handler is unavailable."
            return
        }
        capturingHotkey = false
        hotkeyCaptureReady = false
        backend.trySetHotkey(shortcutText)
    }

    function keyNameFromEvent(event) {
        var key = event.key
        if (key >= Qt.Key_A && key <= Qt.Key_Z) {
            return String.fromCharCode(key)
        }
        if (key >= Qt.Key_0 && key <= Qt.Key_9) {
            return String.fromCharCode(key)
        }
        if (key >= Qt.Key_F1 && key <= Qt.Key_F24) {
            return "F" + String(key - Qt.Key_F1 + 1)
        }

        switch (key) {
        case Qt.Key_Space: return "Space"
        case Qt.Key_Tab: return "Tab"
        case Qt.Key_Return:
        case Qt.Key_Enter: return "Enter"
        case Qt.Key_Escape: return "Esc"
        case Qt.Key_Backspace: return "Backspace"
        case Qt.Key_Insert: return "Insert"
        case Qt.Key_Delete: return "Delete"
        case Qt.Key_Home: return "Home"
        case Qt.Key_End: return "End"
        case Qt.Key_PageUp: return "PgUp"
        case Qt.Key_PageDown: return "PgDn"
        case Qt.Key_Left: return "Left"
        case Qt.Key_Up: return "Up"
        case Qt.Key_Right: return "Right"
        case Qt.Key_Down: return "Down"
        default: return ""
        }
    }

    function isModifierOnlyKey(event) {
        return event.key === Qt.Key_Control
            || event.key === Qt.Key_Shift
            || event.key === Qt.Key_Alt
            || event.key === Qt.Key_Meta
    }

    function shortcutFromKeyEvent(event) {
        if (isModifierOnlyKey(event)) {
            return ""
        }
        var keyName = keyNameFromEvent(event)
        if (!keyName) {
            return ""
        }

        var parts = []
        if (event.modifiers & Qt.ControlModifier) {
            parts.push("Ctrl")
        }
        if (event.modifiers & Qt.AltModifier) {
            parts.push("Alt")
        }
        if (event.modifiers & Qt.ShiftModifier) {
            parts.push("Shift")
        }
        if (event.modifiers & Qt.MetaModifier) {
            parts.push("Win")
        }
        parts.push(keyName)
        return parts.join("+")
    }

    function shortcutFromMouseButton(button) {
        switch (button) {
        case Qt.LeftButton: return "MouseLeft"
        case Qt.RightButton: return "MouseRight"
        case Qt.MiddleButton: return "MouseMiddle"
        case Qt.BackButton: return "MouseX1"
        case Qt.ForwardButton: return "MouseX2"
        default: return ""
        }
    }

    function refreshFromModel() {
        if (typeof appModel !== "undefined" && appModel) {
            displayedHotkey = appModel.hotkey
            speedField.text = Number(appModel.animationSpeedScale).toFixed(2)
            thresholdField.text = String(appModel.folderCompactThreshold)
            animationsSwitch.checked = !!appModel.animationsEnabled
            iconRefreshSwitch.checked = !!appModel.automaticIconRefresh
            folderRefreshSwitch.checked = !!appModel.automaticFolderRefresh
            closeAfterLaunchSwitch.checked = !!appModel.closeAfterLaunch
            automaticAlignmentSwitch.checked = !!appModel.automaticItemAlignment
        }
        if (typeof backend !== "undefined" && backend && startupOnBootSwitch) {
            startupOnBootSwitch.checked = !!backend.launchOnStartupEnabled
        }
    }

    onVisibleChanged: {
        if (visible) {
            refreshFromModel()
        }
    }

    Connections {
        target: appModel
        function onAnimationSpeedScaleChanged() {
            settings.refreshFromModel()
        }
        function onFolderCompactThresholdChanged() {
            settings.refreshFromModel()
        }
        function onAnimationsEnabledChanged() {
            settings.refreshFromModel()
        }
        function onAutomaticIconRefreshChanged() {
            settings.refreshFromModel()
        }
        function onAutomaticFolderRefreshChanged() {
            settings.refreshFromModel()
        }
        function onCloseAfterLaunchChanged() {
            settings.refreshFromModel()
        }
        function onAutomaticItemAlignmentChanged() {
            settings.refreshFromModel()
        }
        function onHotkeyChanged() {
            settings.refreshFromModel()
        }
    }

    Connections {
        target: backend
        function onHotkeyApplyResult(success, message, normalized) {
            settings.capturingHotkey = false
            settings.hotkeyCaptureReady = false
            settings.hotkeyError = !success
            settings.hotkeyStatus = message
            if (success) {
                settings.displayedHotkey = normalized
            } else if (typeof appModel !== "undefined" && appModel) {
                settings.displayedHotkey = appModel.hotkey
            }
        }
        function onLaunchOnStartupChanged() {
            settings.refreshFromModel()
        }
        function onSettingsTransferResult(success, message) {
            settings.transferError = !success
            settings.transferStatus = message
            if (success) {
                settings.refreshFromModel()
            }
        }
    }

    Timer {
        id: hotkeyCaptureArmTimer
        interval: 1
        repeat: false
        onTriggered: settings.hotkeyCaptureReady = true
    }

    component ActionButton: Rectangle {
        id: actionButton
        signal clicked()
        property string text: ""
        radius: 6
        color: actionMouse.pressed ? "#2A3946" : (actionMouse.containsMouse ? "#324555" : "#273643")
        border.color: actionMouse.containsMouse ? "#6B90AA" : "#4A6478"
        border.width: 1
        implicitHeight: 28
        implicitWidth: Math.max(84, label.implicitWidth + 18)

        Text {
            id: label
            anchors.centerIn: parent
            text: actionButton.text
            color: "#EAF4FF"
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onClicked: actionButton.clicked()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: "#EE101820"
        border.color: "#88C2D4E4"
        border.width: 1
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text {
            text: "Settings"
            color: "#EAF4FF"
            font.pixelSize: 16
            font.bold: true
        }

        Rectangle {
            width: parent.width
            height: 1
            color: "#33596F7A"
        }

        Row {
            width: parent.width
            height: 36
            spacing: 10

            Text {
                text: "Shortcut"
                color: "#D7E8F4"
                font.pixelSize: 12
                width: 150
                anchors.verticalCenter: parent.verticalCenter
            }

            FocusScope {
                id: hotkeyCaptureTarget
                width: 120
                height: 30
                anchors.verticalCenter: parent.verticalCenter
                activeFocusOnTab: true

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: hotkeyCaptureMouse.pressed ? "#243543" : (hotkeyCaptureMouse.containsMouse ? "#2B4152" : "#1E2C38")
                    border.color: settings.capturingHotkey ? "#8BE0F4FF" : "#4A6478"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: settings.capturingHotkey ? "Press input..." : settings.displayedHotkey
                        color: "#EAF4FF"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }

                Keys.onPressed: function(event) {
                    if (!settings.capturingHotkey) {
                        return
                    }
                    var shortcut = settings.shortcutFromKeyEvent(event)
                    if (!shortcut) {
                        event.accepted = true
                        return
                    }
                    settings.finishHotkeyCapture(shortcut)
                    event.accepted = true
                }

                MouseArea {
                    id: hotkeyCaptureMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    onClicked: settings.beginHotkeyCapture()
                }
            }

            ActionButton {
                text: "Reset"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    if (typeof backend !== "undefined" && backend && backend.resetHotkeyToDefault) {
                        backend.resetHotkeyToDefault()
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: 26

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 160
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Click the shortcut box, then press the next key, key combo, or mouse button. Left/right mouse are reserved for the UI. Default: Ctrl+Space."
                color: "#8DA7B9"
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }
        }

        Item {
            width: parent.width
            height: hotkeyStatus.length > 0 ? 14 : 0
            visible: hotkeyStatus.length > 0

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 160
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: hotkeyStatus
                color: hotkeyError ? "#FFB3B3" : "#8EC9A8"
                font.pixelSize: 9
                elide: Text.ElideRight
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: "#33596F7A"
        }

        Row {
            width: parent.width
            height: 40
            spacing: 10

            Text {
                text: "Animation speed scale"
                color: "#D7E8F4"
                font.pixelSize: 12
                width: 150
                anchors.verticalCenter: parent.verticalCenter
            }
            TextField {
                id: speedField
                width: 90
                text: (typeof appModel !== "undefined" && appModel)
                      ? Number(appModel.animationSpeedScale).toFixed(2)
                      : "0.20"
                placeholderText: "0.10 - 10.00"
                anchors.verticalCenter: parent.verticalCenter
                onEditingFinished: settings.commitSpeed()
            }
            Text {
                text: "Default 0.20, lower=faster, higher=slower"
                color: "#8DA7B9"
                font.pixelSize: 10
                width: parent.width - 270
                wrapMode: Text.WordWrap
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            width: parent.width
            height: 34
            spacing: 10

            Text {
                text: "Animations"
                color: "#D7E8F4"
                font.pixelSize: 12
                width: 150
                anchors.verticalCenter: parent.verticalCenter
            }
            Switch {
                id: animationsSwitch
                checked: true
                anchors.verticalCenter: parent.verticalCenter
                onToggled: {
                    if (typeof appModel !== "undefined" && appModel) {
                        appModel.animationsEnabled = checked
                    }
                }
            }
            Text {
                text: "On = animated, Off = instant"
                color: "#8DA7B9"
                font.pixelSize: 10
                width: parent.width - 270
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            width: parent.width
            height: 40
            spacing: 10

            Text {
                text: "Compact list threshold"
                color: "#D7E8F4"
                font.pixelSize: 12
                width: 150
                anchors.verticalCenter: parent.verticalCenter
            }
            TextField {
                id: thresholdField
                width: 90
                text: (typeof appModel !== "undefined" && appModel)
                      ? String(appModel.folderCompactThreshold)
                      : "50"
                placeholderText: "1 - 5000"
                anchors.verticalCenter: parent.verticalCenter
                onEditingFinished: settings.commitThreshold()
            }
            Text {
                text: "If folder items > threshold, use compact list"
                color: "#8DA7B9"
                font.pixelSize: 10
                width: parent.width - 270
                wrapMode: Text.WordWrap
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            width: parent.width
            height: 42
            spacing: 10

            Text {
                text: "Automatic icon refresh"
                color: "#D7E8F4"
                font.pixelSize: 12
                width: 150
                anchors.verticalCenter: parent.verticalCenter
            }
            Switch {
                id: iconRefreshSwitch
                checked: true
                anchors.verticalCenter: parent.verticalCenter
                onToggled: {
                    if (typeof appModel !== "undefined" && appModel) {
                        appModel.automaticIconRefresh = checked
                    }
                }
            }
            Text {
                text: "On = remove missing main items on menu open. Off = skip checks until Manual Refresh."
                color: "#8DA7B9"
                font.pixelSize: 10
                width: parent.width - 270
                wrapMode: Text.WordWrap
                lineHeight: 0.8
                lineHeightMode: Text.ProportionalHeight
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            width: parent.width
            height: 42
            spacing: 10

            Text {
                text: "Automatic folder refresh"
                color: "#D7E8F4"
                font.pixelSize: 12
                width: 150
                anchors.verticalCenter: parent.verticalCenter
            }
            Switch {
                id: folderRefreshSwitch
                checked: true
                anchors.verticalCenter: parent.verticalCenter
                onToggled: {
                    if (typeof appModel !== "undefined" && appModel) {
                        appModel.automaticFolderRefresh = checked
                    }
                }
            }
            Text {
                text: "On = rescan ring folders on menu open. Off = use cached listings until Manual Refresh."
                color: "#8DA7B9"
                font.pixelSize: 10
                width: parent.width - 270
                wrapMode: Text.WordWrap
                lineHeight: 0.8
                lineHeightMode: Text.ProportionalHeight
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            width: parent.width
            height: 42
            spacing: 10

            Text {
                text: "Close after launch"
                color: "#D7E8F4"
                font.pixelSize: 12
                width: 150
                anchors.verticalCenter: parent.verticalCenter
            }
            Switch {
                id: closeAfterLaunchSwitch
                checked: true
                anchors.verticalCenter: parent.verticalCenter
                onToggled: {
                    if (typeof appModel !== "undefined" && appModel) {
                        appModel.closeAfterLaunch = checked
                    }
                }
            }
            Text {
                text: "On = hide the menu after opening a real item. Off = keep it open. Opening folders stays open."
                color: "#8DA7B9"
                font.pixelSize: 10
                width: parent.width - 270
                wrapMode: Text.WordWrap
                lineHeight: 0.8
                lineHeightMode: Text.ProportionalHeight
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            width: parent.width
            height: 42
            spacing: 10

            Text {
                text: "Automatic Item Alignement"
                color: "#D7E8F4"
                font.pixelSize: 12
                width: 150
                anchors.verticalCenter: parent.verticalCenter
            }
            Switch {
                id: automaticAlignmentSwitch
                checked: true
                anchors.verticalCenter: parent.verticalCenter
                onToggled: {
                    if (typeof appModel !== "undefined" && appModel) {
                        appModel.automaticItemAlignment = checked
                    }
                }
            }
            Text {
                text: "On = spread items evenly around the ring. Off = keep them on the circle but let you bunch them on one side."
                color: "#8DA7B9"
                font.pixelSize: 10
                width: parent.width - 270
                wrapMode: Text.WordWrap
                lineHeight: 0.8
                lineHeightMode: Text.ProportionalHeight
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: "#33596F7A"
        }

        Row {
            width: parent.width
            height: 42
            spacing: 8

            ActionButton {
                text: "Manual Refresh"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    if (typeof appModel !== "undefined" && appModel && appModel.manualRefreshEnabled) {
                        appModel.manualRefreshEnabled()
                    }
                }
            }
            Text {
                text: "Runs only the refresh types whose automatic toggle is off. If both are on, this does nothing."
                color: "#8DA7B9"
                font.pixelSize: 10
                width: parent.width - 180
                wrapMode: Text.WordWrap
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            width: parent.width
            height: 30
            spacing: 8

            ActionButton {
                text: "Clear All Items"
                onClicked: {
                    settings.confirmClear = true
                    settings.confirmReset = false
                }
            }
            Text {
                text: "Removes every ring entry."
                color: "#8DA7B9"
                font.pixelSize: 10
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            width: parent.width
            height: 30
            spacing: 8
            visible: settings.confirmClear

            Text {
                text: "Are you sure? This cannot be undone."
                color: "#FFB3B3"
                font.pixelSize: 10
                anchors.verticalCenter: parent.verticalCenter
            }
            ActionButton {
                text: "Yes, clear"
                onClicked: {
                    settings.clearAllConfirmed()
                    settings.confirmClear = false
                }
            }
            ActionButton {
                text: "Cancel"
                onClicked: settings.confirmClear = false
            }
        }

        Row {
            width: parent.width
            height: 30
            spacing: 8

            ActionButton {
                text: "Reset Settings To Default"
                onClicked: {
                    settings.confirmReset = true
                    settings.confirmClear = false
                }
            }
            Text {
                text: "Restores speed/toggles/threshold defaults."
                color: "#8DA7B9"
                font.pixelSize: 10
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            width: parent.width
            height: 30
            spacing: 8
            visible: settings.confirmReset

            Text {
                text: "Reset all quick settings?"
                color: "#FFDAA1"
                font.pixelSize: 10
                anchors.verticalCenter: parent.verticalCenter
            }
            ActionButton {
                text: "Yes, reset"
                onClicked: {
                    settings.resetDefaultsConfirmed()
                    settings.confirmReset = false
                    speedField.text = "0.20"
                    thresholdField.text = "50"
                }
            }
            ActionButton {
                text: "Cancel"
                onClicked: settings.confirmReset = false
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: "#33596F7A"
        }

        Text {
            text: "App Control"
            color: "#C6DCE8"
            font.pixelSize: 12
            font.bold: true
        }

        Text {
            text: (typeof appModel !== "undefined" && appModel)
                  ? ("Version: " + appModel.appVersion)
                  : "Version: 0.0.0"
            color: "#8DA7B9"
            font.pixelSize: 10
        }

        Row {
            width: parent.width
            height: 36
            spacing: 10

            Text {
                text: "Launch on startup"
                color: "#D7E8F4"
                font.pixelSize: 12
                width: 150
                anchors.verticalCenter: parent.verticalCenter
            }

            Switch {
                id: startupOnBootSwitch
                checked: false
                anchors.verticalCenter: parent.verticalCenter
                onToggled: {
                    if (typeof backend !== "undefined" && backend) {
                        backend.launchOnStartupEnabled = checked
                    }
                }
            }

            Text {
                text: "On = create a Windows startup shortcut. Off = remove it."
                color: "#8DA7B9"
                font.pixelSize: 10
                width: parent.width - 270
                wrapMode: Text.WordWrap
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            width: parent.width
            height: 34
            spacing: 8

            ActionButton {
                text: "Restart App"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    if (typeof backend !== "undefined" && backend && backend.restartApp) {
                        backend.restartApp()
                    }
                }
            }

            ActionButton {
                text: "Quit App"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    if (typeof backend !== "undefined" && backend && backend.quitApp) {
                        backend.quitApp()
                    }
                }
            }

            Text {
                text: "Restart relaunches the app immediately. Quit fully closes it."
                color: "#8DA7B9"
                font.pixelSize: 10
                width: parent.width - 210
                wrapMode: Text.WordWrap
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: "#33596F7A"
        }

        Text {
            text: "Backup"
            color: "#C6DCE8"
            font.pixelSize: 12
            font.bold: true
        }

        Row {
            width: parent.width
            height: 34
            spacing: 8

            ActionButton {
                text: "Export Settings Only"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    if (typeof backend !== "undefined" && backend && backend.exportSettingsOnly) {
                        backend.exportSettingsOnly()
                    }
                }
            }

            Text {
                text: "Exports only the current settings panel state."
                color: "#8DA7B9"
                font.pixelSize: 10
                width: parent.width - 210
                wrapMode: Text.WordWrap
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            width: parent.width
            height: 34
            spacing: 8

            ActionButton {
                text: "Export Settings And Dock"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    if (typeof backend !== "undefined" && backend && backend.exportSettingsAndDock) {
                        backend.exportSettingsAndDock()
                    }
                }
            }

            Text {
                text: "Exports the current settings plus your pinned dock items in one file."
                color: "#8DA7B9"
                font.pixelSize: 10
                width: parent.width - 210
                wrapMode: Text.WordWrap
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            width: parent.width
            height: 34
            spacing: 8

            ActionButton {
                text: "Import Settings"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    if (typeof backend !== "undefined" && backend && backend.importSettings) {
                        backend.importSettings()
                    }
                }
            }

            Text {
                text: "Imports a backup file. Settings-only backups keep your current dock items."
                color: "#8DA7B9"
                font.pixelSize: 10
                width: parent.width - 210
                wrapMode: Text.WordWrap
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Item {
            width: parent.width
            height: transferStatus.length > 0 ? 16 : 0
            visible: transferStatus.length > 0

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: transferStatus
                color: transferError ? "#FFB3B3" : "#8EC9A8"
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }
        }
    }

    MouseArea {
        visible: settings.capturingHotkey && settings.hotkeyCaptureReady
        anchors.fill: parent
        z: 3000
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton
        hoverEnabled: true
        onPressed: function(mouse) {
            var shortcut = settings.shortcutFromMouseButton(mouse.button)
            if (!shortcut) {
                return
            }
            settings.finishHotkeyCapture(shortcut)
            mouse.accepted = true
        }
    }
}
