import QtQuick
import QtQuick.Controls

Item {
    id: settings
    signal clearAllConfirmed()
    signal resetDefaultsConfirmed()
    property bool confirmClear: false
    property bool confirmReset: false

    function clampSpeed(value) {
        return Math.max(0.1, Math.min(10.0, value))
    }

    function clampThreshold(value) {
        return Math.max(1, Math.min(5000, value))
    }

    function commitSpeed() {
        if (typeof appModel === "undefined") {
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
        if (typeof appModel === "undefined") {
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

    function refreshFromModel() {
        if (typeof appModel === "undefined") {
            return
        }
        speedField.text = Number(appModel.animationSpeedScale).toFixed(2)
        thresholdField.text = String(appModel.folderCompactThreshold)
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
            height: 34
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
                text: typeof appModel !== "undefined"
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
                checked: typeof appModel !== "undefined" ? appModel.animationsEnabled : true
                anchors.verticalCenter: parent.verticalCenter
                onToggled: {
                    if (typeof appModel !== "undefined") {
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
            height: 34
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
                text: typeof appModel !== "undefined"
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
            height: 34
            spacing: 10

            Text {
                text: "Refresh folder on open"
                color: "#D7E8F4"
                font.pixelSize: 12
                width: 150
                anchors.verticalCenter: parent.verticalCenter
            }
            Switch {
                checked: typeof appModel !== "undefined" ? appModel.refreshOnOpen : true
                anchors.verticalCenter: parent.verticalCenter
                onToggled: {
                    if (typeof appModel !== "undefined") {
                        appModel.refreshOnOpen = checked
                    }
                }
            }
            Text {
                text: "If off, cached previews are preferred"
                color: "#8DA7B9"
                font.pixelSize: 10
                width: parent.width - 270
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
    }
}
