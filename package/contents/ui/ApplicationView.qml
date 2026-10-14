import QtQuick

FullView {
    implicitWidth: engine.settings.popupWidth || 600
    implicitHeight: engine.settings.popupHeight || 740
    required property var engine
    storePathCache: engine.storePathCache
    generationCounts: engine.generationCounts
    onGenerationCountsRequested: genNum => {
        if (engine.autoStart)
            engine.requestGenerationCounts(genNum);
    }
    onStorePathRequested: pkg => engine.resolveStorePath(pkg)
    updatingInput: engine.updatingInput
    isSpinning: engine.isSpinning
    busyLabel: engine.busyLabel
    enableGlow: engine.settings.enableGlow
    enableMotion: engine.settings.enableMotion !== false
    enableLiveSwitch: engine.settings.enableLiveSwitch

    uiActive: engine.uiActive
    accentColor: engine.accentColor
    timelineColor: engine.timelineColor
    textColor: engine.textColor
    fs: engine.fs
    showBg: engine.settings.showBg
    bgColor: Qt.color(engine.settings.bgColor || "#800a0c14")
    bgRadius: engine.settings.bgRadius
    isBusy: engine.isBusy
    isLoadingGens: engine.isLoadingGens
    isLoadingDetails: engine.isLoadingDetails
    isCheckingFlake: engine.isCheckingFlake
    generations: engine.generations
    flakeUpdates: engine.flakeUpdates
    toasts: engine.toasts
    lastFlakeCheckTime: engine.lastFlakeCheckTime
    activeGenNum: engine.activeGenNum
    bootedGenNum: engine.bootedGenNum
    runningTestBuild: engine.runningTestBuild
    selectedGenNum: engine.selectedGenNum
    detailsCache: engine.detailsCache
    diffMode: engine.diffMode
    showDeleteButton: engine.settings.showDeleteButton
    diffFilterEnabled: engine.settings.diffFilterEnabled
    showFlakeSection: engine.settings.showFlakeSection
    showCommandButtons: engine.settings.showCommandButtons
    customCommands: engine.customCommands
    activeViewMode: engine.activeViewMode
    deployedSecrets: engine.deployedSecrets
    sourceSecrets: engine.sourceSecrets
    hostname: engine.hostname
    userFacePath: engine.userFacePath
    nixosVersion: engine.nixosVersion
    lastActivationTime: engine.lastActivationTime
    uptime: engine.uptime
    diskStoreBytes: engine.diskStoreBytes
    diskReclaimableBytes: engine.diskReclaimableBytes
    diskFreeBytes: engine.diskFreeBytes
    diskUsageError: engine.diskUsageError
    isProbingDiskUsage: engine._diskProbeRunning
    hashResult: engine.hashResult
    isProbingHash: engine.isProbingHash
    actionHistory: engine.actionHistory
    isLoadingHistory: engine.isLoadingHistory
    profilePackages: engine.profilePackages
    isLoadingProfile: engine.isLoadingProfile
    onProfileInstallRequested: reference => engine.runProfileAction("install", reference)
    onProfileUpgradeRequested: name => engine.runProfileAction("upgrade", name)
    onProfileRemoveRequested: name => engine.runProfileAction("remove", name)
    onProfileCleanRequested: () => engine.runProfileAction("clean", "")
    storeUsageResult: engine.storeUsageResult
    isProbingStoreUsage: engine.isProbingStoreUsage
    pendingGenNum: engine.pendingGenNum
    pendingAction: engine.pendingAction
    pendingCleanup: engine.pendingCleanup
    gcCustomCommand: engine.settings.gcCustomCommand || ""
    pairDiffCache: engine.pairDiffCache
    isLoadingPairDiff: engine.isLoadingPairDiff
    configDiffCache: engine.configDiffCache
    dryRunCache: engine.dryRunCache
    releaseNotesCache: engine.releaseNotesCache
    isDryRunning: engine.isDryRunning
    diffViewMode: engine.settings.diffViewMode || "compact"
    iconCache: engine.iconCache
    metaCache: engine.metaCache
    showPackageIcons: engine.settings.showPackageIcons
    iconStyle: engine.iconStyle
    isNixOS: engine.isNixOS

    onViewModeChanged: mode => engine.activeViewMode = mode
    onConfirmPending: () => engine.confirmPendingAction()
    onCancelPending: () => engine.cancelPendingAction()
    onCleanupVariantPicked: mode => {
        engine.pendingCleanup = mode;
    }
    onConfirmCleanup: mode => {
        engine.pendingCleanup = "";
        engine.executeCleanup(mode);
    }
    onCancelCleanup: () => {
        engine.pendingCleanup = "";
    }
    onCompareRequested: (a, b) => engine.comparePair(a, b)
    onDiffViewModeChanged: engine.settings.diffViewMode = diffViewMode
    onRefreshRequested: () => engine.refreshGenerations()
    onDiskUsageRefreshRequested: () => engine.probeDiskUsage(true)
    onCheckFlakeRequested: () => engine.checkFlakeUpdates()
    onSelectGen: n => engine.loadGenDetails(n)
    onCollapseGen: () => engine.selectedGenNum = -1
    onRequestAction: (n, a) => engine.requestAction(n, a)
    onDiffModeToggle: function (genNum) {
        engine.diffMode = (engine.diffMode === "booted" ? "prev" : "booted");
        const cache = Object.assign({}, engine.detailsCache);
        delete cache[genNum];
        engine.detailsCache = cache;
        engine.loadGenDetails(genNum);
    }
    onRunCommand: (cmd, label) => engine.runCustomCommand(cmd, label)
    onCopyToClipboard: t => engine.copyToClipboard(t)
    onDismissToast: function (idx) {
        var arr = engine.toasts.slice();
        arr.splice(idx, 1);
        engine.toasts = arr;
    }
    onHashRequested: (mode, input) => engine.runHashProbe(mode, input)
    onClearHistoryRequested: () => engine.clearHistory()
    onStoreUsageRequested: path => engine.probeStoreUsage(path)
    impermanence: engine.impermanence
    impermanenceListing: engine.impermanenceListing
    impermanenceScan: engine.impermanenceScan
    impermanenceCleanup: engine.impermanenceCleanup
    isListingImpermanence: engine.isListingImpermanence
    isScanningImpermanence: engine.isScanningImpermanence
    isAnalyzingImpermanence: engine.isAnalyzingImpermanence
    impermanenceRemovalStates: engine.impermanenceRemovalStates
    isRemovingImpermanence: engine.isRemovingImpermanence
    impermanenceSizes: engine.impermanenceSizes
    isMeasuringImpermanence: engine.isMeasuringImpermanence
    impermanenceStaleDays: engine.settings.impermanenceStaleDays || 180
    onImpermanenceListRequested: (path, force) => engine.listImpermanence(path, force)
    onImpermanenceListCancelRequested: engine.closeImpermanenceFolder()
    onImpermanenceSizesRequested: force => engine.measureImpermanence(force)
    onImpermanenceScanRequested: force => engine.scanImpermanence(force)
    onImpermanenceAnalyzeRequested: force => engine.analyzeImpermanence(force)
    onImpermanenceRemoveRequested: (path, name) => engine.removeImpermanencePath(path, name)
    onImpermanenceRemoveManyRequested: items => engine.removeImpermanencePaths(items)
    onImpermanenceOpenRequested: path => engine.openImpermanencePath(path)
    onClamScanRequested: engine.runClamScan()
    devEnvResult: engine.devEnvResult
    devEnvProjects: engine.devEnvProjects
    systemFlakePath: engine.flakePath
    isProbingDevEnv: engine.isProbingDevEnv
    onDevEnvRequested: path => engine.probeDevEnv(path)
    onDevEnvDiscoverRequested: engine.discoverDevEnvs()
    shellPackages: engine.shellPackages
    devSpace: engine.devSpace
    isMeasuringSpace: engine.isMeasuringSpace
    onDevEnvActionRequested: (kind, dir) => engine.devEnvAction(kind, dir)
    onShellPackagesRequested: (dir, name) => engine.loadShellPackages(dir, name)
    onMeasureSpaceRequested: engine.measureDevSpace()
    onClearCacheRequested: dir => engine.clearDevCache(dir)
    healthResult: engine.healthResult
    isProbingHealth: engine.isProbingHealth
    onHealthRequested: force => engine.probeHealth(force)
    onDryRunRequested: (inputName, overrideRef) => engine.runDryPreview(inputName, overrideRef)
    onReleaseNotesRequested: (inputName, force) => engine.loadReleaseNotes(inputName, force)
    onUpdateInputRequested: inputName => engine.runFlakeUpdateInput(inputName)
    onPopOutRequested: engine.pinned = !engine.pinned
    onConfigureRequested: engine.configureRequested()
    isPopOutOpen: engine.pinned
}
