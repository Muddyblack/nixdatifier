import QtQuick
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

Kirigami.Page {
    padding: 0
    globalToolBarStyle: Kirigami.ApplicationHeaderStyle.None
    implicitWidth: 900
    implicitHeight: 740
    Settings {
        id: state
    }
    property alias cfg_flakePath: state.flakePath
    property alias cfg_configRepoPath: state.configRepoPath
    property alias cfg_checkInterval: state.checkInterval
    property alias cfg_maxGenerations: state.maxGenerations
    property alias cfg_defaultView: state.defaultView
    property alias cfg_enableHostDetect: state.enableHostDetect
    property alias cfg_checkTarballs: state.checkTarballs
    property alias cfg_deepInputCheck: state.deepInputCheck
    property alias cfg_ignoredInputs: state.ignoredInputs
    property alias cfg_customCommands: state.customCommands
    property alias cfg_showCommandButtons: state.showCommandButtons
    property alias cfg_commandTerminal: state.commandTerminal
    property alias cfg_usePkexec: state.usePkexec
    property alias cfg_enableLiveSwitch: state.enableLiveSwitch
    property alias cfg_confirmBeforeRollback: state.confirmBeforeRollback
    property alias cfg_confirmBeforeDelete: state.confirmBeforeDelete
    property alias cfg_showDeleteButton: state.showDeleteButton
    property alias cfg_showNotifications: state.showNotifications
    property alias cfg_autoRefreshOnOpen: state.autoRefreshOnOpen
    property alias cfg_showFlakeSection: state.showFlakeSection
    property alias cfg_secretsPath: state.secretsPath
    property alias cfg_secretsSourcePath: state.secretsSourcePath
    property alias cfg_githubTokenFile: state.githubTokenFile
    property alias cfg_githubUseGh: state.githubUseGh
    property alias cfg_impermanencePaths: state.impermanencePaths
    property alias cfg_impermanenceStaleDays: state.impermanenceStaleDays
    property alias cfg_impermanenceAllDisks: state.impermanenceAllDisks
    property alias cfg_diffFilterEnabled: state.diffFilterEnabled
    property alias cfg_timelineColor: state.timelineColor
    property alias cfg_accentColor: state.accentColor
    property alias cfg_fontScale: state.fontScale
    property alias cfg_showBg: state.showBg
    property alias cfg_bgColor: state.bgColor
    property alias cfg_bgRadius: state.bgRadius
    property alias cfg_useSystemTextColor: state.useSystemTextColor
    property alias cfg_customTextColor: state.customTextColor
    property alias cfg_enableGlow: state.enableGlow
    property alias cfg_iconStyle: state.iconStyle
    property alias cfg_diffViewMode: state.diffViewMode
    property alias cfg_showPackageIcons: state.showPackageIcons
    property alias cfg_compactStyle: state.compactStyle
    property alias cfg_compactShowBadge: state.compactShowBadge
    property alias cfg_compactAnimateIcon: state.compactAnimateIcon
    property alias cfg_popupWidth: state.popupWidth
    property alias cfg_popupHeight: state.popupHeight
    property alias cfg_gcCustomCommand: state.gcCustomCommand
    property alias cfg_enableMotion: state.enableMotion
    // Plasma injects defaults separately from the editable values.
    Settings {
        id: defaults
    }
    property alias cfg_flakePathDefault: defaults.flakePath
    property alias cfg_configRepoPathDefault: defaults.configRepoPath
    property alias cfg_checkIntervalDefault: defaults.checkInterval
    property alias cfg_maxGenerationsDefault: defaults.maxGenerations
    property alias cfg_defaultViewDefault: defaults.defaultView
    property alias cfg_enableHostDetectDefault: defaults.enableHostDetect
    property alias cfg_checkTarballsDefault: defaults.checkTarballs
    property alias cfg_deepInputCheckDefault: defaults.deepInputCheck
    property alias cfg_ignoredInputsDefault: defaults.ignoredInputs
    property alias cfg_customCommandsDefault: defaults.customCommands
    property alias cfg_showCommandButtonsDefault: defaults.showCommandButtons
    property alias cfg_commandTerminalDefault: defaults.commandTerminal
    property alias cfg_usePkexecDefault: defaults.usePkexec
    property alias cfg_enableLiveSwitchDefault: defaults.enableLiveSwitch
    property alias cfg_confirmBeforeRollbackDefault: defaults.confirmBeforeRollback
    property alias cfg_confirmBeforeDeleteDefault: defaults.confirmBeforeDelete
    property alias cfg_showDeleteButtonDefault: defaults.showDeleteButton
    property alias cfg_showNotificationsDefault: defaults.showNotifications
    property alias cfg_autoRefreshOnOpenDefault: defaults.autoRefreshOnOpen
    property alias cfg_showFlakeSectionDefault: defaults.showFlakeSection
    property alias cfg_secretsPathDefault: defaults.secretsPath
    property alias cfg_secretsSourcePathDefault: defaults.secretsSourcePath
    property alias cfg_githubTokenFileDefault: defaults.githubTokenFile
    property alias cfg_githubUseGhDefault: defaults.githubUseGh
    property alias cfg_impermanencePathsDefault: defaults.impermanencePaths
    property alias cfg_impermanenceStaleDaysDefault: defaults.impermanenceStaleDays
    property alias cfg_impermanenceAllDisksDefault: defaults.impermanenceAllDisks
    property alias cfg_diffFilterEnabledDefault: defaults.diffFilterEnabled
    property alias cfg_timelineColorDefault: defaults.timelineColor
    property alias cfg_accentColorDefault: defaults.accentColor
    property alias cfg_fontScaleDefault: defaults.fontScale
    property alias cfg_showBgDefault: defaults.showBg
    property alias cfg_bgColorDefault: defaults.bgColor
    property alias cfg_bgRadiusDefault: defaults.bgRadius
    property alias cfg_useSystemTextColorDefault: defaults.useSystemTextColor
    property alias cfg_customTextColorDefault: defaults.customTextColor
    property alias cfg_enableGlowDefault: defaults.enableGlow
    property alias cfg_iconStyleDefault: defaults.iconStyle
    property alias cfg_diffViewModeDefault: defaults.diffViewMode
    property alias cfg_showPackageIconsDefault: defaults.showPackageIcons
    property alias cfg_compactStyleDefault: defaults.compactStyle
    property alias cfg_compactShowBadgeDefault: defaults.compactShowBadge
    property alias cfg_compactAnimateIconDefault: defaults.compactAnimateIcon
    property alias cfg_popupWidthDefault: defaults.popupWidth
    property alias cfg_popupHeightDefault: defaults.popupHeight
    property alias cfg_gcCustomCommandDefault: defaults.gcCustomCommand
    property alias cfg_enableMotionDefault: defaults.enableMotion
    SettingsEditor {
        anchors.fill: parent
        settings: state
        // qmllint disable unresolved-type
        currentVersion: (typeof Plasmoid !== "undefined" && Plasmoid.metaData) ? Plasmoid.metaData.version : ""
        // qmllint enable unresolved-type
    }
}
