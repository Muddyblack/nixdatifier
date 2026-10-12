import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "shared" as UI

Item {
    id: timelineTab
    property var storePathCache: ({})
    property var generationCounts: ({})
    signal generationCountsRequested(int genNum)
    signal storePathRequested(var pkg)

    // ── Required properties ───────────────────────────────────────────────────
    // See FullView.uiActive — false while the popup is closed.
    property bool uiActive: true
    property bool enableGlow: true
    property bool enableMotion: true
    property date referenceDate: new Date()
    property var railSegments: []
    Timer {
        interval: 60000
        repeat: true
        running: timelineTab.uiActive && timelineTab.visible
        onTriggered: timelineTab.referenceDate = new Date()
    }
    property bool enableLiveSwitch: true
    property string diffViewMode: "compact"
    required property color accentColor
    required property color timelineColor
    required property color textColor
    required property real fs
    required property bool isLoadingGens
    required property bool isLoadingDetails
    required property bool isBusy
    required property var generations
    required property int selectedGenNum
    required property int bootedGenNum
    required property int activeGenNum
    required property var detailsCache
    required property string diffMode
    required property bool showDeleteButton
    required property bool diffFilterEnabled
    required property var iconCache
    required property var metaCache
    required property bool showPackageIcons
    required property string iconStyle
    required property var configDiffCache
    required property string activeViewMode

    function fpx(n) {
        return UI.Theme.fontPx(n, fs);
    }

    signal selectGen(int genNum)
    signal collapseGen
    signal requestAction(int genNum, string action)
    signal diffModeToggle(int genNum)
    signal copyToClipboard(string text)
    signal compareWithRequested(int genA, int genB)
    signal refreshRequested
    signal configureRequested

    visible: activeViewMode === "timeline"
    focus: visible
    activeFocusOnTab: true

    // Live free-text filter. Matches against gen number, timestamp, the cached
    // nixos version, the kernel string, and any package name in the diff.
    property string searchText: ""

    // Keyboard navigation. Up/Down moves selection through the filtered list,
    // Enter toggles expand, Delete requests removal, `/` focuses search, Esc clears.
    function moveSelection(delta) {
        const list = timelineTab.filteredGenerations;
        if (list.length === 0)
            return;
        let idx = list.findIndex(g => g.number === timelineTab.selectedGenNum);
        if (idx < 0)
            idx = delta > 0 ? -1 : list.length;
        const next = Math.max(0, Math.min(list.length - 1, idx + delta));
        timelineTab.selectGen(list[next].number);
        genListView.positionViewAtIndex(next, ListView.Contain);
    }
    Keys.onPressed: event => {
        if (timelineSearch.activeFocus)
            return;
        if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
            timelineTab.moveSelection(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
            timelineTab.moveSelection(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Home) {
            if (timelineTab.filteredGenerations.length > 0) {
                timelineTab.selectGen(timelineTab.filteredGenerations[0].number);
                genListView.positionViewAtBeginning();
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            const list = timelineTab.filteredGenerations;
            if (list.length > 0) {
                timelineTab.selectGen(list[list.length - 1].number);
                genListView.positionViewAtEnd();
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (timelineTab.selectedGenNum > 0) {
                // Toggle by re-selecting (handler in main collapses if same).
                timelineTab.collapseGen();
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Delete && timelineTab.selectedGenNum > 0 && timelineTab.showDeleteButton) {
            timelineTab.requestAction(timelineTab.selectedGenNum, "delete");
            event.accepted = true;
        } else if (event.key === Qt.Key_Slash) {
            timelineSearch.forceActiveFocus();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            timelineSearch.text = "";
            event.accepted = true;
        }
    }

    function genMatches(g) {
        const q = timelineTab.searchText.trim().toLowerCase();
        if (!q)
            return true;
        if (("#" + g.number).indexOf(q) !== -1)
            return true;
        if ((g.timestamp || "").toLowerCase().indexOf(q) !== -1)
            return true;
        const d = timelineTab.detailsCache[g.number];
        if (d) {
            if ((d.nixosVer || "").toLowerCase().indexOf(q) !== -1)
                return true;
            if ((d.kernelVer || "").toLowerCase().indexOf(q) !== -1)
                return true;
            if (d.diff) {
                for (let i = 0; i < d.diff.length; i++) {
                    if ((d.diff[i].name || "").toLowerCase().indexOf(q) !== -1)
                        return true;
                }
            }
        }
        return false;
    }

    readonly property var filteredGenerations: {
        if (!timelineTab.searchText.trim())
            return timelineTab.generations;
        return timelineTab.generations.filter(timelineTab.genMatches);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        // Search bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 31 * timelineTab.fs
            radius: 5
            color: Qt.rgba(1, 1, 1, 0.025)
            border.color: timelineSearch.activeFocus ? Qt.rgba(timelineTab.accentColor.r, timelineTab.accentColor.g, timelineTab.accentColor.b, 0.55) : Qt.rgba(1, 1, 1, 0.10)
            border.width: 1
            Behavior on border.color {
                ColorAnimation {
                    duration: 110
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 6
                spacing: 6

                UI.Icon {
                    source: Qt.resolvedUrl("assets/ic_search.svg")
                    implicitWidth: 12
                    implicitHeight: 12
                    color: UI.Theme.muted
                    isMask: true
                }
                TextInput {
                    id: timelineSearch
                    objectName: "generationSearch"
                    Layout.fillWidth: true
                    font.pixelSize: timelineTab.fpx(9)
                    color: timelineTab.textColor
                    clip: true
                    onTextChanged: timelineTab.searchText = text
                    KeyNavigation.priority: KeyNavigation.BeforeItem
                    Keys.onEscapePressed: text = ""

                    Text {
                        anchors.fill: parent
                        visible: timelineSearch.text === ""
                        text: qsTr("Search generations, packages, dates…")
                        color: timelineTab.textColor
                        opacity: 0.30
                        font.pixelSize: timelineTab.fpx(9)
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                // Result count
                Text {
                    visible: timelineSearch.text !== ""
                    text: qsTr("%1 / %2").arg(timelineTab.filteredGenerations.length).arg(timelineTab.generations.length)
                    color: timelineTab.textColor
                    opacity: 0.45
                    font.pixelSize: timelineTab.fpx(8)
                    font.family: UI.Theme.fixedWidthFont.family
                }
                // Clear button
                Text {
                    visible: timelineSearch.text !== ""
                    text: "×"
                    color: timelineTab.textColor
                    opacity: clearMa.containsMouse ? 0.85 : 0.55
                    font.pixelSize: timelineTab.fpx(12)
                    font.bold: true
                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: timelineSearch.text = ""
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.bottomMargin: 10
            Text {
                Layout.fillWidth: true
                text: qsTr("SYSTEM HISTORY")
                color: "#8491a4"
                font.pixelSize: 9 * timelineTab.fs
                font.letterSpacing: 1
            }
            Text {
                objectName: "generationCount"
                text: qsTr("%1 generations").arg(timelineTab.generations.length)
                color: "#7f8ba0"
                font.pixelSize: 10 * timelineTab.fs
            }
        }

        ListView {
            id: genListView
            objectName: "generationList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: timelineTab.filteredGenerations
            clip: true
            spacing: 0
            onContentYChanged: timelineTab.updateTravel()
            onContentHeightChanged: Qt.callLater(timelineTab.updateTravel)
            onWidthChanged: Qt.callLater(timelineTab.updateTravel)
            onHeightChanged: Qt.callLater(timelineTab.updateTravel)
            onModelChanged: Qt.callLater(timelineTab.updateTravel)
            onCountChanged: Qt.callLater(timelineTab.updateTravel)
            ScrollBar.vertical: UI.ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            delegate: GenerationDelegate {
                referenceDate: timelineTab.referenceDate
                changeCounts: timelineTab.generationCounts[modelData.number] || null
                storePathCache: timelineTab.storePathCache
                onStorePathRequested: pkg => timelineTab.storePathRequested(pkg)
                enableLiveSwitch: timelineTab.enableLiveSwitch
                enableGlow: timelineTab.enableGlow
                enableMotion: timelineTab.enableMotion
                diffViewMode: timelineTab.diffViewMode
                onGeometryChanged: Qt.callLater(timelineTab.updateTravel)
                Component.onCompleted: Qt.callLater(timelineTab.updateTravel)
                Component.onDestruction: Qt.callLater(timelineTab.updateTravel)
                uiActive: timelineTab.uiActive
                width: genListView.width
                gen: modelData
                accentColor: timelineTab.accentColor
                timelineColor: timelineTab.timelineColor
                textColor: timelineTab.textColor
                fs: timelineTab.fs
                selectedGenNum: timelineTab.selectedGenNum
                isLoadingDetails: timelineTab.isLoadingDetails
                isBusy: timelineTab.isBusy
                detailsCache: timelineTab.detailsCache
                diffMode: timelineTab.diffMode
                showDeleteButton: timelineTab.showDeleteButton
                diffFilterEnabled: timelineTab.diffFilterEnabled
                bootedGenNum: timelineTab.bootedGenNum
                iconCache: timelineTab.iconCache
                metaCache: timelineTab.metaCache
                showPackageIcons: timelineTab.showPackageIcons
                iconStyle: timelineTab.iconStyle
                allGenerations: timelineTab.generations
                configDiffCache: timelineTab.configDiffCache

                onSelectGen: n => timelineTab.selectGen(n)
                onCollapseGen: () => timelineTab.collapseGen()
                onRequestAction: (n, a) => timelineTab.requestAction(n, a)
                onDiffModeToggle: n => timelineTab.diffModeToggle(n)
                onCopyToClipboard: t => timelineTab.copyToClipboard(t)
                onCompareWithRequested: (a, b) => timelineTab.compareWithRequested(a, b)
            }
        }
    }

    property point travelStart: Qt.point(0, 0)
    property point travelEnd: Qt.point(0, 0)
    property bool travelAvailable: false
    property real travelProgress: 0
    readonly property color travelColor: {
        const start = UI.Theme.positive, end = UI.Theme.changed;
        const p = Math.max(0, Math.min(1, travelProgress));
        return Qt.rgba(start.r + (end.r - start.r) * p, start.g + (end.g - start.g) * p, start.b + (end.b - start.b) * p, 1);
    }
    onUiActiveChanged: {
        referenceDate = new Date();
        Qt.callLater(updateTravel);
    }
    onVisibleChanged: {
        referenceDate = new Date();
        Qt.callLater(updateTravel);
    }
    onTimelineColorChanged: Qt.callLater(updateTravel)
    onActiveGenNumChanged: Qt.callLater(updateTravel)
    onBootedGenNumChanged: Qt.callLater(updateTravel)
    function updateTravel() {
        // Use actual delegate positions, including expanded cards and filtered lists.
        const nodes = [];
        for (let i = 0; i < genListView.count; ++i) {
            const row = genListView.itemAtIndex(i) as GenerationDelegate;
            if (!row)
                continue;
            const point = row.mapToItem(genListView, row.nodeX, row.nodeY);
            nodes.push({
                x: point.x,
                y: point.y,
                color: row.statusColor,
                top: point.y - row.nodeY,
                bottom: point.y - row.nodeY + row.height
            });
            if (uiActive && visible && point.y - row.nodeY < genListView.height && point.y - row.nodeY + row.height > 0)
                generationCountsRequested(row.gen.number);
        }
        const segments = [];
        if (nodes.length) {
            const first = nodes[0], last = nodes[nodes.length - 1];
            segments.push({
                x: first.x,
                y: first.top,
                endY: first.y,
                startColor: UI.Theme.wash(first.color, .18),
                endColor: UI.Theme.wash(first.color, .7)
            });
            for (let i = 1; i < nodes.length; ++i) {
                const a = nodes[i - 1], b = nodes[i];
                segments.push({
                    x: a.x,
                    y: a.y,
                    endY: b.y,
                    startColor: UI.Theme.wash(a.color, .7),
                    endColor: UI.Theme.wash(b.color, .7)
                });
            }
            segments.push({
                x: last.x,
                y: last.y,
                endY: last.bottom,
                startColor: UI.Theme.wash(last.color, .7),
                endColor: UI.Theme.wash(last.color, 0)
            });
        }
        railSegments = segments;
        let boot = -1, next = -1;
        for (let i = 0; i < filteredGenerations.length; ++i) {
            if (filteredGenerations[i].number === bootedGenNum)
                boot = i;
            if (filteredGenerations[i].number === activeGenNum)
                next = i;
        }
        const a = boot >= 0 ? (genListView.itemAtIndex(boot) as GenerationDelegate) : null;
        const b = next >= 0 ? (genListView.itemAtIndex(next) as GenerationDelegate) : null;
        if (!a || !b || boot === next) {
            travelAvailable = false;
            return;
        }
        const pa = a.mapToItem(genListView, a.nodeX, a.nodeY);
        const pb = b.mapToItem(genListView, b.nodeX, b.nodeY);
        travelStart = pa;
        travelEnd = pb;
        // Keep traveling through the clipped edge when one endpoint is offscreen.
        // Assign once so scrolling/resizing doesn't restart the animation each frame.
        travelAvailable = Math.max(pa.y, pb.y) >= 0 && Math.min(pa.y, pb.y) <= genListView.height;
    }
    Item {
        parent: genListView
        anchors.fill: parent
        z: -1
        Repeater {
            model: timelineTab.railSegments
            Rectangle {
                required property var modelData
                x: modelData.x - 1
                y: modelData.y
                width: 2
                height: Math.max(0, modelData.endY - modelData.y)
                gradient: Gradient {
                    id: segmentGradient
                    GradientStop {
                        position: 0
                        color: modelData.startColor
                    }
                    GradientStop {
                        position: 1
                        color: modelData.endColor
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 6
                    height: parent.height
                    gradient: segmentGradient
                    opacity: .08
                    visible: timelineTab.enableGlow
                }
            }
        }
    }
    Rectangle {
        objectName: "travelingMarker"
        parent: genListView
        z: 5
        visible: timelineTab.travelAvailable && timelineTab.uiActive && timelineTab.visible
        x: timelineTab.travelStart.x - 4
        y: timelineTab.travelStart.y + (timelineTab.travelEnd.y - timelineTab.travelStart.y) * timelineTab.travelProgress - 4
        width: 8
        height: 8
        radius: 4
        color: timelineTab.travelColor
        Rectangle {
            anchors.centerIn: parent
            visible: timelineTab.enableGlow
            width: 20
            height: 20
            radius: 10
            color: UI.Theme.wash(timelineTab.travelColor, .08)
            border.color: UI.Theme.wash(timelineTab.travelColor, .6)
        }
        Rectangle {
            anchors.centerIn: parent
            visible: timelineTab.enableGlow
            width: 28
            height: 28
            radius: 14
            color: UI.Theme.wash(timelineTab.travelColor, .035)
        }
    }
    SequentialAnimation on travelProgress {
        running: timelineTab.uiActive && timelineTab.visible && timelineTab.enableMotion && timelineTab.travelAvailable
        loops: Animation.Infinite
        NumberAnimation {
            from: 0
            to: 1
            duration: 1400
            easing.type: Easing.InOutSine
        }
        PauseAnimation {
            duration: 300
        }
        NumberAnimation {
            from: 1
            to: 0
            duration: 1400
            easing.type: Easing.InOutSine
        }
        PauseAnimation {
            duration: 600
        }
        onRunningChanged: if (!running)
            timelineTab.travelProgress = 0
    }

    // Loading spinner
    UI.Flake {
        anchors.centerIn: parent
        visible: timelineTab.isLoadingGens && timelineTab.generations.length === 0
        width: 64
        height: 64
        working: visible && timelineTab.uiActive
        motion: timelineTab.enableMotion
        style: timelineTab.iconStyle
        accent: timelineTab.accentColor
    }

    Rectangle {
        objectName: "emptyTimelineRail"
        parent: genListView
        x: 13
        y: 10
        width: 2
        height: Math.min(parent.height - y, Math.max(64, emptyState.implicitHeight + 16))
        visible: emptyState.visible
        gradient: Gradient {
            GradientStop {
                position: 0
                color: UI.Theme.wash(UI.Theme.changed, .6)
            }
            GradientStop {
                position: .3
                color: UI.Theme.wash(UI.Theme.positive, .45)
            }
            GradientStop {
                position: 1
                color: UI.Theme.wash(timelineTab.timelineColor, .18)
            }
        }
    }

    // Keep the rail present even when a search has no matching generations.
    Column {
        id: emptyState
        parent: genListView
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 30
        spacing: 8
        width: Math.max(0, parent.width - 58)
        readonly property bool noGenerations: timelineTab.generations.length === 0 && !timelineTab.isLoadingGens
        readonly property bool noMatches: timelineTab.generations.length > 0 && timelineTab.filteredGenerations.length === 0 && timelineTab.searchText.trim() !== ""
        visible: noGenerations || noMatches
        Text {
            width: parent.width
            text: emptyState.noMatches ? qsTr("No matching generations.") : qsTr("No generations found.")
            color: "#91a4bd"
            font.pixelSize: 11 * timelineTab.fs
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
        Text {
            width: parent.width
            text: emptyState.noMatches ? qsTr("Try a generation number, package, or date.") : qsTr("Refresh your system history or check the flake configuration.")
            color: "#91a4bd"
            font.pixelSize: 10 * timelineTab.fs
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
        RowLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            UI.ActionButton {
                visible: emptyState.noMatches
                objectName: "clearGenerationSearch"
                text: qsTr("Clear search")
                flatStyle: true
                font.pixelSize: 9 * timelineTab.fs
                onClicked: timelineSearch.text = ""
            }
            UI.ActionButton {
                visible: !emptyState.noMatches
                text: qsTr("Refresh")
                onClicked: timelineTab.refreshRequested()
            }
            UI.ActionButton {
                visible: !emptyState.noMatches
                text: qsTr("Configure…")
                onClicked: timelineTab.configureRequested()
            }
        }
    }
}
