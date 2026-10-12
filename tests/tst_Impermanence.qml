import QtQuick
import QtQuick.Controls
import QtTest
import "../package/contents/ui" as App

Item {
    id: host
    width: 600
    height: 600
    App.ImpermanenceTab {
        id: tab
        anchors.fill: parent
        accentColor: "#91bcff"
        textColor: "#e6ecf5"
        fs: 1
        activeViewMode: "impermanence"
        impermanence: ({
                detected: true,
                areas: [
                    {
                        path: "/persist",
                        fsType: "btrfs",
                        total: 1000,
                        used: 500,
                        avail: 500
                    }
                ],
                entries: []
            })
    }
    SignalSpy {
        id: copySpy
        target: tab
        signalName: "copyToClipboard"
    }
    SignalSpy {
        id: listSpy
        target: tab
        signalName: "listRequested"
    }
    SignalSpy {
        id: modelSpy
        target: null
        signalName: "shownItemsChanged"
    }
    TestCase {
        name: "PersistentFolders"
        when: windowShown
        function item(name, size, newest) {
            return {
                path: "/persist/" + name,
                name: name,
                label: name,
                kind: "d",
                size: size,
                newest: newest,
                count: 1,
                flags: "",
                owner: "user"
            };
        }
        function init() {
            modelSpy.target = null;
            host.width = 600;
            host.height = 600;
            tab.fs = 1;
            tab.closeFolder();
            tab.setLens("folders");
            tab.search = "";
            tab.folderSearch = "";
            tab.sortBy = "size";
            tab.removalStates = ({});
            tab.isListing = false;
            tab.showDisks = false;
            tab.cleanup = {
                isError: false,
                temp: [
                    {
                        path: "/persist/cache",
                        label: "Application cache",
                        size: 90
                    },
                    {
                        path: "/persist/Trash",
                        label: "Trash",
                        size: 50
                    },
                    {
                        path: "/persist/draft.swp",
                        label: "Temporary file",
                        size: 30
                    },
                    {
                        path: "/persist/app.log.old",
                        label: "Rotated log",
                        size: 20
                    }
                ],
                stale: [
                    {
                        path: "/persist/photos",
                        size: 10,
                        newest: 1,
                        kind: "d"
                    }
                ]
            };
            tab.listing = {
                isError: false,
                dir: "/persist",
                area: "/persist",
                total: 60,
                files: 3,
                newest: 3,
                items: [item("alpha", 10, 3), item("beta", 30, 1), item("gamma", 20, 2)]
            };
            copySpy.clear();
            listSpy.clear();
            wait(20);
        }
        function test_cleanup_categories_copy_and_keyboard_selection() {
            tab.setLens("cleanup");
            wait(20);
            compare(tab.cleanupItems("cache").length, 1);
            compare(tab.cleanupItems("trash")[0].path, "/persist/Trash");
            compare(tab.cleanupItems("temporary")[0].path, "/persist/draft.swp");
            compare(tab.cleanupItems("logs")[0].path, "/persist/app.log.old");
            const row = findChild(tab, "cleanupEntry-0-cache");
            row.forceActiveFocus();
            keyClick(Qt.Key_Space);
            verify(tab.isSelected("/persist/cache"));
            const copy = findChild(row, "entryCopy");
            copy.forceActiveFocus();
            compare(copy.opacity, 1);
            keyClick(Qt.Key_Space);
            compare(copySpy.count, 1);
            compare(copySpy.signalArguments[0][0], "/persist/cache");
            const box = findChild(row, "entryCheckBox");
            box.forceActiveFocus();
            keyClick(Qt.Key_Space);
            verify(!tab.isSelected("/persist/cache"));
            const selectCaches = findChild(tab, "impermanenceSelectCaches");
            mouseClick(selectCaches);
            compare(tab.selectedCount, 1);
            verify(!tab.isSelected("/persist/Trash"));
            tab.toggleSelected(tab.cleanupItems("trash")[0], "trash");
            tab.reviewing = true;
            wait(20);
            const review = findChild(tab, "reviewEntry-0-trash");
            verify(review !== null);
            const reviewCopy = findChild(review, "entryCopy");
            reviewCopy.forceActiveFocus();
            keyClick(Qt.Key_Space);
            compare(copySpy.count, 2);
            compare(copySpy.signalArguments[1][0], "/persist/Trash");
        }
        function test_root_shortcut_and_tabs_work_with_keyboard() {
            const root = findChild(tab, "persistentRoot-0");
            verify(root.visible);
            root.forceActiveFocus();
            keyClick(Qt.Key_Return);
            compare(tab.openDir, "/persist");
            compare(listSpy.count, 1);
            const cleanup = findChild(tab, "impermanenceLens-cleanup");
            cleanup.forceActiveFocus();
            keyClick(Qt.Key_Space);
            compare(tab.lens, "cleanup");
        }
        function test_inside_search_sort_and_sticky_navigation() {
            tab.openFolder("/persist", "Persistent files");
            wait(20);
            compare(tab.shownItems[0].label, "beta");
            const search = findChild(tab, "impermanenceFolderSearch");
            search.forceActiveFocus();
            keyClick(Qt.Key_G);
            compare(tab.shownItems.length, 1);
            compare(tab.shownItems[0].label, "gamma");
            keyClick(Qt.Key_Escape);
            compare(tab.shownItems.length, 3);
            const sortButton = findChild(tab, "impermanenceFolderSort");
            mouseClick(sortButton);
            const menu = findChild(sortButton, "impermanenceFolderSortMenu");
            verify(menu !== null);
            tryCompare(menu, "opened", true);
            compare(menu.count, 3);
            mouseClick(menu.itemAt(2));
            compare(tab.sortBy, "name");
            compare(tab.shownItems[0].label, "alpha");
            tab.sortBy = "recent";
            compare(tab.shownItems[1].label, "gamma");
            const rows = [];
            for (let i = 0; i < 50; ++i)
                rows.push(item("folder" + i, i, i));
            tab.listing = Object.assign({}, tab.listing, {
                items: rows
            });
            wait(20);
            const navigation = findChild(tab, "impermanenceFolderNavigation");
            const y = navigation.mapToItem(tab, 0, 0).y;
            const scroll = findChild(tab, "impermanenceScroll");
            scroll.contentItem.contentY = 400;
            wait(20);
            compare(navigation.mapToItem(tab, 0, 0).y, y);
            verify(scroll.height > 250);
            host.width = 440;
            tab.fs = 1.2;
            wait(20);
            verify(search.width > 60);
            verify(scroll.height > 200);
        }
        function test_large_folder_renders_in_bounded_batches() {
            tab.openFolder("/persist", "Persistent files");
            const items = [];
            for (let i = 0; i < 250; ++i)
                items.push(item("entry" + i, i, i));
            tab.listing = Object.assign({}, tab.listing, {
                items: items
            });
            wait(20);
            const rows = findChild(tab, "impermanenceFolderRows");
            compare(rows.count, 60);
            const scroll = findChild(tab, "impermanenceScroll");
            scroll.contentItem.contentY = scroll.contentItem.contentHeight - scroll.contentItem.height;
            wait(20);
            mouseClick(findChild(tab, "impermanenceMoreFiles"));
            compare(rows.count, 120);
            tab.folderSearch = "entry24";
            compare(tab.folderLimit, 60);
            compare(rows.count, 11);
        }
        function test_progress_keeps_rows_and_failure_is_retryable() {
            tab.openFolder("/persist", "Persistent files");
            wait(20);
            modelSpy.target = tab;
            modelSpy.clear();
            tab.removalStates = {
                "/persist/beta": {
                    state: "deleting",
                    message: ""
                },
                "/persist/gamma": {
                    state: "queued",
                    message: ""
                }
            };
            compare(tab.shownItems.length, 3);
            compare(modelSpy.count, 0); // Status updates must not rebuild every delegate.
            tab.selectAll(tab.shownItems, "item");
            compare(tab.selectedCount, 1);
            verify(tab.isSelected("/persist/alpha"));
            tab.removalStates = {
                "/persist/beta": {
                    state: "deleted",
                    message: ""
                },
                "/persist/gamma": {
                    state: "failed",
                    message: "Permission denied"
                }
            };
            tryVerify(() => tab.shownItems.length === 2);
            const failed = findChild(tab, "folderEntry-gamma");
            verify(failed !== null);
            compare(failed.removal.message, "Permission denied");
            verify(!failed.working);
            tab.toggleSelected(tab.shownItems[0], "item");
            verify(tab.isSelected("/persist/gamma"));
        }
        function test_security_scrollbar_stays_at_edge_and_drags() {
            const findings = [];
            for (let i = 0; i < 114; ++i)
                findings.push({
                    severity: "medium",
                    category: "World-writable",
                    path: "/persist/folder" + i,
                    detail: "Anyone on this machine can change it"
                });
            tab.scan = {
                isError: false,
                findings: findings,
                clamav: false
            };
            tab.setLens("security");
            wait(50);
            const scroll = findChild(tab, "impermanenceScroll");
            const bar = scroll.ScrollBar.vertical;
            verify(bar.visible);
            verify(bar.size < 1);
            compare(bar.parent, scroll);
            compare(bar.height, scroll.availableHeight);
            compare(bar.x + bar.width, scroll.width);
            const thumbY = bar.topPadding + bar.contentItem.height / 2;
            mouseDrag(bar, bar.width / 2, thumbY, 0, 150);
            verify(scroll.contentItem.contentY > 0);
            compare(bar.mapToItem(scroll, 0, 0).y, scroll.topPadding);
            host.width = 440;
            host.height = 450;
            wait(20);
            compare(bar.height, scroll.availableHeight);
            compare(bar.x + bar.width, scroll.width);
            tab.scan = null;
        }
    }
}
