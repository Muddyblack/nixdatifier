import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "shared" as UI

PlasmoidItem {
    id: plasmoidRoot
    Layout.minimumWidth: 380
    Layout.minimumHeight: 420
    Layout.preferredWidth: plasmoid.configuration.popupWidth
    Layout.preferredHeight: plasmoid.configuration.popupHeight
    Plasmoid.backgroundHints: plasmoid.configuration.showBg ? PlasmaCore.Types.NoBackground : PlasmaCore.Types.DefaultBackground
    hideOnWindowDeactivate: !core.pinned
    toolTipMainText: core.toolTipMainText
    toolTipSubText: core.toolTipSubText
    Component {
        id: plasmaExecutor
        PlasmaProcess {}
    }
    Component {
        id: plasmaIcon
        Kirigami.Icon {}
    }
    Component.onCompleted: {
        UI.Theme.iconDelegate = plasmaIcon;
        UI.Theme.systemTextColor = Kirigami.Theme.textColor;
        UI.Theme.systemBackgroundColor = Kirigami.Theme.backgroundColor;
    }
    Engine {
        id: core
        settings: plasmoid.configuration
        executor: plasmaExecutor
        // Desktop containment displays the full view without opening a popup.
        expanded: plasmoidRoot.expanded || (Plasmoid.formFactor === PlasmaCore.Types.Planar && plasmoidRoot.visible && !!plasmoidRoot.fullRepresentationItem)
        onConfigureRequested: plasmoid.internalAction("configure").trigger()
    }
    compactRepresentation: CompactView {
        accentColor: core.accentColor
        textColor: core.textColor
        activeGenNum: core.activeGenNum
        flakeUpdates: core.flakeUpdates
        isBusy: core.isBusy
        isLoadingGens: core.isLoadingGens
        isSpinning: core.isSpinning
        compactStyle: plasmoid.configuration.compactStyle
        compactShowBadge: plasmoid.configuration.compactShowBadge
        enableMotion: plasmoid.configuration.enableMotion && plasmoid.configuration.compactAnimateIcon
        iconStyle: core.iconStyle
        onToggleExpanded: plasmoidRoot.expanded = !plasmoidRoot.expanded
    }
    fullRepresentation: ApplicationView {
        id: popupView
        engine: core
        Layout.minimumWidth: 380
        Layout.minimumHeight: 480
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        // Wait for the host's initial layout before remembering user resizes.
        property bool rememberGeometry: false
        Timer {
            interval: 700
            running: plasmoidRoot.expanded
            onTriggered: popupView.rememberGeometry = true
        }
        Timer {
            id: saveGeometry
            interval: 250
            onTriggered: {
                if (!plasmoidRoot.expanded || !popupView.rememberGeometry)
                    return;
                plasmoid.configuration.popupWidth = Math.round(popupView.width);
                plasmoid.configuration.popupHeight = Math.round(popupView.height);
            }
        }
        onVisibleChanged: if (!visible)
            rememberGeometry = false
        onWidthChanged: if (rememberGeometry && width >= 380)
            saveGeometry.restart()
        onHeightChanged: if (rememberGeometry && height >= 480)
            saveGeometry.restart()
    }
}
