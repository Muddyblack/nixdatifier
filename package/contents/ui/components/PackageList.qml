import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shared" as UI

ColumnLayout {
    id: root
    property var storePathCache: ({})
    signal storePathRequested(var pkg)
    property var packages: []
    property var iconCache: ({})
    property var metaCache: ({})
    property color textColor: UI.Theme.textColor
    property color accentColor: UI.Theme.highlightColor
    property real fs: 1
    property bool showPackageIcons: true
    property bool enableGlow: true
    property bool filterEnabled: true
    property string viewMode: "compact"
    property real maximumHeight: 280
    property string heading: qsTr("Package changes")
    property string kind: "all"
    property string searchPlaceholder: qsTr("Filter packages…")
    signal copyToClipboard(string text)
    spacing: 8
    readonly property var filtered: packages.filter(p => (kind === "all" || p.type === kind) && (p.name || "").toLowerCase().indexOf(search.text.trim().toLowerCase()) >= 0)
    RowLayout {
        Layout.fillWidth: true
        Text {
            text: root.heading + " · " + root.packages.length
            color: UI.Theme.muted
            font.pixelSize: 10 * root.fs
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        TextField {
            id: search
            objectName: "packageSearch"
            Accessible.name: root.searchPlaceholder
            Keys.onEscapePressed: event => {
                if (text.length) {
                    clear();
                    event.accepted = true;
                } else {
                    event.accepted = false;
                }
            }
            visible: root.filterEnabled
            Layout.preferredWidth: Math.min(180, root.width * .45)
            implicitHeight: 26 * root.fs
            leftPadding: 8
            rightPadding: 8
            color: root.textColor
            placeholderTextColor: UI.Theme.muted
            background: Rectangle {
                color: "#04ffffff"
                border.color: search.activeFocus ? root.accentColor : UI.Theme.line
                radius: 5
            }
            placeholderText: root.searchPlaceholder
            font.pixelSize: 9 * root.fs
            selectByMouse: true
        }
    }
    Flow {
        Layout.fillWidth: true
        spacing: 5
        Repeater {
            model: [
                {
                    type: "all",
                    label: qsTr("All"),
                    color: root.accentColor
                },
                {
                    type: "added",
                    label: qsTr("Added"),
                    color: UI.Theme.positive
                },
                {
                    type: "upgrade",
                    label: qsTr("Changed"),
                    color: UI.Theme.changed
                },
                {
                    type: "removed",
                    label: qsTr("Removed"),
                    color: UI.Theme.negative
                }
            ]
            UI.ActionButton {
                required property var modelData
                text: modelData.label + " " + (modelData.type === "all" ? root.packages.length : root.packages.filter(p => p.type === modelData.type).length)
                accent: modelData.color
                primary: root.kind === modelData.type
                implicitHeight: 23 * root.fs
                font.pixelSize: 9 * root.fs
                foreground: modelData.color
                flatStyle: root.kind !== modelData.type
                onClicked: root.kind = modelData.type
            }
        }
    }
    ListView {
        id: rows
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(root.maximumHeight, Math.max(38, contentHeight))
        model: root.filtered
        clip: true
        spacing: 1
        ScrollBar.vertical: UI.ScrollBar {}
        delegate: PackageRow {
            storePathCache: root.storePathCache
            onStorePathRequested: pkg => root.storePathRequested(pkg)
            required property var modelData
            required property int index
            alternate: index % 2 !== 0
            width: rows.width - 9
            pkg: modelData
            textColor: root.textColor
            accentColor: root.accentColor
            fs: root.fs
            showPackageIcons: root.showPackageIcons
            enableGlow: root.enableGlow
            iconCache: root.iconCache
            metaCache: root.metaCache
            forceExpanded: root.viewMode === "detailed"
            onCopyRequested: text => root.copyToClipboard(text)
        }
        Text {
            anchors.centerIn: parent
            visible: rows.count === 0
            text: root.packages.length ? qsTr("No matching changes") : qsTr("No package changes")
            color: UI.Theme.muted
            font.pixelSize: 10 * root.fs
        }
    }
}
