pragma ComponentBehavior: Bound
import QtQuick
import "SettingsTheme.js" as Theme
import QtQuick.Window
import QtQuick.Controls.Basic as QQC
import QtQuick.Layouts
import "SettingsSchema.js" as Schema
import "shared" as UI

QQC.Pane {
    id: editor
    property var tone: Theme.fromSettings(settings)
    required property var settings
    property bool hyprland: false
    property bool infoOnlineEnabled: true
    property string currentVersion: ""
    property int currentTab: 0
    onCurrentTabChanged: {
        if (scroll.contentItem)
            scroll.contentItem.contentY = 0;
        Qt.callLater(compactNavigation.revealSelection);
    }
    property string query: ""
    readonly property bool onScreen: visible && Window.window !== null && Window.window.visible
    readonly property bool wide: width >= 740
    readonly property var navigation: [0, 1, 2, 5, 3, 6, 4]
    readonly property var tabs: [qsTr("System"), qsTr("Commands"), qsTr("Generations"), qsTr("Appearance"), qsTr("Info"), qsTr("Panel"), qsTr("Advanced")]
    readonly property var tabKeys: ["General", "Commands", "Behavior", "Design", "Info", "Panel", "Advanced"]
    readonly property var tabIcons: ["settings", "terminal", "activate", "grid", "info", "grid", "settings"]
    readonly property var descriptions: [qsTr("Your system flake, update checks and default view."), qsTr("Your rebuild shortcuts, terminal and cleanup commands."), qsTr("Generation actions, notifications and package comparisons."), qsTr("Fine-tune the colours, typography and feel of your widget."), qsTr("Project information, releases and ways to contribute."), qsTr("Choose how Nixdatifier lives on your desktop."), qsTr("Permissions, secrets, GitHub access and persistent storage.")]
    function sectionFor(field) {
        if (["Secrets", "Impermanence", "Permissions"].includes(field.group))
            return "Advanced";
        if (["Panel", "Popup size", "Hyprland panel"].includes(field.group))
            return "Panel";
        return field.tab;
    }
    function fieldEnabled(field) {
        if (field.key === "panelSideOffset")
            return !String(settings.popupPosition).endsWith("center");
        if (field.key === "customTextColor")
            return !settings.useSystemTextColor;
        if (["bgColor", "bgRadius"].includes(field.key))
            return settings.showBg;
        return true;
    }
    readonly property var placementFields: [
        {
            key: "pillMode",
            tab: "Design",
            group: "Hyprland panel",
            label: qsTr("Panel visibility"),
            type: "String",
            choices: [
                {
                    label: qsTr("Always show pill"),
                    value: "always"
                },
                {
                    label: qsTr("Reveal at screen edge"),
                    value: "hover"
                },
                {
                    label: qsTr("Tray only"),
                    value: "tray"
                }
            ]
        },
        {
            key: "popupPosition",
            tab: "Design",
            group: "Hyprland panel",
            label: qsTr("Popup position"),
            type: "String",
            choices: [
                {
                    label: qsTr("Top left"),
                    value: "top-left"
                },
                {
                    label: qsTr("Top center"),
                    value: "top-center"
                },
                {
                    label: qsTr("Top right"),
                    value: "top-right"
                },
                {
                    label: qsTr("Bottom left"),
                    value: "bottom-left"
                },
                {
                    label: qsTr("Bottom center"),
                    value: "bottom-center"
                },
                {
                    label: qsTr("Bottom right"),
                    value: "bottom-right"
                }
            ]
        },
        {
            key: "panelEdgeOffset",
            tab: "Design",
            group: "Hyprland panel",
            label: qsTr("Edge inset (px)"),
            type: "Int",
            min: 0,
            max: 16384
        },
        {
            key: "panelSideOffset",
            tab: "Design",
            group: "Hyprland panel",
            label: qsTr("Side inset (px)"),
            help: qsTr("Drag the pill or adjust the insets to avoid other widgets."),
            type: "Int",
            min: 0,
            max: 16384
        }
    ]
    readonly property var shownFields: {
        if (!onScreen || currentTab === 4)
            return [];
        const search = query.trim().toLowerCase();
        return Schema.fields.concat(hyprland ? placementFields : []).filter(f => search ? (f.label + " " + f.group + " " + (f.help || "")).toLowerCase().includes(search) : sectionFor(f) === tabKeys[currentTab]);
    }
    readonly property var groups: [...new Set(shownFields.map(f => f.group))]

    padding: 16
    palette.window: tone.panel
    palette.windowText: tone.text
    palette.base: tone.sunk
    palette.text: tone.text
    palette.button: tone.hover
    palette.buttonText: tone.text
    palette.highlight: tone.brand
    palette.highlightedText: tone.brandInk
    palette.placeholderText: tone.dim
    background: Rectangle {
        color: tone.panel
        radius: 18
        gradient: Gradient {
            GradientStop {
                position: 0
                color: tone.panelTop
            }
            GradientStop {
                position: 1
                color: tone.panelBottom
            }
        }
        border.color: tone.line2
    }

    Component {
        id: navigationEntry
        QQC.Button {
            id: entry
            required property int modelData
            readonly property bool selected: editor.currentTab === modelData
            objectName: "settingsTab_" + editor.tabKeys[modelData]
            Layout.fillWidth: editor.wide
            width: editor.wide ? 140 : implicitWidth
            implicitWidth: label.implicitWidth + 54
            implicitHeight: 36
            padding: 12
            onClicked: {
                editor.query = "";
                search.text = "";
                editor.currentTab = modelData;
            }
            contentItem: RowLayout {
                spacing: 10
                Image {
                    source: Qt.resolvedUrl("assets/ic_" + editor.tabIcons[entry.modelData] + ".svg")
                    sourceSize: Qt.size(32, 32)
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    opacity: entry.selected ? 1 : 0.5
                }
                Text {
                    id: label
                    Layout.fillWidth: true
                    text: editor.tabs[entry.modelData]
                    color: entry.selected ? tone.text : entry.hovered ? tone.text : tone.muted
                    font.family: tone.fontFamily
                    font.pixelSize: 12
                    font.weight: entry.selected ? Font.DemiBold : Font.Normal
                }
            }
            background: Rectangle {
                radius: 10
                color: entry.selected ? tone.chipPressed : entry.hovered ? tone.hover : "transparent"
                border.color: entry.activeFocus ? tone.brand : entry.selected ? tone.chipPressedBorder : "transparent"
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: 12
        RowLayout {
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 10
                color: tone.sunk
                border.color: tone.line2
                Image {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    source: Qt.resolvedUrl("../../icon.png")
                    sourceSize: Qt.size(60, 60)
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text {
                    text: qsTr("nixdatifier")
                    color: tone.text
                    font.family: tone.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
                Text {
                    visible: !editor.wide
                    text: qsTr("Settings")
                    color: tone.dim
                    font.family: tone.fontFamily
                    font.pixelSize: 12
                }
            }
            Text {
                text: editor.currentVersion
                color: tone.dim
                font.family: tone.fontFamily
                font.pixelSize: 11
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: tone.line
        }
        Flickable {
            id: compactNavigation
            function revealSelection() {
                if (!visible)
                    return;
                const entry = compactNav.children[editor.navigation.indexOf(editor.currentTab)];
                if (entry)
                    contentX = Math.max(0, Math.min(entry.x - (width - entry.width) / 2, contentWidth - width));
            }
            onVisibleChanged: Qt.callLater(revealSelection)
            onWidthChanged: Qt.callLater(revealSelection)
            visible: !editor.wide
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            contentWidth: compactNav.width
            contentHeight: height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Row {
                id: compactNav
                spacing: 4
                Repeater {
                    model: editor.navigation
                    delegate: navigationEntry
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12
            ColumnLayout {
                visible: editor.wide
                Layout.preferredWidth: 140
                Layout.fillHeight: true
                spacing: 5
                Repeater {
                    model: editor.navigation
                    delegate: navigationEntry
                }
                Item {
                    Layout.fillHeight: true
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        text: editor.tabs[editor.currentTab]
                        color: tone.text
                        font.family: tone.fontFamily
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: editor.descriptions[editor.currentTab]
                        color: tone.muted
                        font.family: tone.fontFamily
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        lineHeight: 1.3
                    }
                }
                SettingsTextField {
                    id: search
                    tone: editor.tone
                    Layout.fillWidth: true
                    visible: editor.currentTab !== 4
                    placeholderText: qsTr("Search all settings…")
                    Accessible.name: qsTr("Search settings")
                    onTextChanged: editor.query = text
                }
                UI.ScrollView {
                    id: scroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: availableWidth
                    clip: true
                    Column {
                        width: scroll.availableWidth
                        spacing: 12
                        Rectangle {
                            visible: editor.currentTab === 3 && editor.query === ""
                            width: parent.width
                            height: 88
                            radius: 14
                            color: tone.sunk
                            border.color: tone.line2
                            Text {
                                x: 16
                                y: 12
                                text: qsTr("APPEARANCE PREVIEW")
                                color: tone.dim
                                font.family: tone.fontFamily
                                font.pixelSize: 10
                                font.letterSpacing: 1
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: 10
                                width: Math.min(parent.width - 40, 310)
                                height: 42
                                color: editor.settings.showBg ? editor.settings.bgColor : "transparent"
                                radius: editor.settings.bgRadius
                                border.color: "#20ffffff"
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 12
                                    Image {
                                        width: 26
                                        height: 26
                                        source: Qt.resolvedUrl("../../icon.png")
                                    }
                                    Text {
                                        text: qsTr("Generation 142")
                                        color: editor.settings.useSystemTextColor ? editor.palette.text : editor.settings.customTextColor
                                        font.family: tone.fontFamily
                                        font.pixelSize: 13 * editor.settings.fontScale
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Rectangle {
                                        width: 7
                                        height: 7
                                        radius: 4
                                        color: editor.settings.accentColor
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                        Repeater {
                            model: editor.groups
                            Column {
                                id: group
                                required property string modelData
                                readonly property var fields: editor.shownFields.filter(f => f.group === modelData)
                                width: parent.width
                                spacing: 9
                                Text {
                                    text: group.modelData.toUpperCase()
                                    color: tone.sectionTitle
                                    font.family: tone.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 1.2
                                    leftPadding: 2
                                }
                                Rectangle {
                                    width: parent.width
                                    height: rows.implicitHeight + 4
                                    radius: 14
                                    color: tone.card
                                    border.color: tone.line
                                    Column {
                                        id: rows
                                        x: 14
                                        y: 2
                                        width: parent.width - 28
                                        Repeater {
                                            model: group.fields
                                            SettingsField {
                                                required property var modelData
                                                required property int index
                                                width: rows.width
                                                height: implicitHeight
                                                field: modelData
                                                settings: editor.settings
                                                first: index === 0
                                                enabled: editor.fieldEnabled(modelData)
                                                opacity: enabled ? 1 : 0.4
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Text {
                            visible: editor.currentTab !== 4 && editor.groups.length === 0
                            text: qsTr("No matching settings. Try another search.")
                            color: tone.muted
                            font.family: tone.fontFamily
                            font.pixelSize: 12
                        }
                        Loader {
                            objectName: "projectInfoLoader"
                            width: parent.width
                            active: editor.onScreen && editor.currentTab === 4
                            sourceComponent: ProjectInfoPane {
                                tone: editor.tone
                                showBranding: false
                                currentVersion: editor.currentVersion
                                onlineEnabled: editor.infoOnlineEnabled
                            }
                        }
                    }
                }
            }
        }
    }
}
