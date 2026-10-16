import QtQuick

QtObject {
    property string flakePath: ""
    property string configRepoPath: ""
    property int checkInterval: 3600
    property int maxGenerations: 10
    property string defaultView: "timeline"
    property bool enableHostDetect: true
    property bool checkTarballs: true
    property bool deepInputCheck: false
    property string customCommands: "[{\"label\":\"update\",\"cmd\":\"nix flake update\"},{\"label\":\"upnix\",\"cmd\":\"upnix\"}]"
    property bool showCommandButtons: true
    property string commandTerminal: ""
    property bool usePkexec: true
    property bool enableLiveSwitch: true
    property bool confirmBeforeRollback: true
    property bool confirmBeforeDelete: true
    property bool showDeleteButton: true
    property bool showNotifications: true
    property bool autoRefreshOnOpen: true
    property bool showFlakeSection: true
    property string secretsPath: ""
    property string secretsSourcePath: ""
    property string githubTokenFile: ""
    property bool githubUseGh: false
    property string impermanencePaths: ""
    property int impermanenceStaleDays: 180
    property bool impermanenceAllDisks: false
    property bool diffFilterEnabled: true
    property color timelineColor: "#71849b"
    property color accentColor: "#91bcff"
    property real fontScale: 1.0
    property bool showBg: true
    property string bgColor: "#f5131923"
    property real bgRadius: 14.0
    property bool useSystemTextColor: true
    property color customTextColor: "#ffffff"
    property bool enableGlow: true
    property string iconStyle: "colored"
    property string diffViewMode: "compact"
    property bool showPackageIcons: true
    property string compactStyle: "icon"
    property bool compactShowBadge: true
    property bool compactAnimateIcon: true
    property int popupWidth: 600
    property int popupHeight: 740
    property string gcCustomCommand: ""
    property bool enableMotion: true
    property string pillMode: "always"
    property string popupPosition: "top-right"
    property int panelEdgeOffset: 0
    property int panelSideOffset: 0
}
