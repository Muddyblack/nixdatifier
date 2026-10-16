pragma ComponentBehavior: Bound
import QtQuick
import "SettingsTheme.js" as Theme
import QtQuick.Controls.Basic as QQC
import QtQuick.Layouts

// Studio-style row: description on the left, one live control on the right.
Item {
    id: row
    property var tone: Theme.fromSettings(settings)
    required property var field
    required property var settings
    property bool first: false
    readonly property var value: settings[field.key]
    readonly property bool commands: field.key === "customCommands"
    readonly property bool colorField: field.type === "Color" || field.key === "bgColor"
    readonly property bool stacked: commands || (!field.choices && field.type === "String" && !colorField && width < 620) || width < 400
    readonly property real controlWidth: field.type === "Bool" ? 36 : field.type === "Int" ? 130 : field.type === "Double" ? 232 : !field.choices && field.type === "String" && !colorField ? Math.min(400, width * 0.55) : 210
    objectName: "setting_" + field.key
    implicitHeight: content.height + 22

    function commit(next) {
        settings[field.key] = next;
    }
    function commandList() {
        try {
            const list = JSON.parse(value || "[]");
            return Array.isArray(list) ? list : [];
        } catch (error) {
            return [];
        }
    }
    function editCommand(index, key, next) {
        const list = commandList();
        if (list[index][key] === next)
            return;
        list[index][key] = next;
        commit(JSON.stringify(list));
    }

    Rectangle {
        width: parent.width
        height: 1
        color: tone.line
        visible: !row.first
    }
    Item {
        id: content
        y: 11
        width: parent.width
        height: row.stacked ? heading.height + 10 + control.height : Math.max(heading.height, control.height)
        Column {
            id: heading
            width: row.stacked ? parent.width : parent.width - row.controlWidth - 20
            y: row.stacked ? 0 : (parent.height - height) / 2
            spacing: 2
            Text {
                width: parent.width
                text: row.field.label
                color: tone.text
                font.family: tone.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: row.field.help || ""
                color: tone.muted
                font.family: tone.fontFamily
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                lineHeight: 1.2
            }
        }
        Loader {
            id: control
            x: row.stacked ? 0 : parent.width - width
            y: row.stacked ? heading.height + 10 : (parent.height - height) / 2
            width: row.stacked ? parent.width : row.controlWidth
            height: (item as Item)?.implicitHeight ?? 0
            sourceComponent: row.commands ? commandsControl : row.field.choices ? (row.field.choices.length <= 3 ? segmentControl : choiceControl) : row.field.type === "Bool" ? switchControl : row.field.type === "Int" ? numberControl : row.field.type === "Double" ? rangeControl : textControl
        }
    }
    Component {
        id: switchControl
        Item {
            implicitHeight: 21
            QQC.Switch {
                id: toggle
                anchors.right: parent.right
                width: 36
                height: 21
                padding: 0
                checked: !!row.value
                Accessible.name: row.field.label
                onToggled: row.commit(checked)
                indicator: Rectangle {
                    width: 36
                    height: 21
                    radius: 10.5
                    y: 0
                    color: tone.switchOff
                    gradient: toggle.checked ? switchGradient : null
                    Gradient {
                        id: switchGradient
                        GradientStop {
                            position: 0
                            color: tone.switchOnTop
                        }
                        GradientStop {
                            position: 1
                            color: tone.switchOnBottom
                        }
                    }
                    border.color: toggle.activeFocus ? "#ffffff" : "transparent"
                    Rectangle {
                        x: toggle.checked ? 18 : 3
                        Behavior on x {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutBack
                                easing.overshoot: 2
                            }
                        }
                        y: 3
                        width: 15
                        height: 15
                        radius: 7.5
                        color: toggle.checked ? tone.brandInk : tone.knob
                    }
                }
            }
        }
    }
    Component {
        id: segmentControl
        Rectangle {
            implicitHeight: segments.implicitHeight + 8
            radius: 9
            color: tone.sunk
            border.color: tone.line2
            Flow {
                id: segments
                x: 4
                y: 4
                width: parent.width - 8
                spacing: 2
                Repeater {
                    model: row.field.choices
                    QQC.Button {
                        id: segment
                        required property var modelData
                        readonly property bool selected: modelData.value === row.value
                        implicitWidth: contentItem.implicitWidth + 20
                        implicitHeight: 28
                        horizontalPadding: 10
                        Accessible.name: row.field.label + ": " + modelData.label
                        onClicked: row.commit(modelData.value)
                        contentItem: Text {
                            text: segment.modelData.label
                            color: segment.selected ? tone.segPressedText : tone.muted
                            font.family: tone.fontFamily
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            radius: 6
                            color: segment.selected ? tone.segPressed : segment.hovered ? tone.hover : "transparent"
                            border.color: segment.activeFocus ? tone.brand : "transparent"
                        }
                    }
                }
            }
        }
    }
    Component {
        id: choiceControl
        QQC.ComboBox {
            id: choice
            objectName: "choice_" + row.field.key
            implicitHeight: 32
            leftPadding: 10
            rightPadding: 30
            contentItem: Text {
                text: choice.displayText
                color: tone.text
                font.family: tone.fontFamily
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            indicator: Image {
                x: choice.width - width - 10
                y: (choice.height - height) / 2
                width: 12
                height: 12
                source: Qt.resolvedUrl("assets/ic_chevron_down.svg")
            }
            delegate: QQC.ItemDelegate {
                id: option
                required property int index
                required property var modelData
                width: choice.width - 8
                implicitHeight: 32
                highlighted: choice.highlightedIndex === index
                contentItem: Text {
                    text: option.modelData.label
                    color: option.highlighted ? tone.text : tone.text
                    font.family: tone.fontFamily
                    font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                background: Rectangle {
                    radius: 6
                    color: option.highlighted ? tone.segPressed : option.hovered ? tone.hover : "transparent"
                }
            }
            popup: QQC.Popup {
                y: choice.height + 4
                width: choice.width
                implicitHeight: Math.min(contentItem.implicitHeight + 8, 260)
                padding: 4
                contentItem: ListView {
                    clip: true
                    implicitHeight: contentHeight
                    model: choice.popup.visible ? choice.delegateModel : null
                    currentIndex: choice.highlightedIndex
                    QQC.ScrollIndicator.vertical: QQC.ScrollIndicator {}
                }
                background: Rectangle {
                    color: tone.panel
                    radius: 8
                    border.color: tone.switchOff
                }
            }
            background: Rectangle {
                radius: 8
                color: tone.sunk
                border.color: choice.activeFocus ? tone.brand : tone.line2
            }
            model: row.field.choices
            textRole: "label"
            valueRole: "value"
            currentIndex: model.findIndex(choice => choice.value === row.value)
            Accessible.name: row.field.label
            onActivated: row.commit(currentValue)
        }
    }
    Component {
        id: numberControl
        QQC.SpinBox {
            id: number
            objectName: "number_" + row.field.key
            background: Rectangle {
                radius: 8
                color: tone.sunk
                border.color: number.activeFocus ? tone.brand : tone.line2
            }
            implicitHeight: 32
            padding: 0
            leftPadding: 30
            rightPadding: 30
            contentItem: TextInput {
                text: number.textFromValue(number.value, number.locale)
                font.family: tone.fontFamily
                font.pixelSize: 12
                color: tone.text
                selectionColor: tone.brand
                selectedTextColor: tone.brandInk
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                readOnly: !number.editable
                validator: number.validator
                inputMethodHints: Qt.ImhDigitsOnly
            }
            up.indicator: Rectangle {
                x: number.width - width
                width: 28
                height: number.height
                radius: 8
                color: number.up.hovered || number.up.pressed ? tone.hover : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "+"
                    color: tone.muted
                    font.pixelSize: 15
                }
            }
            down.indicator: Rectangle {
                width: 28
                height: number.height
                radius: 8
                color: number.down.hovered || number.down.pressed ? tone.hover : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "−"
                    color: tone.muted
                    font.pixelSize: 15
                }
            }
            editable: true
            from: row.field.min === undefined ? 0 : row.field.min
            to: row.field.max === undefined ? 100000 : row.field.max
            value: Number(row.value)
            Accessible.name: row.field.label
            onValueModified: row.commit(value)
        }
    }
    Component {
        id: rangeControl
        RowLayout {
            QQC.Slider {
                id: slider
                objectName: "slider_" + row.field.key
                Layout.fillWidth: true
                implicitHeight: 23
                background: Rectangle {
                    x: slider.leftPadding
                    y: slider.topPadding + slider.availableHeight / 2 - height / 2
                    width: slider.availableWidth
                    height: 4
                    radius: 2
                    color: tone.rangeTrack
                    Rectangle {
                        x: slider.mirrored ? parent.width - width : 0
                        width: slider.position * parent.width
                        height: parent.height
                        radius: 2
                        color: tone.brand
                    }
                }
                handle: Rectangle {
                    x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                    y: slider.topPadding + slider.availableHeight / 2 - height / 2
                    width: 15
                    height: 15
                    radius: 7.5
                    color: tone.rangeThumb
                    border.width: slider.activeFocus ? 2 : 1
                    border.color: slider.activeFocus ? tone.text : tone.sunk
                }
                from: row.field.min || 0
                to: row.field.max || 2
                value: Number(row.value)
                stepSize: row.field.key === "fontScale" ? 0.05 : 1
                Accessible.name: row.field.label
                onMoved: row.commit(value)
            }
            Rectangle {
                implicitWidth: Math.max(54, output.implicitWidth + 14)
                implicitHeight: output.implicitHeight + 6
                radius: 6
                color: tone.hover
                border.color: tone.line
                Text {
                    id: output
                    anchors.centerIn: parent
                    text: Number(row.value).toFixed(row.field.key === "fontScale" ? 2 : 0)
                    color: tone.outputText
                    font.family: tone.fontFamily
                    font.pixelSize: 11
                    font.features: ({
                            "tnum": 1
                        })
                }
            }
        }
    }
    Component {
        id: textControl
        ColumnLayout {
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    visible: row.colorField
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 8
                    color: row.colorField ? String(row.value) : "transparent"
                    border.color: "#44ffffff"
                }
                SettingsTextField {
                    tone: row.tone
                    Layout.fillWidth: true
                    text: String(row.value ?? "")
                    selectByMouse: true
                    Accessible.name: row.field.label
                    placeholderText: row.colorField ? "#RRGGBB" : qsTr("Automatic")
                    font.family: tone.fontFamily
                    font.pixelSize: 12
                    onEditingFinished: {
                        if (row.colorField && !/^#(?:[a-fA-F0-9]{6}|[a-fA-F0-9]{8})$/.test(text)) {
                            text = String(row.value);
                            return;
                        }
                        row.commit(text);
                    }
                }
            }
            SettingsSwatches {
                visible: row.colorField
                Layout.fillWidth: true
                swatches: row.colorField ? ["#55ffcc", "#0eadcf", "#91bcff", "#a6a1ff", "#efb888", "#71849b"] : []
                value: String(row.value)
                onActivated: value => row.commit(value)
            }
        }
    }
    Component {
        id: commandsControl
        ColumnLayout {
            spacing: 10
            Repeater {
                model: row.commandList()
                Rectangle {
                    id: commandRow
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: commandBody.implicitHeight + 24
                    radius: 10
                    color: tone.sunk
                    border.color: tone.line
                    ColumnLayout {
                        id: commandBody
                        x: 12
                        y: 12
                        width: parent.width - 24
                        spacing: 8
                        Text {
                            text: qsTr("COMMAND %1").arg(commandRow.index + 1)
                            color: tone.dim
                            font.family: tone.fontFamily
                            font.pixelSize: 10
                            font.letterSpacing: 1
                        }
                        RowLayout {
                            SettingsTextField {
                                tone: row.tone
                                Layout.fillWidth: true
                                text: commandRow.modelData.label
                                placeholderText: qsTr("Button label")
                                Accessible.name: qsTr("Command label")
                                onEditingFinished: row.editCommand(commandRow.index, "label", text)
                            }
                            SettingsButton {
                                tone: row.tone
                                text: qsTr("Remove")
                                compact: true
                                onClicked: {
                                    const list = row.commandList();
                                    list.splice(commandRow.index, 1);
                                    row.commit(JSON.stringify(list));
                                }
                            }
                        }
                        SettingsTextField {
                            tone: row.tone
                            Layout.fillWidth: true
                            text: commandRow.modelData.cmd
                            placeholderText: qsTr("Command, e.g. upnix")
                            Accessible.name: qsTr("Command to run")
                            onEditingFinished: row.editCommand(commandRow.index, "cmd", text)
                        }
                    }
                }
            }
            SettingsButton {
                tone: row.tone
                text: qsTr("Add command")
                primary: true
                enabled: row.commandList().length < 4
                onClicked: {
                    const list = row.commandList();
                    list.push({
                        label: "",
                        cmd: "",
                        color: "accent"
                    });
                    row.commit(JSON.stringify(list));
                }
            }
        }
    }
}
