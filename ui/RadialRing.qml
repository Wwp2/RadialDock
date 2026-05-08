import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

Item {
    id: ring
    signal folderBackRequested()
    signal settingsBackRequested()
    signal folderSceneOpened()
    signal folderSceneClosed()
    property real openProgress: 1.0
    property bool isOpen: true
    property bool groupEditMode: false
    property bool groupOpen: false
    property string groupTitle: ""
    property var groupEntries: []
    property int openGroupIndex: -1
    property real groupAnchorX: centerX
    property real groupAnchorY: centerY
    property bool groupNamingVisible: false
    property string groupNameDraft: ""
    property int renameTargetIndex: -1
    property bool folderReturnToGroup: false
    property string folderReturnGroupTitle: ""
    property var folderReturnGroupEntries: []
    property int folderReturnGroupIndex: -1
    property real folderReturnGroupAnchorX: centerX
    property real folderReturnGroupAnchorY: centerY
    property bool settingsOpen: false
    property bool folderOpen: false
    property bool folderLoading: false
    property string folderRefreshStatus: ""
    property string currentFolderPath: ""
    property string folderTitle: ""
    property var folderEntries: []
    property bool recentRadialOpen: false
    property string recentFolderPath: ""
    property int radialItemMoveBaseDuration: 500
    property real animationSpeedScale: 0.2
    property bool animationsEnabled: true
    property bool mainRevealActive: false
    property int folderListFallbackThreshold: (typeof appModel !== "undefined" && appModel)
                                            ? appModel.folderCompactThreshold
                                            : 50
    property int draggedIndex: -1
    property int hoverIndex: -1
    property int mergeTargetIndex: -1
    property int removingIndex: -1
    property int removeIndexPending: -1
    property real dragDistance: 0.0
    property bool loadedFromSettings: false
    property bool skipNextModelSync: false
    property bool automaticItemAlignment: true

    readonly property real centerX: width / 2
    readonly property real centerY: height / 2
    readonly property real orbitRadius: Math.min(width, height) * 0.37
    readonly property real ringItemDiameter: 60
    readonly property real ringItemRadius: ringItemDiameter / 2
    readonly property int coreButtonDiameter: 124
    readonly property real decorativeOuterRingDiameter: (orbitRadius + ringItemRadius) * 2
    readonly property real decorativeInnerRingDiameter: Math.max(0, (orbitRadius - ringItemRadius) * 2)
    readonly property real centerIgnoreRadius: Math.min(width, height) * 0.24
    readonly property real removeThreshold: Math.min(width, height) * 0.49
    readonly property bool removeCandidate: !groupEditMode && draggedIndex >= 0 && dragDistance > removeThreshold
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
    readonly property int settingsPanelHeight: Math.max(390, Math.ceil(settingsPanel.implicitHeight))
    readonly property int settingsStagePadding: 64
    readonly property int groupPanelSize: Math.max(180, Math.min(280, 132 + (Math.max(groupEntries.length, 1) * 18)))
    readonly property real groupOrbitRadius: Math.max(44, Math.min(92, groupPanelSize * 0.28))
    readonly property int preferredStageWidth: settingsOpen
                                           ? Math.max(390, settingsPanelWidth + settingsStagePadding)
                                           : 390
    readonly property int preferredStageHeight: settingsOpen
                                            ? Math.max(390, settingsPanelHeight + settingsStagePadding)
                                            : 390

    function animDuration(baseDuration) {
        if (!animationsEnabled) {
            return 0
        }
        return Math.max(1, Math.round(baseDuration * animationSpeedScale))
    }

    function folderPathsEqual(a, b) {
        if (!a || !b) {
            return false
        }
        if (a === b) {
            return true
        }
        if (Qt.platform.os === "windows") {
            return String(a).toLowerCase() === String(b).toLowerCase()
        }
        return false
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

    function angleForSlot(slotIndex, total) {
        var count = Math.max(total, 1)
        return (slotIndex / count) * Math.PI * 2
    }

    function normalizedAngle(angle) {
        var next = angle
        while (next < 0) {
            next += Math.PI * 2
        }
        while (next >= Math.PI * 2) {
            next -= Math.PI * 2
        }
        return next
    }

    function angleForPoint(px, py) {
        return normalizedAngle(Math.atan2(py - centerY, px - centerX) + Math.PI / 2)
    }

    function captureCurrentAlignedAngles() {
        for (var i = 0; i < ringItems.count; i++) {
            ringItems.setProperty(i, "angle", angleForSlot(i, Math.max(ringItems.count, 1)))
        }
        schedulePersist()
    }

    function pathLooksLikeImage(localPath, kind) {
        if ((kind || "").toLowerCase() !== "file" || !localPath) {
            return false
        }
        var normalized = String(localPath).toLowerCase()
        for (var i = 0; i < imageExtensions.length; i++) {
            if (normalized.endsWith(imageExtensions[i])) {
                return true
            }
        }
        return false
    }

    function displayLabel(label, path, kind) {
        if (typeof appModel !== "undefined" && appModel && appModel.displayLabel) {
            var _ = appModel.showFileExtensions
            return appModel.displayLabel(label || "", path || "", kind || "file")
        }
        return label || "Item"
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

    function itemAngle(entry, itemIndex) {
        if (automaticItemAlignment) {
            return angleForSlot(itemIndex, Math.max(ringItems.count, 1))
        }
        if (!entry) {
            return angleForSlot(itemIndex, Math.max(ringItems.count, 1))
        }
        return normalizedAngle(Number(entry.angle || 0))
    }

    function slotPosition(slotIndex) {
        var entry = ringItems.get(slotIndex)
        var angle = itemAngle(entry, slotIndex) - Math.PI / 2
        return {
            x: centerX + Math.cos(angle) * orbitRadius,
            y: centerY + Math.sin(angle) * orbitRadius
        }
    }

    function slotForIndex(itemIndex) {
        if (!automaticItemAlignment) {
            return itemIndex
        }
        if (groupEditMode) {
            return itemIndex
        }
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
        if (!automaticItemAlignment) {
            return ringItems.count
        }
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

    function parseChildrenJson(rawValue) {
        if (!rawValue) {
            return []
        }
        try {
            var parsed = JSON.parse(String(rawValue))
            return Array.isArray(parsed) ? parsed : []
        } catch (error) {
            return []
        }
    }

    function cloneEntry(entry) {
        if (!entry) {
            return {
                "label": "Item",
                "color": colorPalette[0],
                "path": "",
                "kind": "file",
                "children": []
            }
        }
        var children = []
        if (Array.isArray(entry.children)) {
            for (var i = 0; i < entry.children.length; i++) {
                children.push(cloneEntry(entry.children[i]))
            }
        }
        return {
            "label": entry.label || "Item",
            "color": entry.color || colorPalette[0],
            "path": entry.path || "",
            "kind": entry.kind || "file",
            "angle": Number(entry.angle || 0),
            "children": children
        }
    }

    function modelEntryAt(itemIndex) {
        if (itemIndex < 0 || itemIndex >= ringItems.count) {
            return null
        }
        var entry = ringItems.get(itemIndex)
        return {
            "label": entry.label || "Item",
            "color": entry.color || colorPalette[itemIndex % colorPalette.length],
            "path": entry.path || "",
            "kind": entry.kind || "file",
            "angle": Number(entry.angle || 0),
            "children": parseChildrenJson(entry.childrenJson)
        }
    }

    function flattenGroupChildren(entry) {
        if (!entry) {
            return []
        }
        if (entry.kind === "group") {
            return Array.isArray(entry.children) ? entry.children : []
        }
        return [cloneEntry(entry)]
    }

    function findMergeTarget(itemIndex, px, py) {
        var bestIndex = -1
        var bestDistance = 999999
        for (var i = 0; i < ringItems.count; i++) {
            if (i === itemIndex) {
                continue
            }
            var pos = slotPosition(i)
            var dx = px - pos.x
            var dy = py - pos.y
            var distance = Math.sqrt((dx * dx) + (dy * dy))
            if (distance < 42 && distance < bestDistance) {
                bestDistance = distance
                bestIndex = i
            }
        }
        return bestIndex
    }

    function groupSlotPosition(slotIndex, total) {
        var count = Math.max(total, 1)
        var angle = angleForSlot(slotIndex, count) - Math.PI / 2
        var localCenter = groupPanelSize / 2
        return {
            x: localCenter + Math.cos(angle) * groupOrbitRadius,
            y: localCenter + Math.sin(angle) * groupOrbitRadius
        }
    }

    function isPointInsideOpenGroup(px, py) {
        if (!groupOpen) {
            return false
        }
        var dx = px - groupAnchorX
        var dy = py - groupAnchorY
        var distance = Math.sqrt((dx * dx) + (dy * dy))
        return distance <= (groupPanelSize * 0.5) + 10
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
        mergeTargetIndex = -1
        dragDistance = 0.0
        removingIndex = -1
    }

    function updateDrag(itemIndex, px, py) {
        if (draggedIndex !== itemIndex) {
            return
        }
        if (groupEditMode) {
            dragDistance = 0.0
            hoverIndex = itemIndex
            mergeTargetIndex = findMergeTarget(itemIndex, px, py)
            return
        }
        var dx = px - centerX
        var dy = py - centerY
        var pointerDistance = Math.sqrt((dx * dx) + (dy * dy))
        dragDistance = pointerDistance

        if (!automaticItemAlignment) {
            hoverIndex = itemIndex
            return
        }

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

        if (groupEditMode) {
            if (mergeTargetIndex >= 0 && mergeTargetIndex !== itemIndex) {
                mergeItems(itemIndex, mergeTargetIndex)
            }
            resetDragState()
            return
        }

        if (!automaticItemAlignment) {
            if (!isRemoveCandidateAt(px, py)) {
                ringItems.setProperty(itemIndex, "angle", angleForPoint(px, py))
                schedulePersist()
            } else {
                removingIndex = itemIndex
                removeIndexPending = itemIndex
                hoverIndex = -1
                removeTimer.restart()
                return
            }
            resetDragState()
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
        mergeTargetIndex = -1
        dragDistance = 0.0
        removingIndex = -1
        removeIndexPending = -1
    }

    function openFolderPath(folderPath, titleText, fromGroup) {
        if (!folderPath || typeof appModel === "undefined" || !appModel) {
            return
        }
        settingsOpen = false
        if (fromGroup) {
            folderReturnToGroup = true
            folderReturnGroupTitle = groupTitle
            folderReturnGroupEntries = groupEntries
            folderReturnGroupIndex = openGroupIndex
            folderReturnGroupAnchorX = groupAnchorX
            folderReturnGroupAnchorY = groupAnchorY
            groupOpen = false
        } else {
            folderReturnToGroup = false
            folderReturnGroupTitle = ""
            folderReturnGroupEntries = []
            folderReturnGroupIndex = -1
        }
        currentFolderPath = folderPath
        folderTitle = titleText || folderPath
        folderEntries = appModel.cachedFolderEntries ? appModel.cachedFolderEntries(folderPath) : []
        folderOpen = true
        folderSceneOpened()
        if (!appModel.automaticFolderRefresh) {
            folderRefreshStatus = "disabled"
            folderLoading = false
            return
        }

        var refreshState = appModel.folderRefreshState
                         ? appModel.folderRefreshState(folderPath)
                         : "pending"
        if (!refreshState || refreshState === "pending") {
            folderRefreshStatus = "checking"
            folderLoading = true
            if (appModel.requestFolderEntries) {
                appModel.requestFolderEntries(folderPath, true)
            }
            return
        }

        if (refreshState === "checking") {
            folderRefreshStatus = "checking"
            folderLoading = true
            return
        }

        folderRefreshStatus = "checked"
        folderLoading = false
    }

    function closeFolderView() {
        if (!folderOpen) {
            return
        }
        if (folderReturnToGroup) {
            var returnTitle = folderReturnGroupTitle
            var returnEntries = folderReturnGroupEntries
            var returnGroupIndex = folderReturnGroupIndex
            var returnAnchorX = folderReturnGroupAnchorX
            var returnAnchorY = folderReturnGroupAnchorY
            applyFolderClosed()
            groupTitle = returnTitle
            groupEntries = returnEntries
            openGroupIndex = returnGroupIndex
            groupAnchorX = returnAnchorX
            groupAnchorY = returnAnchorY
            groupOpen = true
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
        if (groupEditMode) {
            groupEditMode = false
            return
        }
        if (settingsOpen) {
            closeSettingsView()
            return
        }
        groupOpen = false
        recentRadialOpen = false
        recentFolderPath = ""
        settingsOpen = true
    }

    function closeGroupView() {
        if (!groupOpen) {
            return
        }
        groupOpen = false
        groupTitle = ""
        groupEntries = []
        openGroupIndex = -1
        recentRadialOpen = false
        recentFolderPath = ""
    }

    function toggleGroupEditMode() {
        groupEditMode = !groupEditMode
        if (groupEditMode) {
            settingsOpen = false
            closeGroupView()
        }
        groupNamingVisible = false
        renameTargetIndex = -1
    }

    function promptGroupName(targetIndex, suggestedName) {
        renameTargetIndex = targetIndex
        groupNameDraft = suggestedName || "New Group"
        groupNamingVisible = true
        groupNameField.forceActiveFocus()
        groupNameField.selectAll()
    }

    function commitGroupName() {
        if (!groupNamingVisible || renameTargetIndex < 0 || renameTargetIndex >= ringItems.count) {
            groupNamingVisible = false
            return
        }
        var trimmed = String(groupNameDraft || "").trim()
        if (!trimmed) {
            trimmed = "New Group"
        }
        ringItems.setProperty(renameTargetIndex, "label", trimmed)
        groupNamingVisible = false
        renameTargetIndex = -1
        schedulePersist()
    }

    function cancelGroupNaming() {
        groupNamingVisible = false
        renameTargetIndex = -1
    }

    function openGroupAtIndex(itemIndex) {
        var entry = modelEntryAt(itemIndex)
        if (!entry || entry.kind !== "group") {
            return
        }
        recentRadialOpen = false
        recentFolderPath = ""
        var pos = slotPosition(itemIndex)
        groupAnchorX = pos.x
        groupAnchorY = pos.y
        groupTitle = entry.label || "Group"
        groupEntries = entry.children || []
        openGroupIndex = itemIndex
        groupOpen = true
    }

    function openRecentRadialAtIndex(itemIndex) {
        var entry = modelEntryAt(itemIndex)
        if (!entry || entry.kind !== "folder" || !entry.path) {
            return
        }
        if (typeof appModel === "undefined" || !appModel || !appModel.isShellRecentFolderPath) {
            return
        }
        if (!appModel.isShellRecentFolderPath(entry.path)) {
            return
        }
        var folderPath = entry.path
        settingsOpen = false
        var pos = slotPosition(itemIndex)
        groupAnchorX = pos.x
        groupAnchorY = pos.y
        groupTitle = entry.label || "Recent"
        groupEntries = appModel.listFolderEntries
                     ? appModel.listFolderEntries(folderPath, true)
                     : (appModel.cachedFolderEntries ? appModel.cachedFolderEntries(folderPath) : [])
        openGroupIndex = itemIndex
        recentRadialOpen = true
        recentFolderPath = folderPath
        groupOpen = true
        if (!appModel.listFolderEntries && appModel.requestFolderEntries) {
            appModel.requestFolderEntries(folderPath, true)
        }
    }

    function moveGroupEntryToMain(groupIndex, px, py) {
        if (recentRadialOpen) {
            return
        }
        if (groupIndex < 0 || groupIndex >= groupEntries.length) {
            return
        }
        if (openGroupIndex < 0 || openGroupIndex >= ringItems.count) {
            return
        }

        var movedEntry = cloneEntry(groupEntries[groupIndex])
        var insertAt = Math.max(0, Math.min(nearestSlotForPoint(px, py), ringItems.count))
        var nextEntries = []
        for (var i = 0; i < groupEntries.length; i++) {
            if (i === groupIndex) {
                continue
            }
            nextEntries.push(cloneEntry(groupEntries[i]))
        }
        groupEntries = nextEntries

        if (nextEntries.length <= 0) {
            var removedIndex = openGroupIndex
            ringItems.remove(removedIndex, 1)
            closeGroupView()
            if (insertAt > removedIndex) {
                insertAt -= 1
            }
        } else if (nextEntries.length === 1) {
            var onlyEntry = cloneEntry(nextEntries[0])
            ringItems.set(openGroupIndex, {
                "label": onlyEntry.label || "Item",
                "color": onlyEntry.color || colorPalette[openGroupIndex % colorPalette.length],
                "path": onlyEntry.path || "",
                "kind": onlyEntry.kind || "file",
                "angle": Number(onlyEntry.angle || ringItems.get(openGroupIndex).angle || 0),
                "childrenJson": JSON.stringify(onlyEntry.children || [])
            })
            closeGroupView()
        } else {
            ringItems.set(openGroupIndex, {
                "label": groupTitle || "Group",
                "color": ringItems.get(openGroupIndex).color || colorPalette[openGroupIndex % colorPalette.length],
                "path": "",
                "kind": "group",
                "angle": Number(ringItems.get(openGroupIndex).angle || 0),
                "childrenJson": JSON.stringify(nextEntries)
            })
        }

        insertAt = Math.max(0, Math.min(insertAt, ringItems.count))
        ringItems.insert(insertAt, {
            "label": movedEntry.label || "Item",
            "color": movedEntry.color || colorPalette[insertAt % colorPalette.length],
            "path": movedEntry.path || "",
            "kind": movedEntry.kind || "file",
            "angle": automaticItemAlignment ? angleForSlot(insertAt, Math.max(ringItems.count + 1, 1)) : angleForPoint(px, py),
            "childrenJson": JSON.stringify(movedEntry.children || [])
        })

        if (groupOpen && openGroupIndex >= 0 && insertAt <= openGroupIndex) {
            openGroupIndex += 1
        }

        schedulePersist()
    }

    function mergeItems(sourceIndex, targetIndex) {
        if (sourceIndex < 0 || targetIndex < 0 || sourceIndex === targetIndex) {
            return
        }
        if (sourceIndex >= ringItems.count || targetIndex >= ringItems.count) {
            return
        }

        var sourceEntry = modelEntryAt(sourceIndex)
        var targetEntry = modelEntryAt(targetIndex)
        if (!sourceEntry || !targetEntry) {
            return
        }

        var targetChildren = flattenGroupChildren(targetEntry)
        var sourceChildren = flattenGroupChildren(sourceEntry)
        var mergedChildren = []
        for (var i = 0; i < targetChildren.length; i++) {
            mergedChildren.push(cloneEntry(targetChildren[i]))
        }
        for (var j = 0; j < sourceChildren.length; j++) {
            mergedChildren.push(cloneEntry(sourceChildren[j]))
        }

        var defaultLabel = (targetEntry.kind === "group" && targetEntry.label)
                         ? targetEntry.label
                         : ((sourceEntry.kind === "group" && sourceEntry.label)
                            ? sourceEntry.label
                            : "New Group")
        var mergedGroup = {
            "label": defaultLabel,
            "color": targetEntry.color || sourceEntry.color || colorPalette[0],
            "path": "",
            "kind": "group",
            "angle": Number(targetEntry.angle || 0),
            "childrenJson": JSON.stringify(mergedChildren)
        }

        ringItems.set(targetIndex, mergedGroup)
        var removalIndex = sourceIndex
        if (sourceIndex < targetIndex) {
            removalIndex = sourceIndex
            targetIndex -= 1
        }
        ringItems.remove(removalIndex, 1)

        var createdFreshGroup = (sourceEntry.kind !== "group" && targetEntry.kind !== "group")
        schedulePersist()
        if (createdFreshGroup) {
            promptGroupName(targetIndex, defaultLabel)
        }
    }

    function applyFolderClosed() {
        folderOpen = false
        folderLoading = false
        folderRefreshStatus = ""
        currentFolderPath = ""
        folderTitle = ""
        folderEntries = []
        folderReturnToGroup = false
        folderReturnGroupTitle = ""
        folderReturnGroupEntries = []
        folderReturnGroupIndex = -1
        folderReturnGroupAnchorX = centerX
        folderReturnGroupAnchorY = centerY
        folderSceneClosed()
    }

    function applySettingsClosed() {
        settingsOpen = false
    }

    function resetToMainView() {
        groupEditMode = false
        groupOpen = false
        groupTitle = ""
        groupEntries = []
        openGroupIndex = -1
        groupNamingVisible = false
        renameTargetIndex = -1
        folderReturnToGroup = false
        folderReturnGroupTitle = ""
        folderReturnGroupEntries = []
        folderReturnGroupIndex = -1
        folderReturnGroupAnchorX = centerX
        folderReturnGroupAnchorY = centerY
        settingsOpen = false
        folderOpen = false
        folderLoading = false
        folderRefreshStatus = ""
        currentFolderPath = ""
        folderTitle = ""
        folderEntries = []
        recentRadialOpen = false
        recentFolderPath = ""
        resetDragState()
    }

    function maybeCloseAfterLaunch() {
        if (typeof appModel === "undefined" || !appModel || !appModel.closeAfterLaunch) {
            return
        }
        if (typeof backend !== "undefined" && backend && backend.requestHide) {
            backend.requestHide()
        }
    }

    function activateItem(itemIndex) {
        if (itemIndex < 0 || itemIndex >= ringItems.count) {
            return
        }
        var entry = ringItems.get(itemIndex)
        if (!entry.path) {
            if (entry.kind === "group") {
                if (groupEditMode) {
                    promptGroupName(itemIndex, entry.label || "Group")
                } else {
                    openGroupAtIndex(itemIndex)
                }
            }
            return
        }
        if (groupEditMode) {
            return
        }
        if (entry.kind === "folder") {
            if (typeof appModel !== "undefined" && appModel && appModel.isShellRecentFolderPath
                    && appModel.isShellRecentFolderPath(entry.path)) {
                openRecentRadialAtIndex(itemIndex)
            } else {
                openFolderPath(entry.path, entry.label || entry.path, false)
            }
            return
        }
        if (typeof appModel !== "undefined" && appModel && appModel.openPath) {
            if (appModel.openPath(entry.path)) {
                maybeCloseAfterLaunch()
            }
        }
    }

    function activateGroupEntry(groupIndex) {
        if (groupIndex < 0 || groupIndex >= groupEntries.length) {
            return
        }
        var entry = groupEntries[groupIndex]
        if (!entry) {
            return
        }
        if (entry.kind === "group") {
            groupTitle = entry.label || "Group"
            groupEntries = Array.isArray(entry.children) ? entry.children : []
            return
        }
        if (entry.kind === "folder") {
            openFolderPath(entry.path || "", entry.label || entry.path || "Folder", true)
            return
        }
        if (typeof appModel !== "undefined" && appModel && appModel.openPath) {
            if (appModel.openPath(entry.path || "")) {
                maybeCloseAfterLaunch()
            }
        }
    }

    function openFolderEntry(path, kind) {
        if (!path) {
            return
        }
        if (typeof appModel !== "undefined" && appModel && appModel.openPath) {
            if (appModel.openPath(path)) {
                maybeCloseAfterLaunch()
            }
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
        if (lowerPath.endsWith(".lnk") || lowerPath.endsWith(".url")) {
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
                "kind": kindFromPath(localPath),
                "angle": angleForSlot(ringItems.count, Math.max(ringItems.count + 1, 1)),
                "childrenJson": "[]"
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
                "kind": entry.kind || "file",
                "angle": Number(entry.angle || 0),
                "children": parseChildrenJson(entry.childrenJson)
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
        closeGroupView()
        groupNamingVisible = false
        renameTargetIndex = -1
        automaticItemAlignment = (typeof appModel !== "undefined" && appModel)
                                 ? !!appModel.automaticItemAlignment
                                 : true
        ringItems.clear()

        if (typeof appModel !== "undefined" && appModel && appModel.ringItems && appModel.ringItems.length > 0) {
            for (var i = 0; i < appModel.ringItems.length; i++) {
                var item = appModel.ringItems[i]
                ringItems.append({
                    "label": item.label || "Item",
                    "color": item.color || colorPalette[i % colorPalette.length],
                    "path": item.path || "",
                    "kind": item.kind || "file",
                    "angle": Number(item.angle || angleForSlot(i, Math.max(appModel.ringItems.length, 1))),
                    "childrenJson": JSON.stringify(item.children || [])
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
        function onFolderEntriesReady(folderPath, entries) {
            if (ring.recentRadialOpen && ring.folderPathsEqual(ring.recentFolderPath, folderPath)) {
                ring.groupEntries = entries
                return
            }
            if (!ring.folderOpen || ring.currentFolderPath !== folderPath) {
                return
            }
            ring.folderEntries = entries
            ring.folderLoading = false
            ring.folderRefreshStatus = "checked"
        }
        function onFolderRefreshStateChanged(folderPath, state) {
            if (ring.currentFolderPath !== folderPath) {
                return
            }
            ring.folderRefreshStatus = state
            ring.folderLoading = (state === "checking" || state === "pending")
        }
        function onAutomaticItemAlignmentChanged() {
            var nextValue = !!appModel.automaticItemAlignment
            if (ring.automaticItemAlignment && !nextValue) {
                ring.captureCurrentAlignedAngles()
            }
            ring.automaticItemAlignment = nextValue
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
        width: ring.decorativeOuterRingDiameter
        height: ring.decorativeOuterRingDiameter
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
        width: ring.decorativeInnerRingDiameter
        height: ring.decorativeInnerRingDiameter
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
            required property string childrenJson
            readonly property color entryColor: color
            readonly property int groupPreviewCount: ring.parseChildrenJson(childrenJson).length
            readonly property int total: iconRepeater.count
            readonly property int targetSlot: ring.slotForIndex(index)
            readonly property var targetPos: ring.slotPosition(targetSlot)
            readonly property bool isGroup: kind === "group"
            readonly property bool imagePreview: !isGroup && ring.pathLooksLikeImage(path, kind)
            readonly property int previewRevision: (typeof appModel !== "undefined" && appModel)
                                                   ? appModel.previewVersion
                                                   : 0
            readonly property string resolvedSource: {
                if (isGroup) {
                    return ""
                }
                var _ = previewRevision
                if (typeof appModel !== "undefined" && appModel && appModel.iconDataUrl) {
                    return appModel.iconDataUrl(path || "", kind || "file", label || "Item")
                }
                return ""
            }
            readonly property real revealStart: (index / Math.max(total, 1)) * 0.36
            readonly property real revealValue: Math.max(0.0, Math.min(1.0, (ring.openProgress - revealStart) / (1.0 - revealStart)))
            property bool dragging: false
            property bool pressActive: false
            property real dragCenterX: targetPos.x
            property real dragCenterY: targetPos.y
            property real pointerOffsetX: 0.0
            property real pointerOffsetY: 0.0
            property real pressStartX: 0.0
            property real pressStartY: 0.0
            property real movedDistance: 0.0

            width: 60
            height: 60
            x: dragging ? dragCenterX - width / 2 : targetPos.x - width / 2
            y: dragging ? dragCenterY - height / 2 : targetPos.y - height / 2
            z: dragging ? 200 : 100 - index
            opacity: ring.removingIndex === index ? 0.0 : revealValue * (ring.settingsOpen ? 0.18 : 1.0)
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
                border.width: 0

                Item {
                    id: imagePreviewMaskHost
                    anchors.fill: parent
                    visible: imagePreview
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: imagePreviewMaskHost.width
                            height: imagePreviewMaskHost.height
                            radius: imagePreviewMaskHost.width / 2
                            color: "white"
                        }
                    }

                    Image {
                        anchors.fill: parent
                        source: resolvedSource
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 18
                        color: "#7A0C1218"
                    }
                }

                Text {
                    visible: imagePreview
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    text: ring.displayLabel(label, path, kind)
                    color: "#F7FBFF"
                    font.pixelSize: 8
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                Column {
                    visible: isGroup
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 3

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 34
                        height: 34

                        Rectangle {
                            anchors.centerIn: parent
                            width: 28
                            height: 28
                            radius: width / 2
                            color: "#223240"
                            border.color: "#8CCFE3F6"
                            border.width: 1
                        }

                        Repeater {
                            model: groupPreviewCount
                            delegate: Item {
                                readonly property real miniOrbit: groupPreviewCount >= 7 ? 8.5 : 7
                                readonly property real angle: ((index / Math.max(groupPreviewCount, 1)) * Math.PI * 2) - (Math.PI / 2)
                                readonly property real dotSize: groupPreviewCount >= 7 ? 4 : 5
                                width: dotSize
                                height: dotSize
                                x: (parent.width / 2) + (Math.cos(angle) * miniOrbit) - (width / 2)
                                y: (parent.height / 2) + (Math.sin(angle) * miniOrbit) - (height / 2)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "#F4FAFF"
                                    opacity: 0.9
                                }
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        text: ring.displayLabel(label, path, kind)
                        color: "#F1F8FF"
                        font.pixelSize: 9
                        font.bold: true
                        font.underline: ring.groupEditMode
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }

                Column {
                    visible: !imagePreview && !isGroup
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 2

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 26
                        height: 26
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        source: resolvedSource
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        text: ring.displayLabel(label, path, kind)
                        color: "#E8F8FF"
                        font.pixelSize: 9
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.color: color
                    border.width: ring.mergeTargetIndex === index
                                  ? 3
                                  : (ring.hoverIndex === index && ring.draggedIndex >= 0 ? 2 : 1)

                    Behavior on border.color {
                        ColorAnimation { duration: ring.animDuration(110) }
                    }
                }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                enabled: ring.removingIndex < 0 && !ring.subViewOpen && !ring.groupOpen && !ring.groupNamingVisible
                hoverEnabled: true
                preventStealing: true
                acceptedButtons: Qt.LeftButton
                cursorShape: dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                onPressed: function(mouse) {
                    var p = dragArea.mapToItem(ring, mouse.x, mouse.y)
                    pressActive = true
                    dragging = false
                    dragCenterX = targetPos.x
                    dragCenterY = targetPos.y
                    pointerOffsetX = p.x - dragCenterX
                    pointerOffsetY = p.y - dragCenterY
                    pressStartX = p.x
                    pressStartY = p.y
                    movedDistance = 0.0
                    mouse.accepted = true
                }

                onPositionChanged: function(mouse) {
                    if (!pressActive) {
                        return
                    }
                    var p = dragArea.mapToItem(ring, mouse.x, mouse.y)
                    var dx = p.x - pressStartX
                    var dy = p.y - pressStartY
                    movedDistance = Math.sqrt((dx * dx) + (dy * dy))

                    if (!dragging) {
                        if (movedDistance < 8) {
                            return
                        }
                        dragging = true
                        ring.startDrag(index)
                    }

                    dragCenterX = p.x - pointerOffsetX
                    dragCenterY = p.y - pointerOffsetY
                    ring.updateDrag(index, p.x, p.y)
                }

                onReleased: function(mouse) {
                    if (!pressActive) {
                        return
                    }
                    var p = dragArea.mapToItem(ring, mouse.x, mouse.y)
                    var wasClick = !dragging
                    pressActive = false
                    dragging = false
                    if (!wasClick) {
                        ring.finishDrag(index, p.x, p.y)
                    }
                    dragCenterX = targetPos.x
                    dragCenterY = targetPos.y
                    if (wasClick) {
                        if (!ring.groupEditMode || kind === "group") {
                            ring.activateItem(index)
                        }
                    }
                }

                onCanceled: {
                    if (!pressActive) {
                        return
                    }
                    pressActive = false
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
        width: ring.coreButtonDiameter
        height: ring.coreButtonDiameter
        radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: ring.groupEditMode ? "#E63A2020" : "#DD1A2938" }
            GradientStop { position: 1.0; color: ring.groupEditMode ? "#C0281818" : "#B0121C28" }
        }
        border.color: ring.groupEditMode ? "#FF9B9B" : "#8BE0F4FF"
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
                  : (ring.groupEditMode
                     ? "Group Edit\nMode"
                     : (ring.settingsOpen ? "Settings" : (ring.folderOpen ? "Folder View" : "Radial Dock")))
            color: "#E8F8FF"
            font.pixelSize: ring.removeCandidate ? 14 : 16
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            text: ring.groupEditMode
                  ? "Click to exit"
                  : "Click settings / hold to group"
            color: "#98B5C6"
            font.pixelSize: 9
            opacity: centerHover.hovered && !ring.folderOpen && !ring.groupOpen ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: ring.animDuration(80); easing.type: Easing.OutCubic }
            }
        }

        HoverHandler {
            id: centerHover
        }

        MouseArea {
            id: coreClickArea
            anchors.fill: parent
            enabled: !ring.folderOpen && !ring.groupOpen && !ring.groupNamingVisible && ring.draggedIndex < 0
            acceptedButtons: Qt.LeftButton
            onPressed: holdToEditTimer.restart()
            onReleased: holdToEditTimer.stop()
            onCanceled: holdToEditTimer.stop()
            onClicked: {
                if (holdToEditTimer.triggeredEdit) {
                    holdToEditTimer.triggeredEdit = false
                    return
                }
                ring.toggleSettingsView()
            }
        }

        Timer {
            id: holdToEditTimer
            property bool triggeredEdit: false
            interval: 1000
            repeat: false
            onRunningChanged: {
                if (running) {
                    triggeredEdit = false
                }
            }
            onTriggered: {
                triggeredEdit = true
                ring.toggleGroupEditMode()
            }
        }
    }

    Item {
        id: groupOverlay
        width: ring.groupPanelSize
        height: ring.groupPanelSize
        x: ring.groupAnchorX - (width / 2)
        y: ring.groupAnchorY - (height / 2)
        visible: ring.groupOpen
        opacity: ring.groupOpen ? 1.0 : 0.0
        z: 290

        Behavior on opacity {
            NumberAnimation { duration: ring.animDuration(120); easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#EF101820"
            border.color: "#94D3E5F8"
            border.width: 1
        }

        Text {
            anchors.centerIn: parent
            text: ring.groupTitle
            color: "#F2FAFF"
            font.pixelSize: 11
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            width: Math.max(64, parent.width * 0.42)
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Repeater {
            model: ring.groupEntries
            delegate: Item {
                required property int index
                property var entry: (ring.groupEntries && index >= 0 && index < ring.groupEntries.length)
                                    ? ring.groupEntries[index]
                                    : ({})
                readonly property bool isGroup: (entry.kind || "") === "group"
                readonly property bool imagePreview: !isGroup && ring.pathLooksLikeImage(entry.path || "", entry.kind || "file")
                readonly property int previewRevision: (typeof appModel !== "undefined" && appModel)
                                                       ? appModel.previewVersion
                                                       : 0
                readonly property var pos: ring.groupSlotPosition(index, ring.groupEntries.length)
                readonly property string resolvedSource: {
                    if (isGroup) {
                        return ""
                    }
                    var _ = previewRevision
                    if (typeof appModel !== "undefined" && appModel && appModel.iconDataUrl) {
                        return appModel.iconDataUrl(entry.path || "", entry.kind || "file", entry.label || "Item")
                    }
                    return ""
                }
                property bool dragging: false
                property bool pressActive: false
                property real dragCenterX: pos.x
                property real dragCenterY: pos.y
                property real pointerOffsetX: 0
                property real pointerOffsetY: 0
                property real pressStartX: 0
                property real pressStartY: 0
                property real movedDistance: 0

                width: 52
                height: 52
                x: dragging ? dragCenterX - (width / 2) : pos.x - (width / 2)
                y: dragging ? dragCenterY - (height / 2) : pos.y - (height / 2)
                z: dragging ? 420 : 0

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "#E217202B"
                    border.color: "#77D4E8F4"
                    border.width: 1

                    Image {
                        anchors.fill: parent
                        visible: imagePreview
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                        source: resolvedSource
                    }

                    Column {
                        visible: !imagePreview
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 1

                        Rectangle {
                            visible: isGroup
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 24
                            height: 16
                            radius: 8
                            color: "#5079A0C0"
                            border.color: "#CFEFFF"
                            border.width: 1
                        }

                        Image {
                            visible: !isGroup
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 20
                            height: 20
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            source: resolvedSource
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            text: ring.displayLabel(entry.label || "Item", entry.path || "", entry.kind || "file")
                            color: "#EAF4FF"
                            font.pixelSize: 8
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    preventStealing: true
                    onPressed: function(mouse) {
                        var p = groupOverlay.mapFromItem(this, mouse.x, mouse.y)
                        pressActive = true
                        dragging = false
                        dragCenterX = pos.x
                        dragCenterY = pos.y
                        pointerOffsetX = p.x - dragCenterX
                        pointerOffsetY = p.y - dragCenterY
                        pressStartX = p.x
                        pressStartY = p.y
                        movedDistance = 0
                        mouse.accepted = true
                    }
                    onPositionChanged: function(mouse) {
                        if (!pressActive) {
                            return
                        }
                        var p = groupOverlay.mapFromItem(this, mouse.x, mouse.y)
                        var dx = p.x - pressStartX
                        var dy = p.y - pressStartY
                        movedDistance = Math.sqrt((dx * dx) + (dy * dy))
                        if (!dragging) {
                            if (movedDistance < 8) {
                                return
                            }
                            dragging = true
                        }
                        dragCenterX = p.x - pointerOffsetX
                        dragCenterY = p.y - pointerOffsetY
                    }
                    onReleased: function(mouse) {
                        if (!pressActive) {
                            return
                        }
                        var ringPoint = ring.mapFromItem(this, mouse.x, mouse.y)
                        var wasClick = !dragging
                        pressActive = false
                        dragging = false
                        dragCenterX = pos.x
                        dragCenterY = pos.y
                        if (wasClick) {
                            ring.activateGroupEntry(index)
                            return
                        }
                        if (!ring.recentRadialOpen
                                && !ring.isPointInsideOpenGroup(ringPoint.x, ringPoint.y)) {
                            ring.moveGroupEntryToMain(index, ringPoint.x, ringPoint.y)
                        }
                    }
                    onCanceled: {
                        pressActive = false
                        dragging = false
                        dragCenterX = pos.x
                        dragCenterY = pos.y
                        movedDistance = 0
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 280
        height: 142
        radius: 12
        visible: ring.groupNamingVisible
        opacity: ring.groupNamingVisible ? 1.0 : 0.0
        z: 340
        color: "#F418212B"
        border.color: "#89D3E5F8"
        border.width: 1

        Behavior on opacity {
            NumberAnimation { duration: ring.animDuration(100); easing.type: Easing.OutCubic }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Text {
                text: "Name This Group"
                color: "#F2FAFF"
                font.pixelSize: 14
                font.bold: true
            }

            TextField {
                id: groupNameField
                text: ring.groupNameDraft
                selectByMouse: true
                onTextChanged: ring.groupNameDraft = text
                onAccepted: ring.commitGroupName()
            }

            Row {
                spacing: 8

                Rectangle {
                    width: 84
                    height: 28
                    radius: 6
                    color: saveGroupNameMouse.pressed ? "#2A3946" : (saveGroupNameMouse.containsMouse ? "#324555" : "#273643")
                    border.color: saveGroupNameMouse.containsMouse ? "#6B90AA" : "#4A6478"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Save"
                        color: "#EAF4FF"
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: saveGroupNameMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        onClicked: ring.commitGroupName()
                    }
                }

                Rectangle {
                    width: 84
                    height: 28
                    radius: 6
                    color: cancelGroupNameMouse.pressed ? "#2A3946" : (cancelGroupNameMouse.containsMouse ? "#324555" : "#273643")
                    border.color: cancelGroupNameMouse.containsMouse ? "#6B90AA" : "#4A6478"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: "#EAF4FF"
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: cancelGroupNameMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        onClicked: ring.cancelGroupNaming()
                    }
                }
            }
        }
    }

    Settings {
        id: settingsPanel
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
