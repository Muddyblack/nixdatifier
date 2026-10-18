import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "shared" as UI
import "components"

Item {
    id: root
    property bool enableGlow: true
    property var storePathCache: ({})
    signal storePathRequested(var pkg)
    property bool uiActive: true
    required property string activeViewMode
    required property color accentColor
    required property color textColor
    required property real fs
    required property bool isCheckingFlake
    required property var flakeUpdates
    required property string lastFlakeCheckTime
    required property var dryRunCache
    property var releaseNotesCache: ({})
    required property bool isDryRunning
    required property string iconStyle
    property bool isBusy: false
    property var iconCache: ({})
    property var metaCache: ({})
    property bool showPackageIcons: true
    property var openPreviews: ({})
    signal dryRunRequested(string inputName, string overrideRef)
    signal releaseNotesRequested(string inputName, bool force)
    signal updateInputRequested(string inputName)
    signal ignoreInputRequested(string inputName)
    signal resumeInputRequested(string inputName)
    property var skippedInputs: []
    property var pendingInputs: []
    property string inputList: ""
    property string inputListMode: "ignore"
    signal inputListSaved(string text)
    // Inputs that are not checked stay in the list, in name order, so nothing jumps around.
    readonly property var rows: root.flakeUpdates.concat(root.skippedInputs.map(n => ({
                input: n,
                skipped: true
            }))).sort((a, b) => a.input < b.input ? -1 : a.input > b.input ? 1 : 0)
    signal checkRequested
    signal copyToClipboard(string text)
    visible: activeViewMode === "updates"
    property string updatingInput: ""
    function togglePreview(input) {
        if (!openPreviews[input.input] && !dryRunCache[input.input] && isDryRunning)
            return;
        const next = Object.assign({}, openPreviews);
        next[input.input] = !next[input.input];
        openPreviews = next;
        if (next[input.input])
            releaseNotesRequested(input.input, false);
        if (next[input.input] && !dryRunCache[input.input])
            dryRunRequested(input.input, input.overrideRef);
    }
    UI.ScrollView {
        id: scroll
        objectName: "updatesScroll"
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: scroll.availableWidth
            spacing: 0
            RowLayout {
                objectName: "updatesHeader"
                Layout.fillWidth: true
                Layout.bottomMargin: 12
                spacing: 9
                Text {
                    text: qsTr("Flake updates")
                    color: root.textColor
                    font.pixelSize: 12 * root.fs
                    font.weight: Font.Medium
                }
                Text {
                    Layout.fillWidth: true
                    text: root.flakeUpdates.length === 1 ? qsTr("1 input") : qsTr("%1 inputs").arg(root.flakeUpdates.length)
                    color: "#8e9eb3"
                    font.pixelSize: 9 * root.fs
                    elide: Text.ElideRight
                }
                Text {
                    visible: root.lastFlakeCheckTime !== ""
                    text: root.width >= 440 * root.fs ? qsTr("Checked %1").arg(root.lastFlakeCheckTime) : root.lastFlakeCheckTime
                    color: "#7f8ba0"
                    font.pixelSize: 9 * root.fs
                    HoverHandler {
                        id: checkTimeHover
                    }
                    ToolTip.visible: checkTimeHover.hovered
                    ToolTip.text: qsTr("Last checked at %1").arg(root.lastFlakeCheckTime)
                }
                UI.ActionButton {
                    objectName: "inputListButton"
                    text: root.width >= 440 * root.fs ? qsTr("Input list") : ""
                    glyph: "document-edit"
                    tip: qsTr("Edit the list of inputs that are skipped or checked")
                    implicitHeight: 29 * root.fs
                    font.pixelSize: 10 * root.fs
                    onClicked: listPopup.opened ? listPopup.close() : listPopup.open()
                    Popup {
                        id: listPopup
                        objectName: "inputListPopup"
                        parent: root
                        width: Math.min(420, root.width - 24)
                        x: Math.round((root.width - width) / 2)
                        y: 40
                        padding: 13
                        modal: false
                        focus: true
                        closePolicy: Popup.CloseOnEscape
                        onAboutToShow: listEdit.text = root.inputList.split(/[,\s]+/).filter(n => n !== "").join("\n")
                        background: Rectangle {
                            color: "#1b2330"
                            border.color: "#29a3b9de"
                            radius: 9
                        }
                        contentItem: ColumnLayout {
                            spacing: 10
                            Text {
                                text: root.inputListMode === "only" ? qsTr("Allowlist: only these inputs are checked") : qsTr("Blocklist: these inputs are skipped")
                                color: root.textColor
                                font.pixelSize: 12 * root.fs
                                font.weight: Font.Medium
                            }
                            Text {
                                Layout.fillWidth: true
                                text: qsTr("One name per line. Globs work, e.g. nur or my-private/*. Use wrapper/input for a wrapper flake's inputs. An empty list checks everything.")
                                color: "#91a4bd"
                                wrapMode: Text.WordWrap
                                font.pixelSize: 10 * root.fs
                            }
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 150
                                TextArea {
                                    id: listEdit
                                    objectName: "inputListEdit"
                                    color: root.textColor
                                    selectByMouse: true
                                    wrapMode: TextEdit.NoWrap
                                    font.pixelSize: 11 * root.fs
                                    background: Rectangle {
                                        radius: 6
                                        color: "#04ffffff"
                                        border.color: listEdit.activeFocus ? root.accentColor : "#16ffffff"
                                    }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Item {
                                    Layout.fillWidth: true
                                }
                                UI.ActionButton {
                                    text: qsTr("Cancel")
                                    flatStyle: true
                                    onClicked: listPopup.close()
                                }
                                UI.ActionButton {
                                    objectName: "inputListSave"
                                    text: qsTr("Save")
                                    primary: true
                                    onClicked: {
                                        root.inputListSaved(listEdit.text.split(/[,\s]+/).filter(n => n !== "").join(","));
                                        listPopup.close();
                                    }
                                }
                            }
                        }
                    }
                }
                UI.ActionButton {
                    text: qsTr("Check")
                    glyph: "view-refresh"
                    implicitHeight: 29 * root.fs
                    font.pixelSize: 10 * root.fs
                    enabled: !root.isCheckingFlake && !root.isBusy
                    onClicked: root.checkRequested()
                }
            }
            Repeater {
                model: root.rows
                Item {
                    id: card
                    required property var modelData
                    readonly property bool skipped: !!modelData.skipped
                    readonly property bool pending: skipped && root.pendingInputs.indexOf(modelData.input) >= 0
                    readonly property var entry: root.dryRunCache[modelData.input] || null
                    readonly property bool opened: !skipped && !!root.openPreviews[modelData.input]
                    readonly property bool updating: root.updatingInput === modelData.input
                    Layout.fillWidth: true
                    Layout.bottomMargin: 9
                    implicitHeight: skipped ? skippedSurface.implicitHeight : detailWindow.visible ? 58 : contents.implicitHeight + 20
                    Rectangle {
                        id: skippedSurface
                        objectName: "skipped-" + card.modelData.input
                        visible: card.skipped
                        width: card.width
                        implicitHeight: 47
                        radius: 9
                        color: "#02ffffff"
                        border.color: "#08ffffff"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8
                            Text {
                                Layout.fillWidth: true
                                text: card.modelData.input
                                color: "#91a4bd"
                                opacity: card.pending ? 1 : 0.55
                                font.pixelSize: 11 * root.fs
                                font.strikeout: !card.pending
                                elide: Text.ElideRight
                            }
                            Text {
                                id: skippedState
                                text: card.pending ? qsTr("checking…") : qsTr("not checked")
                                color: card.pending ? root.accentColor : "#91a4bd"
                                opacity: 0.55
                                font.pixelSize: 9 * root.fs
                                // Pulses only while pending, and the engine clears pending on any outcome or after 60 s.
                                SequentialAnimation on opacity {
                                    running: card.pending && root.uiActive
                                    loops: Animation.Infinite
                                    onRunningChanged: if (!running)
                                        skippedState.opacity = 0.55
                                    NumberAnimation {
                                        to: 1
                                        duration: 600
                                    }
                                    NumberAnimation {
                                        to: 0.35
                                        duration: 600
                                    }
                                }
                            }
                            UI.ActionButton {
                                objectName: "resume-" + card.modelData.input
                                visible: !card.pending
                                glyph: "view-visible"
                                implicitHeight: 27
                                tip: qsTr("Check %1 again").arg(card.modelData.input)
                                onClicked: root.resumeInputRequested(card.modelData.input)
                            }
                        }
                    }
                    UI.DetailWindow {
                        id: detailWindow
                        objectName: "updateWindow-" + card.modelData.input
                        title: qsTr("Update: %1 — Nixdatifier").arg(card.modelData.input)
                        detailItem: cardSurface
                    }
                    Rectangle {
                        id: cardSurface
                        visible: !card.skipped
                        width: card.width
                        implicitHeight: contents.implicitHeight + 20
                        height: implicitHeight
                        radius: 9
                        color: "#03ffffff"
                        border.color: "#0effffff"
                        ColumnLayout {
                            id: contents
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 0
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Item {
                                    Layout.fillWidth: true
                                    // Grow with the text (the date line, larger fonts) so nothing spills out of the card.
                                    implicitHeight: Math.max(38, cardInfo.implicitHeight)
                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 10
                                        Rectangle {
                                            implicitWidth: 31
                                            implicitHeight: 31
                                            radius: 8
                                            color: "#04ffffff"
                                            border.color: "#0effffff"
                                            UI.Icon {
                                                anchors.centerIn: parent
                                                source: Qt.resolvedUrl(card.modelData.input.indexOf("home") >= 0 ? "assets/ic_folder.svg" : "assets/ic_outline_box.svg")
                                                width: 17
                                                height: 17
                                                isMask: true
                                                color: "#93a5be"
                                            }
                                        }
                                        ColumnLayout {
                                            id: cardInfo
                                            Layout.fillWidth: true
                                            spacing: 4
                                            Text {
                                                Layout.fillWidth: true
                                                text: card.modelData.input
                                                color: root.textColor
                                                font.pixelSize: 11 * root.fs
                                                font.weight: Font.Medium
                                                elide: Text.ElideRight
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 5
                                                visible: !card.updating
                                                Text {
                                                    Layout.maximumWidth: 70 * root.fs
                                                    text: card.modelData.oldRev
                                                    color: "#8293ab"
                                                    font.family: UI.Theme.fixedWidthFont.family
                                                    font.pixelSize: 9 * root.fs
                                                    elide: Text.ElideRight
                                                }
                                                Text {
                                                    text: "→"
                                                    color: "#8293ab"
                                                    font.pixelSize: 10 * root.fs
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: card.modelData.newRev
                                                    color: root.accentColor
                                                    font.family: UI.Theme.fixedWidthFont.family
                                                    font.pixelSize: 9 * root.fs
                                                    elide: Text.ElideRight
                                                }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 5
                                                visible: !card.updating && (card.modelData.oldDate !== "" || card.modelData.newDateTs > 0)
                                                UI.Icon {
                                                    source: Qt.resolvedUrl("assets/ic_calendar.svg")
                                                    implicitWidth: 10 * root.fs
                                                    implicitHeight: 10 * root.fs
                                                    isMask: true
                                                    color: "#62738b"
                                                }
                                                Text {
                                                    visible: card.modelData.oldDate !== ""
                                                    text: card.modelData.oldDate
                                                    color: "#62738b"
                                                    font.pixelSize: 9 * root.fs
                                                }
                                                Text {
                                                    visible: card.modelData.oldDate !== ""
                                                    text: "→"
                                                    color: "#62738b"
                                                    font.pixelSize: 9 * root.fs
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: card.modelData.newDate
                                                    color: root.accentColor
                                                    opacity: 0.75
                                                    font.pixelSize: 9 * root.fs
                                                    elide: Text.ElideRight
                                                }
                                            }
                                            Text {
                                                visible: card.updating
                                                text: qsTr("Updating input…")
                                                color: UI.Theme.positive
                                                font.pixelSize: 9 * root.fs
                                            }
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: !!card.modelData.overrideRef
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.togglePreview(card.modelData)
                                    }
                                }
                                RowLayout {
                                    spacing: 5
                                    UI.ActionButton {
                                        objectName: "openUpdate-" + card.modelData.input
                                        visible: !detailWindow.visible
                                        glyph: "view-fullscreen"
                                        implicitHeight: 27
                                        tip: qsTr("Open in larger window")
                                        onClicked: {
                                            if (!card.opened && card.modelData.overrideRef)
                                                root.togglePreview(card.modelData);
                                            detailWindow.open();
                                        }
                                    }
                                    UI.ActionButton {
                                        objectName: "preview-" + card.modelData.input
                                        glyph: Qt.resolvedUrl(card.opened ? "assets/ic_chevron_up.svg" : "assets/ic_outline_compare.svg")
                                        implicitHeight: 27
                                        primary: true
                                        accent: "#b6a1e4"
                                        tip: card.opened ? qsTr("Collapse preview") : card.entry ? qsTr("Show cached preview") : qsTr("Preview package changes")
                                        enabled: !!card.modelData.overrideRef && (card.opened || !!card.entry || !root.isDryRunning)
                                        onClicked: root.togglePreview(card.modelData)
                                    }
                                    UI.ActionButton {
                                        objectName: "update-" + card.modelData.input
                                        glyph: "view-refresh"
                                        implicitHeight: 27
                                        tip: qsTr("Update only %1").arg(card.modelData.input)
                                        accent: UI.Theme.positive
                                        primary: true
                                        enabled: !root.isBusy
                                        onClicked: root.updateInputRequested(card.modelData.input)
                                    }
                                    UI.ActionButton {
                                        objectName: "ignore-" + card.modelData.input
                                        visible: root.canIgnoreInputs
                                        glyph: "view-hidden"
                                        implicitHeight: 27
                                        tip: qsTr("Stop checking %1").arg(card.modelData.input)
                                        onClicked: root.ignoreInputRequested(card.modelData.input)
                                    }
                                    UI.ActionButton {
                                        objectName: "source-" + card.modelData.input
                                        glyph: "go-up-right"
                                        implicitHeight: 27
                                        tip: qsTr("Open source repository")
                                        enabled: /^https?:\/\//i.test(card.modelData.url || "")
                                        onClicked: Qt.openUrlExternally(card.modelData.url)
                                    }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: visible ? 10 : 0
                                visible: card.opened
                                spacing: 10
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 1
                                    color: "#08ffffff"
                                }
                                ReleaseNotes {
                                    objectName: "notes-" + card.modelData.input
                                    Layout.fillWidth: true
                                    entry: root.releaseNotesCache[card.modelData.input] || null
                                    fs: root.fs
                                    textColor: root.textColor
                                    accentColor: root.accentColor
                                    onRetryRequested: root.releaseNotesRequested(card.modelData.input, true)
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 1
                                    color: "#08ffffff"
                                }
                                Text {
                                    visible: !!card.entry && card.entry.status === "loading"
                                    text: qsTr("Evaluating package changes…")
                                    color: root.accentColor
                                    font.pixelSize: 10 * root.fs
                                }
                                UI.ActionButton {
                                    visible: !card.entry
                                    text: qsTr("Preview changes")
                                    enabled: !root.isDryRunning
                                    onClicked: root.dryRunRequested(card.modelData.input, card.modelData.overrideRef)
                                }
                                Text {
                                    visible: !!card.entry && card.entry.status === "error"
                                    Layout.fillWidth: true
                                    wrapMode: Text.WrapAnywhere
                                    text: card.entry ? card.entry.errorMsg || "" : ""
                                    color: UI.Theme.negative
                                    font.pixelSize: 10 * root.fs
                                }
                                UI.ActionButton {
                                    visible: !!card.entry && card.entry.status === "error"
                                    text: qsTr("Retry preview")
                                    enabled: !root.isDryRunning
                                    onClicked: root.dryRunRequested(card.modelData.input, card.modelData.overrideRef)
                                }
                                PackageList {
                                    storePathCache: root.storePathCache
                                    onStorePathRequested: pkg => root.storePathRequested(pkg)
                                    visible: !!card.entry && card.entry.status === "ok"
                                    Layout.fillWidth: true
                                    packages: card.entry ? card.entry.packages || [] : []
                                    iconCache: root.iconCache
                                    metaCache: root.metaCache
                                    fs: root.fs
                                    textColor: root.textColor
                                    accentColor: root.accentColor
                                    showPackageIcons: root.showPackageIcons
                                    enableGlow: root.enableGlow
                                    onCopyToClipboard: text => root.copyToClipboard(text)
                                }
                                UI.ActionButton {
                                    text: qsTr("Collapse preview")
                                    flatStyle: true
                                    onClicked: root.togglePreview(card.modelData)
                                }
                            }
                        }
                    }
                }
            }
            Text {
                visible: !root.flakeUpdates.length
                Layout.fillWidth: true
                Layout.topMargin: 25
                Layout.bottomMargin: 25
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: root.isCheckingFlake ? qsTr("Checking upstream inputs…") : root.lastFlakeCheckTime ? qsTr("No pending input updates.") : qsTr("Configure a flake directory or check for updates.")
                color: "#91a4bd"
                font.pixelSize: 11 * root.fs
            }
        }
    }
}
