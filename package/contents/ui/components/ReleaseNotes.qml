import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shared" as UI

// What changed upstream for one flake input: GitHub releases published since
// the locked revision, the newest commits, and a link to the full comparison.
ColumnLayout {
    id: notes
    property var entry: null
    property real fs: 1
    property color textColor: "white"
    property color accentColor: UI.Theme.highlightColor
    property bool showAllCommits: false
    property int openRelease: 0
    readonly property bool ready: !!entry && entry.status === "ok"
    readonly property var releases: ready ? entry.releases || [] : []
    readonly property var commits: ready ? entry.commits || [] : []
    signal retryRequested
    spacing: 7

    function shortDate(iso) {
        const d = new Date(iso);
        return isNaN(d.getTime()) ? "" : d.toLocaleDateString(Qt.locale(), Locale.ShortFormat);
    }

    Subheading {
        Layout.fillWidth: true
        fs: notes.fs
        text: qsTr("What's new")
        detail: !notes.ready || !notes.commits.length ? "" : notes.entry.moreCommits ? qsTr("%1+ commits").arg(notes.commits.length) : notes.commits.length === 1 ? qsTr("1 commit") : qsTr("%1 commits").arg(notes.commits.length)
        UI.ActionButton {
            objectName: "compareLink"
            visible: notes.ready && !!notes.entry.compareUrl
            text: qsTr("Full diff")
            glyph: "go-up-right"
            flatStyle: true
            implicitHeight: 22 * notes.fs
            font.pixelSize: 9 * notes.fs
            tip: qsTr("Open the full comparison upstream")
            onClicked: Qt.openUrlExternally(notes.entry.compareUrl)
        }
    }
    Text {
        visible: !!notes.entry && notes.entry.status === "loading"
        text: qsTr("Asking upstream what changed…")
        color: notes.accentColor
        font.pixelSize: 10 * notes.fs
    }
    RowLayout {
        visible: !!notes.entry && notes.entry.status === "error"
        Layout.fillWidth: true
        spacing: 8
        Text {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: notes.entry ? notes.entry.errorMsg || "" : ""
            textFormat: Text.PlainText
            color: UI.Theme.negative
            font.pixelSize: 10 * notes.fs
        }
        UI.ActionButton {
            text: qsTr("Retry")
            flatStyle: true
            implicitHeight: 22 * notes.fs
            font.pixelSize: 9 * notes.fs
            onClicked: notes.retryRequested()
        }
    }
    Text {
        visible: notes.ready && !notes.releases.length && !notes.commits.length
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: notes.entry && notes.entry.compareUrl ? qsTr("No release notes here — open the full diff to see the changes.") : qsTr("Release notes are only available for GitHub inputs.")
        color: "#91a4bd"
        font.pixelSize: 10 * notes.fs
    }

    // ── Releases ─────────────────────────────────────────────────────────────
    Repeater {
        model: notes.releases
        ColumnLayout {
            id: release
            required property var modelData
            required property int index
            readonly property bool open: notes.openRelease === index
            Layout.fillWidth: true
            spacing: 5
            RowLayout {
                Layout.fillWidth: true
                spacing: 7
                Tag {
                    text: release.modelData.tag
                    tone: release.modelData.prerelease ? UI.Theme.changed : UI.Theme.positive
                    fs: notes.fs
                }
                Text {
                    Layout.fillWidth: true
                    text: release.modelData.name && release.modelData.name !== release.modelData.tag ? release.modelData.name : ""
                    textFormat: Text.PlainText
                    color: notes.textColor
                    font.pixelSize: 10 * notes.fs
                    elide: Text.ElideRight
                }
                Text {
                    text: notes.shortDate(release.modelData.date)
                    color: "#7f8ba0"
                    font.pixelSize: 9 * notes.fs
                }
                UI.Icon {
                    source: Qt.resolvedUrl(release.open ? "../assets/ic_chevron_up.svg" : "../assets/ic_chevron_down.svg")
                    implicitWidth: 12
                    implicitHeight: 12
                    isMask: true
                    color: "#8293ab"
                }
                TapHandler {
                    onTapped: notes.openRelease = release.open ? -1 : release.index
                }
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }
            Rectangle {
                visible: release.open
                Layout.fillWidth: true
                implicitHeight: body.implicitHeight + 16
                radius: 6
                color: "#05ffffff"
                border.color: "#0affffff"
                Text {
                    id: body
                    anchors.fill: parent
                    anchors.margins: 8
                    text: (release.modelData.body || qsTr("*No description.*")) + "\n\n[" + qsTr("Open release page") + "](" + release.modelData.url + ")"
                    textFormat: Text.MarkdownText
                    wrapMode: Text.Wrap
                    color: notes.textColor
                    linkColor: notes.accentColor
                    font.pixelSize: 10 * notes.fs
                    onLinkActivated: link => Qt.openUrlExternally(link)
                    HoverHandler {
                        cursorShape: body.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }
            }
        }
    }

    // ── Commits ──────────────────────────────────────────────────────────────
    Repeater {
        model: notes.showAllCommits ? notes.commits : notes.commits.slice(0, 6)
        RowLayout {
            id: commit
            required property var modelData
            Layout.fillWidth: true
            spacing: 7
            Text {
                text: commit.modelData.sha.substring(0, 7)
                color: notes.accentColor
                font.family: UI.Theme.fixedWidthFont.family
                font.pixelSize: 9 * notes.fs
            }
            Text {
                Layout.fillWidth: true
                text: commit.modelData.message
                textFormat: Text.PlainText
                color: commitHover.hovered ? notes.textColor : "#b4c0d0"
                font.pixelSize: 10 * notes.fs
                elide: Text.ElideRight
            }
            Text {
                text: commit.modelData.author
                textFormat: Text.PlainText
                color: "#7f8ba0"
                font.pixelSize: 9 * notes.fs
                Layout.maximumWidth: 90 * notes.fs
                elide: Text.ElideRight
            }
            HoverHandler {
                id: commitHover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: Qt.openUrlExternally(commit.modelData.url)
            }
            ToolTip.visible: commitHover.hovered
            ToolTip.delay: 600
            ToolTip.text: commit.modelData.message + "\n" + commit.modelData.author + " · " + notes.shortDate(commit.modelData.date)
        }
    }
    UI.ActionButton {
        visible: notes.commits.length > 6
        text: notes.showAllCommits ? qsTr("Show fewer commits") : qsTr("Show all %1 commits").arg(notes.commits.length)
        flatStyle: true
        implicitHeight: 22 * notes.fs
        font.pixelSize: 9 * notes.fs
        onClicked: notes.showAllCommits = !notes.showAllCommits
    }
}
