import QtQuick
import "." as UI
import QtQuick.Controls.Basic

ComboBox {
    id: control
    property real fs: 1
    property color textColor: Theme.textColor
    property color accentColor: Theme.highlightColor
    implicitWidth: 140
    implicitHeight: 31 * fs
    leftPadding: 10
    rightPadding: 28
    topPadding: 5
    bottomPadding: 5
    font.pixelSize: 10 * fs
    textRole: "number"
    valueRole: "number"
    hoverEnabled: true
    function labelAt(index) {
        const entry = model && index >= 0 ? model[index] : null;
        if (!entry)
            return "—";
        return "#" + entry.number + (entry.booted ? qsTr(" · Booted") : entry.active ? qsTr(" · Next boot") : "");
    }
    function colorAt(index) {
        const entry = model && index >= 0 ? model[index] : null;
        return entry && entry.booted ? Theme.positive : entry && entry.active ? Theme.changed : textColor;
    }
    displayText: labelAt(currentIndex)
    contentItem: Text {
        objectName: "generationPickerText"
        text: control.displayText
        textFormat: Text.PlainText
        color: control.colorAt(control.currentIndex)
        font: control.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Icon {
        x: control.width - width - 10
        y: (control.height - height) / 2
        width: 11
        height: 11
        source: Qt.resolvedUrl("../assets/ic_chevron_down.svg")
        isMask: true
        color: Theme.muted
    }
    background: Rectangle {
        radius: 6
        color: control.hovered ? "#09ffffff" : "#05ffffff"
        border.color: control.activeFocus ? control.accentColor : Theme.line
    }
    delegate: ItemDelegate {
        id: option
        required property int index
        objectName: "generationOption-" + index
        width: ListView.view ? ListView.view.width : control.width
        implicitHeight: 32 * control.fs
        highlighted: control.highlightedIndex === index
        hoverEnabled: control.hoverEnabled
        text: control.labelAt(index)
        contentItem: Text {
            text: option.text
            textFormat: Text.PlainText
            color: control.colorAt(option.index)
            font: control.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: 4
            color: option.highlighted || option.hovered ? Theme.wash(control.accentColor, .14) : "transparent"
        }
    }
    popup: Popup {
        // Keep pointer focus on the panel surface while HyprlandFocusGrab is active.
        popupType: Popup.Item
        y: control.height + 4
        width: control.width
        implicitHeight: Math.min(options.contentHeight + 8, 240 * control.fs)
        padding: 4
        margins: 6
        contentItem: ListView {
            id: options
            clip: true
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            highlightMoveDuration: 0
            ScrollBar.vertical: UI.ScrollBar {}
        }
        background: Rectangle {
            color: "#1b2330"
            border.color: "#29a3b9de"
            radius: 7
        }
    }
}
