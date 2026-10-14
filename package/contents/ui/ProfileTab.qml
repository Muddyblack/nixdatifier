import QtQuick
import QtQuick.Layouts
import "shared" as UI
import "components"

// Packages in the user's own profile (nix profile): what is installed, and
// install, upgrade, remove and clean up without a terminal. Everything runs
// through `nixdatifier profile`, so the terminal view shows the same.
Item {
    id: profileTab

    required property color accentColor
    required property color textColor
    required property real fs
    required property string activeViewMode
    required property var profilePackages
    property bool isLoadingProfile: false
    property bool isBusy: false

    signal installRequested(string reference)
    signal upgradeRequested(string name)
    signal removeRequested(string name)
    signal cleanRequested
    signal refreshRequested

    anchors.fill: parent
    visible: activeViewMode === "profile"

    // The row asking for a second click before it removes anything.
    property string confirmingRemove: ""

    function install() {
        const reference = referenceField.text.trim();
        if (reference === "" || isBusy)
            return;
        installRequested(reference);
        referenceField.text = "";
    }
    onVisibleChanged: if (!visible)
        confirmingRemove = ""

    UI.ScrollView {
        id: scroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: scroll.availableWidth
            spacing: 9

            SectionIntro {
                Layout.fillWidth: true
                Layout.bottomMargin: 8
                title: profileTab.isLoadingProfile && profileTab.profilePackages.length === 0 ? qsTr("Reading your profile…") : profileTab.profilePackages.length ? qsTr("%n package(s) in your profile", "", profileTab.profilePackages.length) : qsTr("Nothing installed in your profile")
                subtitle: qsTr("What nix profile install put there, for your user only.")
                textColor: profileTab.textColor
                fs: profileTab.fs
                UI.ActionButton {
                    objectName: "upgradeAllPackages"
                    text: qsTr("Upgrade all")
                    glyph: Qt.resolvedUrl("assets/ic_refresh.svg")
                    tip: qsTr("Upgrade every package in your profile")
                    flatStyle: true
                    implicitHeight: 27
                    font.pixelSize: UI.Theme.fontPx(10, profileTab.fs)
                    enabled: !profileTab.isBusy
                    visible: profileTab.profilePackages.length > 0
                    onClicked: profileTab.upgradeRequested("")
                }
                UI.ActionButton {
                    objectName: "cleanProfile"
                    text: qsTr("Clean old versions")
                    glyph: Qt.resolvedUrl("assets/ic_delete.svg")
                    tip: qsTr("Delete the earlier versions of your profile")
                    flatStyle: true
                    implicitHeight: 27
                    font.pixelSize: UI.Theme.fontPx(10, profileTab.fs)
                    enabled: !profileTab.isBusy
                    onClicked: profileTab.cleanRequested()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                FieldInput {
                    id: referenceField
                    objectName: "profileReference"
                    Layout.fillWidth: true
                    fs: profileTab.fs
                    accent: profileTab.accentColor
                    textColor: profileTab.textColor
                    mono: true
                    placeholderText: "nixpkgs#hello   github:user/repo"
                    enabled: !profileTab.isBusy
                    onAccepted: profileTab.install()
                }
                UI.ActionButton {
                    objectName: "installPackage"
                    text: qsTr("Install")
                    glyph: Qt.resolvedUrl("assets/ic_activate.svg")
                    tip: qsTr("Install into your profile")
                    implicitHeight: 33
                    font.pixelSize: UI.Theme.fontPx(10, profileTab.fs)
                    enabled: !profileTab.isBusy && referenceField.text.trim() !== ""
                    onClicked: profileTab.install()
                }
            }

            Repeater {
                model: profileTab.profilePackages
                ToolRow {
                    id: row
                    required property var modelData
                    Layout.fillWidth: true
                    glyph: "ic_outline_box"
                    iconColor: profileTab.accentColor
                    title: modelData.name
                    detail: (modelData.package || "") + (modelData.source ? "  ·  " + modelData.source : "")
                    monoDetail: false
                    textColor: profileTab.textColor
                    fs: profileTab.fs
                    UI.ActionButton {
                        objectName: "upgrade-" + row.modelData.name
                        text: qsTr("Upgrade")
                        glyph: Qt.resolvedUrl("assets/ic_refresh.svg")
                        tip: qsTr("Upgrade %1").arg(row.modelData.name)
                        flatStyle: true
                        implicitHeight: 27
                        font.pixelSize: UI.Theme.fontPx(10, profileTab.fs)
                        enabled: !profileTab.isBusy
                        onClicked: profileTab.upgradeRequested(row.modelData.name)
                    }
                    UI.ActionButton {
                        objectName: "remove-" + row.modelData.name
                        text: profileTab.confirmingRemove === row.modelData.name ? qsTr("Really remove?") : qsTr("Remove")
                        glyph: Qt.resolvedUrl("assets/ic_delete.svg")
                        tip: qsTr("Remove %1 from your profile").arg(row.modelData.name)
                        flatStyle: true
                        implicitHeight: 27
                        font.pixelSize: UI.Theme.fontPx(10, profileTab.fs)
                        enabled: !profileTab.isBusy
                        onClicked: {
                            if (profileTab.confirmingRemove === row.modelData.name) {
                                profileTab.confirmingRemove = "";
                                profileTab.removeRequested(row.modelData.name);
                            } else {
                                profileTab.confirmingRemove = row.modelData.name;
                            }
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 25
                visible: !profileTab.isLoadingProfile && profileTab.profilePackages.length === 0
                text: qsTr("Install something with a flake reference like nixpkgs#hello or github:user/repo. Packages from your system configuration are not listed here, only the ones in your own profile.")
                color: "#91a4bd"
                font.pixelSize: UI.Theme.fontPx(11, profileTab.fs)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                lineHeight: 1.5
            }
        }
    }
}
