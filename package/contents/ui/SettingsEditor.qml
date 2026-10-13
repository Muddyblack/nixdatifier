pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic as QQC
import QtQuick.Layouts
import "SettingsSchema.js" as Schema
import "shared" as UI

QQC.Pane {
    id: editor
    required property var settings
    property bool hyprland: false
    property bool infoOnlineEnabled: true
    property string currentVersion: ""
    property int currentTab: 0
    onCurrentTabChanged: {
        if (scroll.contentItem)
            scroll.contentItem.contentY = 0;
    }
    property string query: ""
    readonly property bool onScreen: visible && Window.window !== null && Window.window.visible
    readonly property var tabs: [qsTr("General"), qsTr("Commands"), qsTr("Behavior"), qsTr("Design"), qsTr("Info")]
    readonly property var tabKeys: ["General", "Commands", "Behavior", "Design", "Info"]
    readonly property var tabIcons: ["settings", "terminal", "activate", "grid", "info"]
    readonly property var descriptions: [qsTr("Connect your system flake and choose how generations are shown."), qsTr("Keep your rebuild commands and terminal preferences together."), qsTr("Choose how updates, generation actions and package details behave."), qsTr("Make the panel and popup feel at home on your desktop."), qsTr("Project information, releases and ways to contribute.")]
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
        return Schema.fields.concat(hyprland ? placementFields : []).filter(f => search ? (f.label + " " + f.group + " " + (f.help || "")).toLowerCase().includes(search) : f.tab === tabKeys[currentTab]);
    }
    readonly property var groups: [...new Set(shownFields.map(f => f.group))]

    padding: 18
    palette.window: "#151718"
    palette.windowText: "#eeefeb"
    palette.base: "#0f1112"
    palette.text: "#eeefeb"
    palette.button: "#24282a"
    palette.buttonText: "#eeefeb"
    palette.highlight: "#91bcff"
    palette.highlightedText: "#101b2c"
    palette.placeholderText: "#787f82"
    background: Rectangle {
        color: "#151718"
        radius: 14
        border.color: "#10ffffff"
    }

    contentItem: ColumnLayout {
        spacing: 16
        RowLayout {
            Layout.fillWidth: true
            Image {
                source: Qt.resolvedUrl("../../icon.png")
                sourceSize: Qt.size(80, 80)
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text {
                    text: qsTr("nixdatifier")
                    color: "#eeefeb"
                    font.pixelSize: 19
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: editor.descriptions[editor.currentTab]
                    color: "#9da3a5"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
            }
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: editor.tabs
                QQC.Button {
                    id: tabButton
                    required property string modelData
                    required property int index
                    text: modelData
                    objectName: "settingsTab_" + editor.tabKeys[index]
                    implicitHeight: 34
                    implicitWidth: tabContent.implicitWidth + 20
                    padding: 10
                    onClicked: {
                        editor.query = "";
                        search.text = "";
                        editor.currentTab = index;
                    }
                    contentItem: RowLayout {
                        id: tabContent
                        spacing: 6
                        Image {
                            source: Qt.resolvedUrl("assets/ic_" + editor.tabIcons[tabButton.index] + ".svg")
                            sourceSize: Qt.size(28, 28)
                            Layout.preferredWidth: 14
                            Layout.preferredHeight: 14
                            opacity: editor.currentTab === tabButton.index ? 1 : 0.65
                        }
                        Text {
                            text: tabButton.text
                            color: editor.currentTab === tabButton.index ? "#c6dcff" : "#9da3a5"
                            font.pixelSize: 11
                        }
                    }
                    background: Rectangle {
                        radius: 8
                        color: editor.currentTab === tabButton.index ? "#22344b" : tabButton.hovered ? "#08ffffff" : "transparent"
                        border.color: tabButton.activeFocus ? "#91bcff" : editor.currentTab === tabButton.index ? "#5091bcff" : "#10ffffff"
                    }
                }
            }
        }
        SettingsTextField {
            id: search
            Layout.fillWidth: true
            visible: editor.currentTab !== 4
            placeholderText: qsTr("Search settings…")
            selectByMouse: true
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
                spacing: 18
                Repeater {
                    model: editor.groups
                    Column {
                        id: group
                        required property string modelData
                        readonly property var fields: editor.shownFields.filter(f => f.group === modelData)
                        width: parent.width
                        spacing: 8
                        Text {
                            text: group.modelData.toUpperCase()
                            color: "#b1b7b9"
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.2
                        }
                        Rectangle {
                            width: parent.width
                            height: rows.implicitHeight + 4
                            radius: 14
                            color: "#04ffffff"
                            border.color: "#10ffffff"
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
                                        enabled: modelData.key !== "panelSideOffset" || !String(editor.settings.popupPosition).endsWith("center")
                                        opacity: enabled ? 1 : 0.45
                                    }
                                }
                            }
                        }
                    }
                }
                Text {
                    visible: editor.currentTab !== 4 && editor.groups.length === 0
                    text: qsTr("No matching settings")
                    color: "#9da3a5"
                    font.pixelSize: 12
                }
                Loader {
                    objectName: "projectInfoLoader"
                    width: parent.width
                    active: editor.onScreen && editor.currentTab === 4
                    sourceComponent: ProjectInfoPane {
                        showBranding: false
                        currentVersion: editor.currentVersion
                        onlineEnabled: editor.infoOnlineEnabled
                    }
                }
            }
        }
    }
}
