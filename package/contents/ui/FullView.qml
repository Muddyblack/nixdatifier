import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import "shared" as UI
import "components"

Pane {
    id: fullView
    property var storePathCache: ({})
    property var generationCounts: ({})
    signal generationCountsRequested(int genNum)
    signal storePathRequested(var pkg)
    padding: 0
    background: null
    palette.window: fullView.showBg ? fullView.bgColor : UI.Theme.systemBackgroundColor
    palette.windowText: textColor
    palette.base: "#1c2533"
    palette.alternateBase: "#242f40"
    palette.text: textColor
    palette.button: "#242f40"
    palette.buttonText: textColor
    palette.highlight: accentColor
    palette.highlightedText: "#131923"
    palette.placeholderText: "#9aaac0"

    function svg(name) {
        return Qt.resolvedUrl("assets/" + name + ".svg");
    }

    // Keep the shared layout consistent while honoring the user's font scale.
    function fpx(n) {
        return UI.Theme.fontPx(n, fs);
    }

    // ── Required properties ───────────────────────────────────────────────────
    // False while the popup is closed. Looping animations gate on it so a
    // hidden popup costs nothing; defaults to true so the view still animates
    // if it is ever hosted somewhere that does not thread the flag down.
    property bool uiActive: true
    required property color accentColor
    required property color timelineColor
    required property color textColor
    required property real fs
    required property bool showBg
    required property var bgColor
    required property real bgRadius
    required property bool isBusy
    required property bool isLoadingGens
    required property bool isLoadingDetails
    required property bool isCheckingFlake
    required property var generations
    required property var flakeUpdates
    required property var toasts
    required property string lastFlakeCheckTime
    required property int activeGenNum
    required property int bootedGenNum
    property bool runningTestBuild: false
    required property int selectedGenNum
    required property var detailsCache
    required property string diffMode
    required property bool showDeleteButton
    required property bool diffFilterEnabled
    required property bool showFlakeSection
    required property bool showCommandButtons
    required property var customCommands
    property string gcCustomCommand: ""
    required property string activeViewMode   // "timeline" | "updates" | "diff" | "tools" | "secrets" | "hash" | "history" | "storeusage" | "impermanence"
    required property var deployedSecrets  // { path, exists, lastModified, age }
    required property var sourceSecrets    // { path, exists, lastModified, kind }
    required property string hostname
    required property string userFacePath
    required property string nixosVersion
    required property string lastActivationTime
    required property string uptime
    required property string iconStyle
    required property bool isNixOS
    required property real diskStoreBytes
    required property real diskReclaimableBytes
    required property real diskFreeBytes

    readonly property string storeLabel: UI.Theme.formatBytes(diskStoreBytes) || "—"
    readonly property string reclaimableLabel: diskReclaimableBytes < 0 ? "—" : diskReclaimableBytes === 0 ? "0 B" : UI.Theme.formatBytes(diskReclaimableBytes)

    // Invoked from a timeline card's right-click "Compare with…" menu.
    // Switches to the Diff tab, pre-populates A and B, and triggers the diff fetch.
    function openCompareInDiffTab(genA, genB) {
        diffTab.selectPair(genA, genB);
        fullView.viewModeChanged("diff");
        fullView.compareRequested(genA, genB);
    }

    // Pending action for inline confirm bar
    property int pendingGenNum: -1
    property string pendingAction: ""
    property string pendingCleanup: ""

    // Pairwise diff state for the Diff tab
    property var pairDiffCache: ({})
    property bool isLoadingPairDiff: false
    property var configDiffCache: ({})
    property var dryRunCache: ({})
    property var releaseNotesCache: ({})
    property bool isDryRunning: false
    property bool isProbingHash: false
    property string diffViewMode: "compact"   // "compact" | "detailed"
    property var iconCache: ({})
    property var metaCache: ({})
    property bool showPackageIcons: true

    // hash result pushed back from main: { value: string, isError: bool }
    // empty string = no result yet / cleared
    property var hashResult: null

    // ── Rebuild history state ────────────────────────────────────────────────
    property var actionHistory: []
    property bool isLoadingHistory: false

    // ── Store usage tool state ───────────────────────────────────────────────
    property var storeUsageResult: null
    property bool isProbingStoreUsage: false

    // ── Development environment tool state ───────────────────────────────────
    property var devEnvResult: null
    property var devEnvProjects: []
    property string systemFlakePath: ""
    property bool isProbingDevEnv: false
    property var shellPackages: ({})
    property var devSpace: []
    property bool isMeasuringSpace: false

    // ── Persistent folders (impermanence) tab state ─────────────────────────
    property var impermanence: ({
            detected: false,
            volatile: false,
            volatileWhy: "",
            rootFs: "",
            areas: [],
            entries: []
        })
    property var impermanenceListing: null
    property var impermanenceScan: null
    property var impermanenceCleanup: null
    property bool isListingImpermanence: false
    property bool isScanningImpermanence: false
    property bool isAnalyzingImpermanence: false
    property bool isRemovingImpermanence: false
    property int impermanenceStaleDays: 180

    // ── System health tool state ─────────────────────────────────────────────
    property var healthResult: null
    property bool isProbingHealth: false

    signal viewModeChanged(string mode)
    signal refreshRequested
    signal checkFlakeRequested
    signal selectGen(int genNum)
    signal collapseGen
    signal requestAction(int genNum, string action)
    signal diffModeToggle(int genNum)
    signal runCommand(string cmd, string label)
    signal copyToClipboard(string text)
    signal dismissToast(int index)
    signal hashRequested(string mode, string input)
    signal clearHistoryRequested
    signal storeUsageRequested(string path)
    signal impermanenceListRequested(string path, bool force)
    signal impermanenceScanRequested(bool force)
    signal impermanenceAnalyzeRequested(bool force)
    signal impermanenceRemoveRequested(string path, string name)
    signal impermanenceOpenRequested(string path)
    signal clamScanRequested
    signal devEnvRequested(string path)
    signal devEnvDiscoverRequested
    signal devEnvActionRequested(string kind, string dir)
    signal shellPackagesRequested(string dir, string name)
    signal measureSpaceRequested
    signal clearCacheRequested(string dir)
    signal healthRequested(bool force)
    signal confirmPending
    signal cancelPending
    signal cleanupVariantPicked(string mode)
    signal confirmCleanup(string mode)
    signal cancelCleanup
    signal compareRequested(int genA, int genB)
    signal dryRunRequested(string inputName, string overrideRef)
    signal releaseNotesRequested(string inputName, bool force)
    signal updateInputRequested(string inputName)
    signal popOutRequested
    signal configureRequested

    property bool commandsOpen: false
    function openCommands() {
        commandsOpen = true;
        commandsView.focusBack();
    }
    function closeCommands() {
        commandsOpen = false;
        commandsButton.forceActiveFocus(Qt.OtherFocusReason);
    }
    onUiActiveChanged: if (!uiActive)
        commandsOpen = false

    property bool isPopOutOpen: false
    property string updatingInput: ""
    property bool isSpinning: false
    property string busyLabel: ""
    property bool enableGlow: true
    property bool enableMotion: true
    property bool enableLiveSwitch: true
    readonly property var tools: [
        {
            key: "health",
            label: qsTr("System health"),
            hint: fullView.isNixOS ? qsTr("Reboots, /boot space, caches and failed units.") : qsTr("Nix, profiles, caches and failed units."),
            glyph: "ic_check"
        },
        {
            key: "devenv",
            label: qsTr("Dev environments"),
            hint: qsTr("direnv, flakes and shells of any project folder."),
            glyph: "ic_folder"
        },
        {
            key: "secrets",
            label: qsTr("Secrets"),
            hint: qsTr("Inspect deployed and source secrets."),
            glyph: "ic_secrets"
        },
        {
            key: "hash",
            label: qsTr("Hash calculator"),
            hint: qsTr("Hashes for URLs, files, and store paths."),
            glyph: "ic_hash"
        },
        {
            key: "history",
            label: qsTr("Rebuild history"),
            hint: qsTr("Review past rebuild and update output."),
            glyph: "ic_history"
        },
        {
            key: "storeusage",
            label: qsTr("Store usage"),
            hint: qsTr("See why a store path can't be collected."),
            glyph: "ic_search"
        }
    ].filter(tool => fullView.isNixOS || tool.key !== "secrets")
    readonly property var activeTool: tools.find(t => t.key === activeViewMode) || null
    readonly property bool inTools: activeViewMode === "tools" || activeTool !== null
    readonly property bool toolsOverlayOpen: inTools && activeViewMode !== "tools"

    readonly property real contentMargin: width < 440 ? 16 : 21
    readonly property string releaseLabel: {
        if (!fullView.isNixOS)
            return fullView.nixosVersion ? "Nix " + fullView.nixosVersion : "Nix";
        const match = nixosVersion.match(/^\d{2}\.\d{2}/);
        return nixosVersion ? "NixOS " + (match ? match[0] : nixosVersion) : "NixOS";
    }
    function shortActivation() {
        const m = lastActivationTime.match(/(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})/);
        return m ? Qt.formatDateTime(new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]), Number(m[4]), Number(m[5])), "d MMM, hh:mm") : lastActivationTime;
    }
    clip: true
    Rectangle {
        anchors.fill: parent
        radius: fullView.bgRadius
        color: fullView.showBg ? fullView.bgColor : "transparent"
        border.color: UI.Theme.wash(fullView.accentColor, .18)
    }
    ColumnLayout {
        objectName: "mainPage"
        anchors.fill: parent
        visible: !fullView.commandsOpen && !fullView.toolsOverlayOpen
        spacing: 0
        ColumnLayout {
            id: header
            Layout.fillWidth: true
            Layout.leftMargin: fullView.contentMargin
            Layout.rightMargin: fullView.contentMargin
            Layout.topMargin: 20
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                UI.Flake {
                    implicitWidth: 31
                    implicitHeight: 31
                    working: fullView.isSpinning && fullView.uiActive
                    motion: fullView.enableMotion
                    style: fullView.iconStyle
                    accent: fullView.accentColor
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Text {
                        objectName: "widgetTitle"
                        text: "Nixdatifier"
                        color: fullView.textColor
                        font.pixelSize: 16 * fullView.fs
                        font.weight: Font.DemiBold
                        font.letterSpacing: -.4
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Row {
                            objectName: "headerGenerations"
                            spacing: 6
                            readonly property bool hasNext: fullView.activeGenNum > 0 && fullView.activeGenNum !== fullView.bootedGenNum
                            readonly property string description: (fullView.bootedGenNum > 0 ? qsTr("Booted generation #%1").arg(fullView.bootedGenNum) + (hasNext ? qsTr(" · Next boot #%1").arg(fullView.activeGenNum) : "") : qsTr("Next boot #%1").arg(fullView.activeGenNum)) + (fullView.runningTestBuild ? qsTr(" · Running a test build that reverts on reboot") : "")
                            visible: fullView.bootedGenNum > 0 || fullView.activeGenNum > 0
                            Accessible.role: Accessible.StaticText
                            Accessible.name: description
                            Text {
                                objectName: "bootedGenerationLabel"
                                visible: fullView.bootedGenNum > 0
                                text: "#" + fullView.bootedGenNum
                                color: UI.Theme.positive
                                font.pixelSize: 10 * fullView.fs
                                font.weight: Font.Medium
                            }
                            Text {
                                visible: parent.hasNext && fullView.bootedGenNum > 0
                                text: "→"
                                color: "#71849b"
                                font.pixelSize: 10 * fullView.fs
                            }
                            Text {
                                objectName: "nextGenerationLabel"
                                visible: parent.hasNext
                                text: "#" + fullView.activeGenNum
                                color: UI.Theme.changed
                                font.pixelSize: 10 * fullView.fs
                                font.weight: Font.Medium
                            }
                            Text {
                                objectName: "testBuildLabel"
                                visible: fullView.runningTestBuild
                                text: qsTr("· test build")
                                color: UI.Theme.highlightColor
                                font.pixelSize: 10 * fullView.fs
                                font.weight: Font.Medium
                            }
                            HoverHandler {
                                id: generationHover
                            }
                            ToolTip.visible: generationHover.hovered
                            ToolTip.text: description
                        }
                        Text {
                            Layout.fillWidth: true
                            text: fullView.releaseLabel
                            color: UI.Theme.muted
                            font.pixelSize: 10 * fullView.fs
                            elide: Text.ElideRight
                            ToolTip.text: fullView.nixosVersion
                            ToolTip.visible: versionHover.hovered
                            HoverHandler {
                                id: versionHover
                            }
                        }
                    }
                }
                RowLayout {
                    spacing: 0
                    UI.ActionButton {
                        glyph: "view-refresh"
                        flatStyle: true
                        tip: qsTr("Refresh system information")
                        enabled: !fullView.isLoadingGens
                        onClicked: fullView.refreshRequested()
                    }
                    UI.ActionButton {
                        glyph: "window-pin"
                        flatStyle: true
                        tip: fullView.isPopOutOpen ? qsTr("Unpin popup") : qsTr("Keep popup open")
                        primary: fullView.isPopOutOpen
                        onClicked: fullView.popOutRequested()
                    }
                    UI.ActionButton {
                        glyph: "configure"
                        flatStyle: true
                        tip: qsTr("Configure widget…")
                        onClicked: fullView.configureRequested()
                    }
                    UI.ActionButton {
                        id: moreButton
                        text: "⋯"
                        implicitWidth: 27
                        flatStyle: true
                        font.pixelSize: 15
                        tip: qsTr("More actions")
                        onClicked: moreMenu.open()
                        Menu {
                            id: moreMenu
                            y: moreButton.height
                            MenuItem {
                                text: qsTr("Refresh generations list")
                                enabled: !fullView.isLoadingGens
                                visible: fullView.isNixOS
                                height: visible ? implicitHeight : 0
                                onTriggered: fullView.refreshRequested()
                            }
                            MenuItem {
                                text: qsTr("Check flake for updates")
                                enabled: !fullView.isCheckingFlake
                                visible: fullView.isNixOS && fullView.showFlakeSection
                                height: visible ? implicitHeight : 0
                                onTriggered: fullView.checkFlakeRequested()
                            }
                            MenuItem {
                                text: qsTr("Configure widget…")
                                onTriggered: fullView.configureRequested()
                            }
                            MenuItem {
                                text: qsTr("Clean up Nix store…")
                                visible: fullView.isNixOS
                                height: visible ? implicitHeight : 0
                                onTriggered: cleanupMenu.open()
                            }
                            MenuSeparator {}
                            MenuItem {
                                text: qsTr("KDE Store Page")
                                onTriggered: Qt.openUrlExternally("https://store.kde.org/p/2360222/")
                            }
                            MenuItem {
                                text: qsTr("GitHub Repository")
                                onTriggered: Qt.openUrlExternally("https://github.com/Muddyblack/nixdatifier")
                            }
                        }
                    }
                }
            }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 13
                spacing: 12
                Row {
                    spacing: 5
                    Item {
                        visible: !!fullView.userFacePath
                        width: 12
                        height: 12
                        Image {
                            id: faceImage
                            anchors.fill: parent
                            source: fullView.userFacePath ? "file://" + fullView.userFacePath : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: false
                        }
                        Rectangle {
                            id: faceMask
                            anchors.fill: parent
                            radius: width / 2
                            visible: false
                        }
                        MultiEffect {
                            anchors.fill: parent
                            source: faceImage
                            maskEnabled: true
                            maskSource: faceMask
                        }
                    }
                    UI.Icon {
                        visible: !fullView.userFacePath
                        source: "user-identity"
                        width: 12
                        height: 12
                        isMask: true
                        color: "#7286a3"
                    }
                    Text {
                        text: fullView.hostname || "—"
                        color: "#a2b0c5"
                        font.pixelSize: 10 * fullView.fs
                    }
                }
                Row {
                    visible: !!fullView.uptime
                    spacing: 5
                    UI.Icon {
                        source: "clock"
                        width: 12
                        height: 12
                        isMask: true
                        color: "#7286a3"
                    }
                    Text {
                        text: qsTr("Up %1").arg(fullView.uptime)
                        color: "#a2b0c5"
                        font.pixelSize: 10 * fullView.fs
                    }
                }
                Row {
                    visible: !!fullView.lastActivationTime
                    spacing: 5
                    UI.Icon {
                        source: "view-calendar"
                        width: 12
                        height: 12
                        isMask: true
                        color: "#7286a3"
                    }
                    Text {
                        text: qsTr("Switched %1").arg(fullView.shortActivation())
                        color: "#8d9db4"
                        font.pixelSize: 9 * fullView.fs
                        ToolTip.text: fullView.lastActivationTime
                        ToolTip.visible: activationHover.hovered
                        HoverHandler {
                            id: activationHover
                        }
                    }
                }
            }
            Rectangle {
                visible: fullView.pendingAction !== "" || fullView.pendingCleanup !== ""
                Layout.fillWidth: true
                Layout.topMargin: visible ? 10 : 0
                implicitHeight: confirmRow.implicitHeight + 20
                radius: 8
                color: "#18edcc8a"
                RowLayout {
                    id: confirmRow
                    anchors.fill: parent
                    anchors.margins: 10
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: fullView.textColor
                        font.pixelSize: fullView.fpx(9)
                        text: fullView.pendingCleanup ? qsTr("Run this cleanup? Old generations may be removed.") : qsTr("%1 generation #%2?").arg(fullView.pendingAction === "delete" ? qsTr("Delete") : fullView.pendingAction === "switch" ? qsTr("Activate now") : qsTr("Set next boot to")).arg(fullView.pendingGenNum)
                    }
                    UI.ActionButton {
                        text: qsTr("Cancel")
                        onClicked: fullView.pendingCleanup ? fullView.cancelCleanup() : fullView.cancelPending()
                    }
                    UI.ActionButton {
                        text: qsTr("Confirm")
                        primary: true
                        enabled: !fullView.isBusy
                        onClicked: fullView.pendingCleanup ? fullView.confirmCleanup(fullView.pendingCleanup) : fullView.confirmPending()
                    }
                }
            }
            Item {
                objectName: "navigation"
                Layout.fillWidth: true
                Layout.topMargin: 12
                implicitHeight: 42 * fullView.fs
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: "#0dffffff"
                }
                Flickable {
                    anchors.fill: parent
                    contentWidth: tabsRow.width
                    contentHeight: height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Row {
                        id: tabsRow
                        spacing: fullView.width < 440 ? 16 : 22
                        Repeater {
                            model: [
                                {
                                    key: "timeline",
                                    label: qsTr("Generations"),
                                    glyph: "ic_history",
                                    nixosOnly: true
                                },
                                {
                                    key: "updates",
                                    label: qsTr("Updates"),
                                    glyph: "ic_outline_updates",
                                    nixosOnly: true
                                },
                                {
                                    key: "diff",
                                    label: qsTr("Compare"),
                                    glyph: "ic_outline_compare",
                                    nixosOnly: true
                                },
                                {
                                    key: "impermanence",
                                    label: qsTr("Persistent folders"),
                                    glyph: "ic_disk",
                                    nixosOnly: false
                                },
                                {
                                    key: "tools",
                                    label: qsTr("Tools"),
                                    glyph: "ic_grid",
                                    nixosOnly: false
                                }
                            ]
                            UI.NavigationTab {
                                required property var modelData
                                objectName: "tab-" + modelData.key
                                text: modelData.label
                                glyph: fullView.svg(modelData.glyph)
                                selected: modelData.key === "tools" ? fullView.inTools : fullView.activeViewMode === modelData.key
                                count: modelData.key === "updates" && fullView.showFlakeSection ? fullView.flakeUpdates.length : -1
                                accent: fullView.accentColor
                                scaleFactor: fullView.fs
                                showIcon: fullView.width >= 440
                                onClicked: fullView.viewModeChanged(modelData.key)
                                visible: (!modelData.nixosOnly || fullView.isNixOS) && (modelData.key !== "impermanence" || fullView.impermanence.detected)
                                width: visible ? implicitWidth : 0
                            }
                        }
                    }
                }
            }
        }
        Item {
            objectName: "viewBody"
            clip: true
            Layout.leftMargin: fullView.contentMargin
            Layout.rightMargin: fullView.contentMargin
            Layout.topMargin: 17
            Layout.bottomMargin: 16
            Layout.fillWidth: true
            Layout.fillHeight: true
            TimelineTab {
                id: timelineTab
                objectName: "generationTimeline"
                generationCounts: fullView.generationCounts
                onGenerationCountsRequested: genNum => fullView.generationCountsRequested(genNum)
                storePathCache: fullView.storePathCache
                onStorePathRequested: pkg => fullView.storePathRequested(pkg)
                enableGlow: fullView.enableGlow
                enableMotion: fullView.enableMotion
                enableLiveSwitch: fullView.enableLiveSwitch
                diffViewMode: fullView.diffViewMode
                uiActive: fullView.uiActive && visible
                anchors.fill: parent
                activeViewMode: fullView.activeViewMode
                accentColor: fullView.accentColor
                timelineColor: fullView.timelineColor
                textColor: fullView.textColor
                fs: fullView.fs
                isLoadingGens: fullView.isLoadingGens
                isLoadingDetails: fullView.isLoadingDetails
                isBusy: fullView.isBusy
                generations: fullView.generations
                selectedGenNum: fullView.selectedGenNum
                bootedGenNum: fullView.bootedGenNum
                activeGenNum: fullView.activeGenNum
                detailsCache: fullView.detailsCache
                diffMode: fullView.diffMode
                showDeleteButton: fullView.showDeleteButton
                diffFilterEnabled: fullView.diffFilterEnabled
                iconCache: fullView.iconCache
                metaCache: fullView.metaCache
                showPackageIcons: fullView.showPackageIcons
                iconStyle: fullView.iconStyle
                configDiffCache: fullView.configDiffCache

                onSelectGen: n => fullView.selectGen(n)
                onCollapseGen: () => fullView.collapseGen()
                onRequestAction: (n, a) => fullView.requestAction(n, a)
                onDiffModeToggle: n => fullView.diffModeToggle(n)
                onCopyToClipboard: t => fullView.copyToClipboard(t)
                onCompareWithRequested: (a, b) => fullView.openCompareInDiffTab(a, b)
                onRefreshRequested: () => fullView.refreshRequested()
                onConfigureRequested: () => fullView.configureRequested()
            }

            UpdatesTab {
                enableGlow: fullView.enableGlow
                objectName: "updatesView"
                storePathCache: fullView.storePathCache
                onStorePathRequested: pkg => fullView.storePathRequested(pkg)
                updatingInput: fullView.updatingInput
                anchors.fill: parent
                isBusy: fullView.isBusy
                iconCache: fullView.iconCache
                metaCache: fullView.metaCache
                showPackageIcons: fullView.showPackageIcons
                onCopyToClipboard: text => fullView.copyToClipboard(text)
                onCheckRequested: fullView.checkFlakeRequested()
                uiActive: fullView.uiActive && visible
                activeViewMode: fullView.activeViewMode
                accentColor: fullView.accentColor
                textColor: fullView.textColor
                fs: fullView.fs
                isCheckingFlake: fullView.isCheckingFlake
                flakeUpdates: fullView.flakeUpdates
                lastFlakeCheckTime: fullView.lastFlakeCheckTime
                dryRunCache: fullView.dryRunCache
                releaseNotesCache: fullView.releaseNotesCache
                isDryRunning: fullView.isDryRunning
                iconStyle: fullView.iconStyle

                onDryRunRequested: (inputName, overrideRef) => fullView.dryRunRequested(inputName, overrideRef)
                onReleaseNotesRequested: (inputName, force) => fullView.releaseNotesRequested(inputName, force)
                onUpdateInputRequested: inputName => fullView.updateInputRequested(inputName)
            }

            DiffTab {
                id: diffTab
                enableGlow: fullView.enableGlow
                storePathCache: fullView.storePathCache
                onStorePathRequested: pkg => fullView.storePathRequested(pkg)
                activeViewMode: fullView.activeViewMode
                accentColor: fullView.accentColor
                textColor: fullView.textColor
                fs: fullView.fs
                generations: fullView.generations
                detailsCache: fullView.detailsCache
                pairDiffCache: fullView.pairDiffCache
                isLoadingPairDiff: fullView.isLoadingPairDiff
                diffViewMode: fullView.diffViewMode
                iconCache: fullView.iconCache
                metaCache: fullView.metaCache
                showPackageIcons: fullView.showPackageIcons

                onCompareRequested: (a, b) => fullView.compareRequested(a, b)
                onCopyToClipboard: t => fullView.copyToClipboard(t)
                onDiffViewModePicked: mode => fullView.diffViewMode = mode
            }

            ImpermanenceTab {
                anchors.fill: parent
                activeViewMode: fullView.activeViewMode
                accentColor: fullView.accentColor
                textColor: fullView.textColor
                fs: fullView.fs
                impermanence: fullView.impermanence
                listing: fullView.impermanenceListing
                scan: fullView.impermanenceScan
                cleanup: fullView.impermanenceCleanup
                isListing: fullView.isListingImpermanence
                isScanning: fullView.isScanningImpermanence
                isAnalyzing: fullView.isAnalyzingImpermanence
                isRemoving: fullView.isRemovingImpermanence
                staleDays: fullView.impermanenceStaleDays

                onListRequested: (path, force) => fullView.impermanenceListRequested(path, force)
                onScanRequested: force => fullView.impermanenceScanRequested(force)
                onAnalyzeRequested: force => fullView.impermanenceAnalyzeRequested(force)
                onRemoveRequested: (path, name) => fullView.impermanenceRemoveRequested(path, name)
                onOpenRequested: path => fullView.impermanenceOpenRequested(path)
                onClamScanRequested: fullView.clamScanRequested()
                onCopyToClipboard: t => fullView.copyToClipboard(t)
            }

            ScrollView {
                id: toolsScroll
                objectName: "toolsView"
                anchors.fill: parent
                clip: true
                contentWidth: availableWidth
                visible: fullView.activeViewMode === "tools"
                ColumnLayout {
                    width: toolsScroll.availableWidth
                    spacing: 0
                    // Two rows of three; narrow windows get two columns instead
                    // of squeezing six cards onto one line.
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 17
                        columns: fullView.width >= 440 ? 3 : 2
                        columnSpacing: 10
                        rowSpacing: 10
                        uniformCellWidths: true
                        uniformCellHeights: true
                        Repeater {
                            model: fullView.tools
                            AbstractButton {
                                id: toolButton
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                implicitHeight: toolContent.implicitHeight + 30
                                padding: 13
                                hoverEnabled: true
                                onClicked: fullView.viewModeChanged(modelData.key)
                                background: Rectangle {
                                    radius: 9
                                    color: toolButton.hovered ? UI.Theme.wash(fullView.accentColor, .05) : "#03ffffff"
                                    border.color: toolButton.hovered ? UI.Theme.wash(fullView.accentColor, .3) : "#10ffffff"
                                }
                                contentItem: ColumnLayout {
                                    id: toolContent
                                    spacing: 0
                                    UI.Icon {
                                        Layout.bottomMargin: 15
                                        source: fullView.svg(toolButton.modelData.glyph)
                                        implicitWidth: 21
                                        implicitHeight: 21
                                        isMask: true
                                        color: fullView.accentColor
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        Layout.bottomMargin: 7
                                        text: toolButton.modelData.label
                                        color: fullView.textColor
                                        font.pixelSize: 11 * fullView.fs
                                        font.weight: Font.Medium
                                        wrapMode: Text.WordWrap
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: toolButton.modelData.hint
                                        color: "#8fa0b7"
                                        font.pixelSize: 9 * fullView.fs
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.6
                                    }
                                }
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: storageColumn.implicitHeight + 26
                        radius: 9
                        color: "#03ffffff"
                        border.color: "#0effffff"
                        ColumnLayout {
                            id: storageColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 13
                            spacing: 0
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: qsTr("Nix store")
                                    color: fullView.textColor
                                    font.pixelSize: 10 * fullView.fs
                                }
                                Text {
                                    text: fullView.storeLabel
                                    color: "#93a5bd"
                                    font.pixelSize: 9 * fullView.fs
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.topMargin: 13
                                Layout.bottomMargin: 10
                                implicitHeight: 5
                                radius: 3
                                clip: true
                                color: "#0affffff"
                                Rectangle {
                                    anchors.fill: parent
                                    color: "#779ecc"
                                    visible: fullView.diskStoreBytes > 0
                                }
                                Rectangle {
                                    anchors.right: parent.right
                                    height: parent.height
                                    width: fullView.diskStoreBytes > 0 ? parent.width * Math.max(0, Math.min(1, fullView.diskReclaimableBytes / fullView.diskStoreBytes)) : 0
                                    color: UI.Theme.changed
                                }
                                ToolTip.text: qsTr("Reclaimable portion of the Nix store")
                                ToolTip.visible: storageHover.hovered
                                HoverHandler {
                                    id: storageHover
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: qsTr("%1 free").arg(UI.Theme.formatBytes(fullView.diskFreeBytes) || "—")
                                    color: "#8fa0b7"
                                    font.pixelSize: 9 * fullView.fs
                                }
                                Text {
                                    text: qsTr("%1 reclaimable").arg(fullView.reclaimableLabel)
                                    color: UI.Theme.changed
                                    font.pixelSize: 9 * fullView.fs
                                }
                            }
                        }
                    }
                    UI.ActionButton {
                        Layout.topMargin: 13
                        visible: fullView.isNixOS
                        height: visible ? implicitHeight : 0
                        text: qsTr("Clean up old generations…")
                        glyph: fullView.svg("ic_delete")
                        font.pixelSize: 10 * fullView.fs
                        onClicked: cleanupMenu.open()
                    }
                }
            }
        }
        Rectangle {
            id: storageFooter
            objectName: "storageFooter"
            Layout.fillWidth: true
            implicitHeight: 42 * fullView.fs
            color: "#0c000000"
            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: "#0dffffff"
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: fullView.contentMargin
                anchors.rightMargin: fullView.contentMargin
                spacing: 6
                UI.Icon {
                    source: fullView.isSpinning ? fullView.svg("ic_info") : "drive-harddisk"
                    implicitWidth: 13
                    implicitHeight: 13
                    isMask: true
                    color: "#76869b"
                }
                Text {
                    objectName: "footerStatus"
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    readonly property string storage: fullView.storeLabel + qsTr(" store  ·  %1 reclaimable").arg(fullView.reclaimableLabel)
                    text: fullView.isSpinning ? fullView.busyLabel || qsTr("Working…") : storage
                    color: fullView.isSpinning ? fullView.accentColor : "#8f9db0"
                    font.pixelSize: 9 * fullView.fs
                    HoverHandler {
                        id: footerHover
                    }
                    ToolTip.visible: footerHover.hovered
                    ToolTip.text: fullView.isSpinning ? text + "\n" + storage : storage
                }
                UI.ActionButton {
                    id: feedbackButton
                    objectName: "feedbackIndicator"
                    visible: fullView.toasts.length > 0
                    readonly property var latest: fullView.toasts.length ? fullView.toasts[fullView.toasts.length - 1] : ({
                            msg: "",
                            err: false
                        })
                    flatStyle: true
                    primary: true
                    implicitHeight: 27
                    glyph: fullView.svg(latest.err ? "ic_info" : "ic_check")
                    text: latest.err ? qsTr("Notice") : qsTr("Done")
                    accent: latest.err ? UI.Theme.changed : UI.Theme.positive
                    tip: latest.msg
                    font.pixelSize: 9 * fullView.fs
                    onClicked: feedbackPopup.opened ? feedbackPopup.close() : feedbackPopup.open()
                    Popup {
                        id: feedbackPopup
                        objectName: "feedbackDetails"
                        parent: fullView
                        width: Math.min(380, fullView.width - 2 * fullView.contentMargin)
                        x: fullView.width - width - fullView.contentMargin
                        y: fullView.height - height - 48
                        padding: 13
                        modal: false
                        focus: true
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                        background: Rectangle {
                            color: "#1b2330"
                            border.color: "#29a3b9de"
                            radius: 9
                        }
                        contentItem: ColumnLayout {
                            spacing: 10
                            Text {
                                text: qsTr("Status")
                                color: fullView.textColor
                                font.pixelSize: 12 * fullView.fs
                                font.weight: Font.Medium
                            }
                            Text {
                                Layout.fillWidth: true
                                text: feedbackButton.latest.msg
                                textFormat: Text.PlainText
                                color: "#bac7d9"
                                wrapMode: Text.WrapAnywhere
                                font.pixelSize: 11 * fullView.fs
                                maximumLineCount: 9
                                elide: Text.ElideRight
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                UI.ActionButton {
                                    glyph: fullView.svg("ic_copy")
                                    text: qsTr("Copy")
                                    onClicked: fullView.copyToClipboard(feedbackButton.latest.msg)
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                                UI.ActionButton {
                                    text: qsTr("Dismiss")
                                    onClicked: {
                                        fullView.dismissToast(fullView.toasts.length - 1);
                                        if (!fullView.toasts.length)
                                            feedbackPopup.close();
                                    }
                                }
                            }
                        }
                    }
                }
                UI.ActionButton {
                    id: commandsButton
                    objectName: "commandsButton"
                    visible: fullView.isNixOS && fullView.showCommandButtons
                    text: qsTr("Commands ›")
                    glyph: "utilities-terminal"
                    flatStyle: true
                    font.pixelSize: 9 * fullView.fs
                    onClicked: fullView.openCommands()
                }
            }
            Item {
                objectName: "footerProgress"
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: fullView.bgRadius
                anchors.rightMargin: fullView.bgRadius
                height: 2
                clip: true
                visible: fullView.isSpinning
                Rectangle {
                    id: progress
                    property real sweep: 0
                    width: parent.width * (fullView.enableMotion ? .35 : 1)
                    height: parent.height
                    x: fullView.enableMotion ? (parent.width + width) * sweep - width : 0
                    color: fullView.accentColor
                    NumberAnimation on sweep {
                        running: fullView.isSpinning && fullView.uiActive && fullView.enableMotion && !fullView.commandsOpen
                        from: 0
                        to: 1
                        duration: 1600
                        loops: Animation.Infinite
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }
    CommandsView {
        id: commandsView
        objectName: "commandsView"
        anchors.fill: parent
        visible: fullView.commandsOpen
        commands: fullView.customCommands
        textColor: fullView.textColor
        accentColor: fullView.accentColor
        fs: fullView.fs
        isBusy: fullView.isBusy
        working: fullView.isSpinning && fullView.uiActive
        enableMotion: fullView.enableMotion
        iconStyle: fullView.iconStyle
        onCloseRequested: fullView.closeCommands()
        onConfigureRequested: {
            fullView.closeCommands();
            fullView.configureRequested();
        }
        onRunRequested: (cmd, label) => {
            if (fullView.isBusy)
                return;
            fullView.closeCommands();
            fullView.runCommand(cmd, label);
        }
    }
    Item {
        id: toolsOverlay
        objectName: "toolsOverlay"
        anchors.fill: parent
        visible: fullView.toolsOverlayOpen
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: fullView.contentMargin
                Layout.rightMargin: fullView.contentMargin
                Layout.topMargin: 20
                Layout.bottomMargin: 18
                spacing: 9
                UI.ActionButton {
                    objectName: "toolsOverlayBack"
                    glyph: "go-previous"
                    flatStyle: true
                    tip: qsTr("Back to Tools")
                    onClicked: fullView.viewModeChanged("tools")
                }
                UI.Flake {
                    implicitWidth: 24
                    implicitHeight: 24
                    working: fullView.isSpinning && fullView.uiActive
                    motion: fullView.enableMotion
                    style: fullView.iconStyle
                    accent: fullView.accentColor
                }
                Text {
                    Layout.fillWidth: true
                    text: fullView.activeTool ? fullView.activeTool.label : ""
                    color: fullView.textColor
                    font.pixelSize: 14 * fullView.fs
                    font.weight: Font.Medium
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: UI.Theme.line
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: fullView.contentMargin
                Layout.rightMargin: fullView.contentMargin
                Layout.topMargin: 17
                Layout.bottomMargin: 20
                DevEnvTab {
                    anchors.fill: parent
                    activeViewMode: fullView.activeViewMode
                    accentColor: fullView.accentColor
                    textColor: fullView.textColor
                    fs: fullView.fs
                    devEnvResult: fullView.devEnvResult
                    devEnvProjects: fullView.devEnvProjects
                    systemFlakePath: fullView.systemFlakePath
                    isProbingDevEnv: fullView.isProbingDevEnv
                    shellPackages: fullView.shellPackages
                    devSpace: fullView.devSpace
                    isMeasuringSpace: fullView.isMeasuringSpace

                    onDevEnvRequested: path => fullView.devEnvRequested(path)
                    onDiscoverRequested: fullView.devEnvDiscoverRequested()
                    onActionRequested: (kind, dir) => fullView.devEnvActionRequested(kind, dir)
                    onShellPackagesRequested: (dir, name) => fullView.shellPackagesRequested(dir, name)
                    onMeasureSpaceRequested: fullView.measureSpaceRequested()
                    onClearCacheRequested: dir => fullView.clearCacheRequested(dir)
                    onCopyToClipboard: t => fullView.copyToClipboard(t)
                }
                HealthTab {
                    anchors.fill: parent
                    activeViewMode: fullView.activeViewMode
                    accentColor: fullView.accentColor
                    textColor: fullView.textColor
                    fs: fullView.fs
                    healthResult: fullView.healthResult
                    isProbingHealth: fullView.isProbingHealth

                    onHealthRequested: force => fullView.healthRequested(force)
                    onCopyToClipboard: t => fullView.copyToClipboard(t)
                }
                SecretsTab {
                    anchors.fill: parent
                    activeViewMode: fullView.activeViewMode
                    textColor: fullView.textColor
                    fs: fullView.fs
                    deployedSecrets: fullView.deployedSecrets
                    sourceSecrets: fullView.sourceSecrets
                }
                HashTab {
                    anchors.fill: parent
                    activeViewMode: fullView.activeViewMode
                    accentColor: fullView.accentColor
                    textColor: fullView.textColor
                    fs: fullView.fs
                    hashResult: fullView.hashResult
                    isProbingHash: fullView.isProbingHash

                    onHashRequested: (mode, input) => fullView.hashRequested(mode, input)
                    onCopyToClipboard: t => fullView.copyToClipboard(t)
                }
                HistoryTab {
                    anchors.fill: parent
                    activeViewMode: fullView.activeViewMode
                    accentColor: fullView.accentColor
                    textColor: fullView.textColor
                    fs: fullView.fs
                    actionHistory: fullView.actionHistory
                    isLoadingHistory: fullView.isLoadingHistory

                    onClearHistoryRequested: fullView.clearHistoryRequested()
                    onCopyToClipboard: t => fullView.copyToClipboard(t)
                }
                StoreUsageTab {
                    anchors.fill: parent
                    activeViewMode: fullView.activeViewMode
                    accentColor: fullView.accentColor
                    textColor: fullView.textColor
                    fs: fullView.fs
                    storeUsageResult: fullView.storeUsageResult
                    isProbingStoreUsage: fullView.isProbingStoreUsage

                    onStoreUsageRequested: path => fullView.storeUsageRequested(path)
                    onCopyToClipboard: t => fullView.copyToClipboard(t)
                }
            }
        }
    }
    Menu {
        id: cleanupMenu
        x: Math.max(0, fullView.width - width - 18)
        y: 64
        MenuItem {
            text: qsTr("Collect unused store paths")
            enabled: !fullView.isBusy
            onTriggered: fullView.cleanupVariantPicked("gc")
        }
        MenuItem {
            text: qsTr("Remove generations older than 14 days")
            enabled: !fullView.isBusy
            onTriggered: fullView.cleanupVariantPicked("gc-14d")
        }
        MenuItem {
            text: qsTr("Remove all non-current generations")
            enabled: !fullView.isBusy
            onTriggered: fullView.cleanupVariantPicked("gc-all")
        }
        MenuItem {
            visible: fullView.gcCustomCommand !== ""
            height: visible ? implicitHeight : 0
            text: qsTr("Run custom cleanup command")
            enabled: !fullView.isBusy
            onTriggered: fullView.cleanupVariantPicked("gc-custom")
        }
    }
}
