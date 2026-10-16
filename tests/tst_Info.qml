import QtQuick
import QtTest
import "../package/contents/ui" as App
import "../package/contents/code/ProjectInfo.js" as Project
import "../package/contents/code/ProjectInfoRequests.js" as Requests
import "../package/contents/ui/SettingsSchema.js" as Schema
import "../package/contents/ui/SettingsTheme.js" as Theme

Item {
    id: host
    width: 650
    height: 750
    App.Settings {
        id: cfg
    }
    Component {
        id: editorComponent
        App.SettingsEditor {
            width: 620
            height: 700
            infoOnlineEnabled: false
        }
    }
    TestCase {
        name: "ProjectInfo"
        when: windowShown

        function test_project_metadata_and_versions() {
            compare(Project.licenseId, "MIT");
            compare(Project.statistics.length, 3);
            compare(Project.statistics[2].href, "https://www.opendesktop.org/p/2360222");
            verify(decodeURIComponent(Project.statistics[2].url).includes("search=nixdatifier"));
            compare(Project.funding.length, 3);
            compare(Project.releaseStatus("2.0.3", "2.0.4"), "Update available");
            compare(Project.releaseStatus("2.0.3", "2.0.3"), "Up to date");
            compare(Project.releaseVersion('{"tag_name":"v2.0.4","draft":false,"prerelease":false}'), "2.0.4");
        }

        function test_installed_version_comes_from_host() {
            const editor = createTemporaryObject(editorComponent, host, {
                settings: cfg,
                currentVersion: "9.8.7",
                currentTab: 4
            });
            verify(editor !== null);
            const loader = findChild(editor, "projectInfoLoader");
            tryVerify(function () {
                return loader.item !== null;
            });
            compare(loader.item.currentVersion, "9.8.7");
            loader.item.latestVersion = "9.8.7";
            compare(loader.item.versionStatus, "Up to date");
            editor.currentVersion = "9.8.6";
            compare(loader.item.currentVersion, "9.8.6");
            compare(loader.item.versionStatus, "Update available");
            editor.currentVersion = "";
            compare(loader.item.versionStatus, "Version comparison unavailable");
        }

        function test_settings_tabs_and_narrow_layout() {
            const editor = createTemporaryObject(editorComponent, host, {
                settings: cfg,
                hyprland: true
            });
            verify(editor !== null);
            for (const tab of editor.navigation.filter(index => index !== 4)) {
                editor.currentTab = tab;
                wait(20);
                const fields = Schema.fields.concat(editor.placementFields).filter(f => editor.sectionFor(f) === editor.tabKeys[tab]);
                for (const field of fields) {
                    const item = findChild(editor, "setting_" + field.key);
                    verify(item !== null, field.key);
                    verify(item.height > 0, field.key);
                }
            }
            editor.currentTab = 5;
            editor.width = 344;
            wait(20);
            verify(findChild(editor, "setting_panelEdgeOffset") !== null);
            editor.currentTab = 3;
            wait(20);
            verify(findChild(editor, "setting_accentColor").stacked);
            editor.query = "flake";
            wait(20);
            verify(findChild(editor, "setting_flakePath") !== null);
            verify(findChild(editor, "setting_accentColor") === null);
        }

        function test_dropdown_selection_and_slider_input() {
            const editor = createTemporaryObject(editorComponent, host, {
                settings: cfg
            });
            const choice = findChild(editor, "choice_defaultView");
            verify(choice !== null);
            choice.forceActiveFocus();
            choice.popup.open();
            tryCompare(choice.popup, "visible", true);
            keyClick(Qt.Key_Down);
            keyClick(Qt.Key_Return);
            compare(cfg.defaultView, "updates");
            cfg.defaultView = "timeline";
            editor.currentTab = 3;
            const slider = findChild(editor, "slider_fontScale");
            verify(slider !== null);
            slider.forceActiveFocus();
            keyClick(Qt.Key_Right);
            verify(cfg.fontScale > 1);
            cfg.fontScale = 1;
        }

        function test_settings_palette_tracks_widget_colours() {
            const editor = createTemporaryObject(editorComponent, host, {
                settings: cfg
            });
            const previousAccent = cfg.accentColor;
            const previousBackground = cfg.bgColor;
            try {
                cfg.accentColor = "#e4a5ce";
                compare(String(editor.tone.brand), "#e4a5ce");
                compare(String(findChild(editor, "setting_flakePath").tone.brand), "#e4a5ce");
                cfg.bgColor = "#ffffff";
                verify(Theme.contrast(editor.tone.panel, editor.tone.text) >= 4.5);
                cfg.bgColor = "#151923";
                verify(Theme.contrast(editor.tone.panel, editor.tone.text) >= 4.5);
            } finally {
                cfg.accentColor = previousAccent;
                cfg.bgColor = previousBackground;
            }
        }

        function test_studio_number_edit_commits_to_settings() {
            const editor = createTemporaryObject(editorComponent, host, {
                settings: cfg
            });
            const number = findChild(editor, "number_checkInterval");
            verify(number !== null);
            const previous = cfg.checkInterval;
            number.contentItem.forceActiveFocus();
            number.contentItem.selectAll();
            keyClick(Qt.Key_7);
            keyClick(Qt.Key_2);
            keyClick(Qt.Key_0);
            keyClick(Qt.Key_0);
            keyClick(Qt.Key_Return);
            compare(cfg.checkInterval, 7200);
            cfg.checkInterval = previous;
        }

        function test_info_is_destroyed_on_hide_and_tab_change() {
            const editor = createTemporaryObject(editorComponent, host, {
                settings: cfg
            });
            verify(editor !== null);
            const loader = findChild(editor, "projectInfoLoader");
            const tab = findChild(editor, "settingsTab_General");
            const tabY = tab.mapToItem(editor, 0, 0).y;
            for (let i = 0; i < 10; i++) {
                editor.currentTab = 4;
                tryVerify(function () {
                    return loader.item !== null;
                });
                verify(findChild(editor, "stat_kde") !== null);
                verify(findChild(editor, "statIcon_kde") !== null);
                verify(findChild(editor, "fundingIcon_github") !== null);
                compare(findChild(editor, "projectInfoWakeTimer").running, false);
                compare(findChild(editor, "projectInfoWakeTimer").repeat, false);
                wait(0);
                compare(tab.mapToItem(editor, 0, 0).y, tabY);
                editor.visible = false;
                tryCompare(loader, "active", false);
                verify(loader.item === null);
                editor.visible = true;
                tryVerify(function () {
                    return loader.item !== null;
                });
                editor.currentTab = 0;
                verify(loader.item === null);
            }
        }

        function test_connection_recovers_after_more_than_three_failures() {
            const pending = [];
            let now = 0;
            let state;
            function makeRequest() {
                const request = {
                    readyState: 0,
                    status: 0,
                    responseText: "",
                    onreadystatechange: null,
                    aborted: false,
                    open: function () {},
                    send: function () {},
                    abort: function () {
                        this.aborted = true;
                    },
                    getResponseHeader: function () {
                        return null;
                    },
                    complete: function (status, body) {
                        this.status = status;
                        this.responseText = body;
                        this.readyState = 4;
                        this.onreadystatechange();
                    }
                };
                pending.push(request);
                return request;
            }
            const project = {
                latestReleaseUrl: "release",
                statistics: [],
                contributorsUrl: "contributors",
                releaseVersion: Project.releaseVersion,
                contributors: Project.contributors
            };
            const client = Requests.create(project, makeRequest, function () {
                return now;
            }, function (next) {
                state = next;
            });
            for (let attempt = 0; attempt < 5; attempt++) {
                client.tick();
                compare(pending.length, (attempt + 1) * 2);
                pending[pending.length - 2].complete(0, "");
                pending[pending.length - 1].complete(0, "");
                verify(state.networkMessage.includes("Retrying automatically"));
                now += attempt === 0 ? 15000 : attempt === 1 ? 60000 : 300000;
            }
            client.tick();
            compare(pending.length, 12);
            pending[10].complete(200, '{"tag_name":"v2.0.4"}');
            pending[11].complete(200, '[]');
            compare(state.latestVersion, "2.0.4");
            compare(state.networkMessage, "");
            compare(client.nextWakeDelay(), -1);
            now += 300000;
            client.tick();
            compare(pending.length, 12);
            client.dispose();
        }

        function test_slow_requests_timeout_and_rate_limits_are_respected() {
            let now = 0;
            const pending = [];
            const project = {
                latestReleaseUrl: "release",
                statistics: [],
                contributorsUrl: "contributors",
                releaseVersion: Project.releaseVersion,
                contributors: Project.contributors
            };
            const client = Requests.create(project, function () {
                const request = {
                    readyState: 0,
                    status: 0,
                    responseText: "",
                    aborted: false,
                    open: function () {},
                    send: function () {},
                    abort: function () {
                        this.aborted = true;
                    },
                    getResponseHeader: function (name) {
                        return name === "Retry-After" ? "600" : null;
                    }
                };
                pending.push(request);
                return request;
            }, function () {
                return now;
            }, function () {});
            client.tick();
            now = 19000;
            client.tick();
            verify(!pending[0].aborted);
            compare(client.nextWakeDelay(), 1000);
            now = 20000;
            client.tick();
            verify(pending[0].aborted);
            compare(pending[0].onreadystatechange, null);
            compare(client.nextWakeDelay(), 15000);
            now = 35000;
            client.tick();
            compare(pending.length, 4);
            for (let i = 2; i < 4; i++) {
                pending[i].status = 429;
                pending[i].readyState = 4;
                pending[i].onreadystatechange();
            }
            now += 300000;
            client.tick();
            client.refresh();
            compare(pending.length, 4);
            now = 635000;
            client.tick();
            compare(pending.length, 6);
            client.dispose();
            verify(pending[4].aborted);
            compare(client.nextWakeDelay(), -1);
        }

        function test_successful_load_stops_waking_after_refresh_cooldown() {
            let now = 0;
            let requests = 0;
            let state;
            const project = {
                latestReleaseUrl: "release",
                statistics: [],
                contributorsUrl: "contributors",
                releaseVersion: Project.releaseVersion,
                contributors: Project.contributors
            };
            const client = Requests.create(project, function () {
                requests++;
                return {
                    url: "",
                    readyState: 0,
                    status: 200,
                    responseText: "",
                    open: function (method, url) {
                        this.url = url;
                    },
                    send: function () {
                        this.responseText = this.url === "release" ? '{"tag_name":"v2.0.3"}' : '[]';
                        this.readyState = 4;
                        this.onreadystatechange();
                    },
                    abort: function () {}
                };
            }, function () {
                return now;
            }, function (next) {
                state = next;
            });
            client.tick();
            compare(requests, 2);
            compare(client.nextWakeDelay(), 60000);
            verify(!state.canRefresh);
            now = 60000;
            client.tick();
            verify(state.canRefresh);
            compare(client.nextWakeDelay(), -1);
            compare(requests, 2);
            client.dispose();
        }

        function test_requests_release_callbacks_and_stop_after_dispose() {
            const pending = [];
            let now = 0;
            function makeRequest() {
                const request = {
                    onreadystatechange: null,
                    aborted: false,
                    open: function () {},
                    send: function () {},
                    abort: function () {
                        this.aborted = true;
                    }
                };
                pending.push(request);
                return request;
            }
            const client = Requests.create(Project, makeRequest, function () {
                return now;
            }, function () {});
            compare(pending.length, 0);
            client.tick();
            compare(pending.length, 5);
            client.pause();
            for (const request of pending) {
                verify(request.aborted);
                compare(request.onreadystatechange, null);
            }
            now = 16000;
            client.tick();
            compare(pending.length, 10);
            client.dispose();
            for (const request of pending) {
                verify(request.aborted);
                compare(request.onreadystatechange, null);
            }
            now = 100000;
            client.tick();
            client.refresh();
            compare(pending.length, 10);
        }
    }
}
