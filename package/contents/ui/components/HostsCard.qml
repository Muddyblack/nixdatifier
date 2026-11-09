import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../shared" as UI

// The overview of the flake's machines: state, boot state, a pending reboot and
// the flake revision each runs against your HEAD. A row picks the machine the
// tabs look at. An offline machine keeps its last answer, greyed, with when it
// was seen.
ColumnLayout {
    id: card
    property var hosts: []        // reachable machines: { name, target, local }
    property var status: ({})     // name -> `hosts status` JSON
    property string current: ""   // "" is this machine
    property bool probing: false
    property real fs: 1
    property color textColor: UI.Theme.muted
    signal chosen(string name)
    signal refreshRequested
    spacing: 2

    function info(host) {
        return card.status[host.name] || null;
    }
    function isCurrent(host) {
        return host.local ? card.current === "" : host.name === card.current;
    }
    function stateLabel(i) {
        if (!i)
            return qsTr("checking…");
        return ({
                "online": qsTr("online"),
                "offline": qsTr("offline"),
                "unreachable": qsTr("unreachable"),
                "auth": qsTr("auth needed"),
                "unmapped": qsTr("no ssh target")
            })[i.state] || i.state;
    }
    function tone(i) {
        if (!i)
            return UI.Theme.muted;
        return i.state === "online" ? UI.Theme.positive : i.state === "auth" ? UI.Theme.changed : UI.Theme.negative;
    }
    function seen(epoch) {
        const s = Math.max(0, Math.floor(Date.now() / 1000 - epoch));
        if (s < 90)
            return qsTr("just now");
        if (s < 5400)
            return qsTr("%1 min ago").arg(Math.round(s / 60));
        if (s < 172800)
            return qsTr("%1 h ago").arg(Math.round(s / 3600));
        return qsTr("%1 days ago").arg(Math.round(s / 86400));
    }
    function details(i) {
        if (!i)
            return "";
        const parts = [];
        if (i.state === "online" || i.stale) {
            if (i.bootedGeneration)
                parts.push(qsTr("Booted #%1").arg(i.bootedGeneration) + (i.activeGeneration && i.activeGeneration !== i.bootedGeneration ? qsTr(" → next #%1").arg(i.activeGeneration) : ""));
            if (i.rebootRequired)
                parts.push(qsTr("reboot pending"));
            if (i.behind > 0)
                parts.push(i.behind === 1 ? qsTr("1 commit behind") : qsTr("%1 commits behind").arg(i.behind));
            else if (i.behind === 0)
                parts.push(qsTr("up to date with HEAD"));
            else if (i.rev)
                parts.push(qsTr("rev %1").arg(i.rev.slice(0, 7)));
        }
        if (i.stale && i.lastSeen)
            parts.push(qsTr("last seen %1").arg(card.seen(i.lastSeen)));
        else if (i.state !== "online" && i.error)
            parts.push(i.error);
        return parts.join(" · ");
    }

    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: qsTr("Hosts")
            color: card.textColor
            font.pixelSize: UI.Theme.fontPx(11, card.fs)
            font.weight: Font.DemiBold
        }
        UI.ActionButton {
            glyph: "view-refresh"
            flatStyle: true
            tip: qsTr("Ask every host again")
            enabled: !card.probing
            onClicked: card.refreshRequested()
        }
    }
    Repeater {
        model: card.hosts
        delegate: Rectangle {
            id: row
            required property var modelData
            readonly property var i: card.info(modelData)
            readonly property bool offline: !!i && i.state !== "online"
            objectName: "host-" + modelData.name
            Layout.fillWidth: true
            implicitHeight: rowContent.implicitHeight + 14
            radius: 6
            color: card.isCurrent(modelData) ? UI.Theme.wash(card.textColor, .1) : hover.hovered ? UI.Theme.wash(card.textColor, .05) : "transparent"
            opacity: offline ? (i.stale ? .75 : .6) : 1
            HoverHandler {
                id: hover
            }
            TapHandler {
                onTapped: card.chosen(row.modelData.name)
            }
            Accessible.role: Accessible.Button
            Accessible.name: row.modelData.name + ", " + card.stateLabel(row.i)
            ColumnLayout {
                id: rowContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 8
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 7
                    Rectangle {
                        implicitWidth: 8
                        implicitHeight: 8
                        radius: 4
                        color: card.tone(row.i)
                    }
                    Text {
                        text: row.modelData.name
                        color: card.textColor
                        font.pixelSize: UI.Theme.fontPx(10, card.fs)
                        font.weight: Font.Medium
                    }
                    Text {
                        visible: row.modelData.local
                        text: qsTr("this machine")
                        color: UI.Theme.muted
                        font.pixelSize: UI.Theme.fontPx(9, card.fs)
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Text {
                        text: card.stateLabel(row.i)
                        color: card.tone(row.i)
                        font.pixelSize: UI.Theme.fontPx(9, card.fs)
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: card.details(row.i)
                    color: UI.Theme.muted
                    font.pixelSize: UI.Theme.fontPx(9, card.fs)
                    elide: Text.ElideRight
                    ToolTip.text: text
                    ToolTip.visible: detailsHover.hovered && truncated
                    HoverHandler {
                        id: detailsHover
                    }
                }
            }
        }
    }
}
