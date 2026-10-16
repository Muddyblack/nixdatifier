import QtQuick
import QtTest
import "../package/contents/ui/shared" as UI

Item {
    width: 600
    height: 400
    Item {
        id: original
        width: 350
        Item {
            id: details
            x: 40
            y: 80
            width: original.width - 52
            implicitHeight: 900
            height: implicitHeight
        }
    }
    UI.DetailWindow {
        id: detailWindow
        detailItem: details
    }
    TestCase {
        name: "DetailWindow"
        when: windowShown
        function test_open_resize_close_restores_bindings() {
            detailWindow.open();
            tryCompare(detailWindow, "visible", true);
            verify(details.parent !== original);
            tryVerify(() => details.width > 350);
            detailWindow.width = 750;
            tryCompare(details, "width", 718);
            detailWindow.close();
            tryCompare(details, "parent", original);
            compare(details.x, 40);
            compare(details.y, 80);
            compare(details.width, 298);
            original.width = 400;
            compare(details.width, 348);
            detailWindow.open();
            tryCompare(detailWindow, "visible", true);
            detailWindow.close();
            tryCompare(details, "parent", original);
        }
    }
}
