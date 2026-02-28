import QtQuick
import QtQuick.Controls

Item {
    id: ring
    signal folderBackRequested()
    signal settingsBackRequested()
    property real openProgress: 1.0
    property bool isOpen: true
    property bool settingsOpen: false
    property bool folderOpen: false
    property string folderTitle: ""
    property var folderEntries: []
    property int radialItemMoveBaseDuration: 500
    property real animationSpeedScale: 0.2
    property bool animationsEnabled: true
    property bool mainRevealActive: false
    property int folderListFallbackThreshold: (typeof appModel !== "undefined" && appModel)
                                            ? appModel.folderCompactThreshold
                                            : 50
    property int draggedIndex: -1
    property int hoverIndex: -1
    property int removingIndex: -1
    property int removeIndexPending: -1
    property real dragDistance: 0.0
    property bool loadedFromSettings: false
    property bool skipNextModelSync: false

    readonly property real centerX: width / 2
    readonly property real centerY: height / 2
    readonly property real orbitRadius: Math.min(width, height) * 0.37
    readonly property real centerIgnoreRadius: Math.min(width, height) * 0.24
    readonly property real removeThreshold: Math.min(width, height) * 0.49
    readonly property bool removeCandidate: draggedIndex >= 0 && dragDistance > removeThreshold
    readonly property bool subViewOpen: folderOpen || settingsOpen
    readonly property bool compactListMode: folderOpen && folderEntries.length > folderListFallbackThreshold
    readonly property int folderGridColumns: compactListMode ? 1 : estimatedGridColumns(folderEntries.length)
    readonly property int folderGridRows: compactListMode ? folderEntries.length : Math.ceil(folderEntries.length / Math.max(folderGridColumns, 1))
    readonly property int folderPanelWidth: compactListMode
                                          ? 520
                                          : Math.max(300, folderGridColumns * 104 + 30)
    readonly property int folderPanelHeight: compactListMode
                                           ? 460
                                           : Math.max(180, folderGridRows * 104 + 58)
    readonly property int settingsPanelWidth: 420
    readonly property int settingsPanelHeight: 550
    readonly property int preferredStageWidth: settingsOpen
                                           ? Math.max(390, settingsPanelWidth + 56)
                                           : (folderOpen ? Math.max(390, folderPanelWidth + 56) : 390)
    readonly property int preferredStageHeight: settingsOpen
                                            ? Math.max(390, settingsPanelHeight + 56)
                                            : (folderOpen ? Math.max(390, folderPanelHeight + 56) : 390)

    function animDuration(baseDuration) {
        if (!animationsEnabled) {
            return 0
        }
        return Math.max(1, Math.round(baseDuration * animationSpeedScale))
    }

    ListModel {
        id: ringItems
    }

    readonly property var colorPalette: [
        "#FF7B6C",
        "#8D9BFF",
        "#63D5C2",
        "#F9B26E",
        "#62B9FF",
        "#DD8DFF",
        "#83E37B",
        "#F0DF87",
        "#FF9BC7",
        "#7EE3FF"
    ]

    function angleForSlot(slotIndex, total) {
        var count = Math.max(total, 1)
        return (slotIndex / count) * Math.PI * 2
    }

    function clampInt(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(maxValue, value))
    }

    function estimatedGridColumns(itemCount) {
        if (itemCount <= 1) {
            return 1
        }
        var guess = Math.ceil(Math.sqrt(itemCount))
        return clampInt(guess, 2, 8)
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
        if (distance <= centerIgnoreRadius) {
            return false
        }
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
        var pointerDistance = Math.sqrt((dx * dx) + (dy * dy))
        dragDistance = pointerDistance

        if (pointerDistance <= centerIgnoreRadius) {
            // Ignore center region while rearranging to avoid accidental remove/jitter.
            hoverIndex = draggedIndex
            return
        }

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
            schedulePersist()
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

    function closeFolderView() {
        if (!folderOpen) {
            return
        }
        folderBackRequested()
    }

    function closeSettingsView() {
        if (!settingsOpen) {
            return
        }
        settingsBackRequested()
    }

    function toggleSettingsView() {
        if (settingsOpen) {
            closeSettingsView()
            return
        }
        settingsOpen = true
    }

    function applyFolderClosed() {
        folderOpen = false
        folderTitle = ""
        folderEntries = []
    }

    function applySettingsClosed() {
        settingsOpen = false
    }

    function activateItem(itemIndex) {
        if (itemIndex < 0 || itemIndex >= ringItems.count) {
            return
        }
        var entry = ringItems.get(itemIndex)
        if (!entry.path) {
            return
        }
        if (entry.kind === "folder") {
            if (typeof appModel === "undefined" || !appModel || !appModel.listFolderEntries) {
                return
            }
            settingsOpen = false
            folderEntries = appModel.listFolderEntries(entry.path, appModel.automaticFolderRefresh)
            folderTitle = entry.label || entry.path
            folderOpen = true
            return
        }
        if (typeof appModel !== "undefined" && appModel && appModel.openPath) {
            appModel.openPath(entry.path)
        }
    }

    function openFolderEntry(path, kind) {
        if (!path) {
            return
        }
        if (typeof appModel !== "undefined" && appModel && appModel.openPath) {
            appModel.openPath(path)
        }
    }

    function localPathFromUrl(urlValue) {
        var urlText = String(urlValue)
        if (urlText.indexOf("file:///") !== 0) {
            return ""
        }
        var localPath = decodeURIComponent(urlText.substring(8))
        return localPath.replace(/\//g, "\\")
    }

    function fileLabelFromPath(localPath) {
        var normalized = localPath.replace(/\\/g, "/")
        var parts = normalized.split("/")
        if (parts.length === 0) {
            return localPath
        }
        return parts[parts.length - 1] || localPath
    }

    function kindFromPath(localPath) {
        if (typeof appModel !== "undefined" && appModel && appModel.pathKind) {
            return appModel.pathKind(localPath)
        }
        var lowerPath = localPath.toLowerCase()
        if (lowerPath.endsWith(".lnk")) {
            return "shortcut"
        }
        var slashNormalized = localPath.replace(/\\/g, "/")
        var leaf = slashNormalized.split("/").pop()
        if (leaf && leaf.indexOf(".") >= 0) {
            return "file"
        }
        return "folder"
    }

    function colorForPath(localPath) {
        var hash = 0
        for (var i = 0; i < localPath.length; i++) {
            hash = ((hash << 5) - hash) + localPath.charCodeAt(i)
            hash |= 0
        }
        var index = Math.abs(hash) % colorPalette.length
        return colorPalette[index]
    }

    function hasPath(localPath) {
        for (var i = 0; i < ringItems.count; i++) {
            var entry = ringItems.get(i)
            if (entry.path === localPath) {
                return true
            }
        }
        return false
    }

    function addDroppedUrls(urls) {
        if (!urls || urls.length === 0) {
            return
        }
        var appendedCount = 0
        for (var i = 0; i < urls.length; i++) {
            var localPath = localPathFromUrl(urls[i])
            if (!localPath || hasPath(localPath)) {
                continue
            }
            var label = fileLabelFromPath(localPath)
            ringItems.append({
                "label": label,
                "color": colorForPath(localPath),
                "path": localPath,
                "kind": kindFromPath(localPath)
            })
            appendedCount += 1
        }
        if (appendedCount > 0) {
            schedulePersist()
        }
    }

    function serializeItems() {
        var serialized = []
        for (var i = 0; i < ringItems.count; i++) {
            var entry = ringItems.get(i)
            serialized.push({
                "label": entry.label || "Item",
                "color": entry.color || colorPalette[i % colorPalette.length],
                "path": entry.path || "",
                "kind": entry.kind || "file"
            })
        }
        return serialized
    }

    function schedulePersist() {
        if (!loadedFromSettings) {
            return
        }
        if (typeof appModel === "undefined" || !appModel || !appModel.saveRingItems) {
            return
        }
        persistTimer.restart()
    }

    function loadFromSettings() {
        ringItems.clear()

        if (typeof appModel !== "undefined" && appModel && appModel.ringItems && appModel.ringItems.length > 0) {
            for (var i = 0; i < appModel.ringItems.length; i++) {
                var item = appModel.ringItems[i]
                ringItems.append({
                    "label": item.label || "Item",
                    "color": item.color || colorPalette[i % colorPalette.length],
                    "path": item.path || "",
                    "kind": item.kind || "file"
                })
            }
        }

        loadedFromSettings = true
    }

    Component.onCompleted: {
        loadFromSettings()
    }

    Connections {
        target: appModel
        function onRingItemsChanged() {
            if (ring.skipNextModelSync) {
                ring.skipNextModelSync = false
                return
            }
            ring.loadFromSettings()
        }
    }

    Timer {
        id: persistTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (typeof appModel !== "undefined" && appModel && appModel.saveRingItems) {
                ring.skipNextModelSync = true
                appModel.saveRingItems(serializeItems())
            }
        }
    }

    Timer {
        id: removeTimer
        interval: 130
        repeat: false
        onTriggered: {
            if (ring.removeIndexPending >= 0 && ring.removeIndexPending < ringItems.count) {
                ringItems.remove(ring.removeIndexPending, 1)
                ring.schedulePersist()
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
            NumberAnimation { duration: ring.animDuration(120); easing.type: Easing.OutCubic }
        }
        Behavior on border.color {
            ColorAnimation { duration: ring.animDuration(120) }
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
            required property string path
            required property string kind
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
            property real movedDistance: 0.0

            width: 60
            height: 60
            x: dragging ? dragCenterX - width / 2 : targetPos.x - width / 2
            y: dragging ? dragCenterY - height / 2 : targetPos.y - height / 2
            z: dragging ? 200 : 100 - index
            opacity: ring.removingIndex === index ? 0.0 : revealValue * (ring.subViewOpen ? 0.18 : 1.0)
            scale: ring.removingIndex === index
                   ? 0.55
                   : (dragging ? 1.12 : (0.65 + (0.35 * revealValue)))

            Behavior on x {
                enabled: !dragging && !ring.mainRevealActive
                NumberAnimation { duration: ring.animDuration(ring.radialItemMoveBaseDuration); easing.type: Easing.OutCubic }
            }
            Behavior on y {
                enabled: !dragging && !ring.mainRevealActive
                NumberAnimation { duration: ring.animDuration(ring.radialItemMoveBaseDuration); easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: ring.animDuration(150); easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: ring.animDuration(170); easing.type: Easing.OutBack }
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.rgba(0.13, 0.18, 0.25, 0.9)
                border.color: color
                border.width: ring.hoverIndex === index && ring.draggedIndex >= 0 ? 2 : 1

                Behavior on border.color {
                    ColorAnimation { duration: ring.animDuration(110) }
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 2

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 26
                        height: 26
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        source: (typeof appModel !== "undefined" && appModel && appModel.iconDataUrl)
                                ? appModel.iconDataUrl(path || "", kind || "file", label || "Item")
                                : ""
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        text: label
                        color: "#E8F8FF"
                        font.pixelSize: 9
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                enabled: ring.removingIndex < 0 && !ring.subViewOpen
                hoverEnabled: true
                preventStealing: true
                acceptedButtons: Qt.LeftButton
                cursorShape: dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                onPressed: function(mouse) {
                    var p = dragArea.mapToItem(ring, mouse.x, mouse.y)
                    // Re-anchor drag origin to the current visual slot every time.
                    // Without this, prior drags can leave stale anchor values and cause icon "pop".
                    dragCenterX = targetPos.x
                    dragCenterY = targetPos.y
                    dragging = true
                    pointerOffsetX = p.x - dragCenterX
                    pointerOffsetY = p.y - dragCenterY
                    movedDistance = 0.0
                    ring.startDrag(index)
                    ring.updateDrag(index, p.x, p.y)
                    mouse.accepted = true
                }

                onPositionChanged: function(mouse) {
                    if (!dragging) {
                        return
                    }
                    var p = dragArea.mapToItem(ring, mouse.x, mouse.y)
                    dragCenterX = p.x - pointerOffsetX
                    dragCenterY = p.y - pointerOffsetY
                    var dx = dragCenterX - targetPos.x
                    var dy = dragCenterY - targetPos.y
                    movedDistance = Math.sqrt((dx * dx) + (dy * dy))
                    ring.updateDrag(index, p.x, p.y)
                }

                onReleased: function(mouse) {
                    if (!dragging) {
                        return
                    }
                    var p = dragArea.mapToItem(ring, mouse.x, mouse.y)
                    var wasClick = movedDistance < 8
                    dragging = false
                    ring.finishDrag(index, p.x, p.y)
                    dragCenterX = targetPos.x
                    dragCenterY = targetPos.y
                    if (wasClick) {
                        ring.activateItem(index)
                    }
                }

                onCanceled: {
                    if (!dragging) {
                        return
                    }
                    dragging = false
                    dragCenterX = targetPos.x
                    dragCenterY = targetPos.y
                    ring.resetDragState()
                }
            }
        }
    }

    Rectangle {
        id: coreButton
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
            NumberAnimation { duration: ring.animDuration(180); easing.type: Easing.OutBack }
        }
        Behavior on opacity {
            NumberAnimation { duration: ring.animDuration(160); easing.type: Easing.OutCubic }
        }

        Text {
            anchors.centerIn: parent
            text: ring.removeCandidate
                  ? "Release to\nRemove"
                  : (ring.settingsOpen ? "Settings" : (ring.folderOpen ? "Folder View" : "Radial Dock"))
            color: "#E8F8FF"
            font.pixelSize: ring.removeCandidate ? 14 : 16
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            text: "Click for settings"
            color: "#98B5C6"
            font.pixelSize: 9
            opacity: centerHover.hovered && !ring.folderOpen ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: ring.animDuration(80); easing.type: Easing.OutCubic }
            }
        }

        HoverHandler {
            id: centerHover
        }

        MouseArea {
            anchors.fill: parent
            enabled: !ring.folderOpen && ring.draggedIndex < 0
            acceptedButtons: Qt.LeftButton
            onClicked: ring.toggleSettingsView()
        }
    }

    FolderView {
        width: Math.min(ring.folderPanelWidth, ring.width - 20)
        height: Math.min(ring.folderPanelHeight, ring.height - 20)
        anchors.centerIn: parent
        visible: ring.folderOpen
        opacity: ring.folderOpen ? 1.0 : 0.0
        z: 300
        title: ring.folderTitle
        entries: ring.folderEntries
        compactMode: ring.compactListMode
        onTileActivated: function(path, kind) {
            ring.openFolderEntry(path, kind)
        }

        Behavior on opacity {
            NumberAnimation { duration: ring.animDuration(130); easing.type: Easing.OutCubic }
        }
    }

    Settings {
        width: Math.min(ring.settingsPanelWidth, ring.width - 28)
        height: Math.min(ring.settingsPanelHeight, ring.height - 28)
        anchors.centerIn: parent
        visible: ring.settingsOpen
        opacity: ring.settingsOpen ? 1.0 : 0.0
        z: 320
        onClearAllConfirmed: {
            if (typeof appModel !== "undefined" && appModel && appModel.clearRingItems) {
                appModel.clearRingItems()
            }
        }
        onResetDefaultsConfirmed: {
            if (typeof appModel !== "undefined" && appModel && appModel.resetQuickSettings) {
                appModel.resetQuickSettings()
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: ring.animDuration(130); easing.type: Easing.OutCubic }
        }
    }
}
