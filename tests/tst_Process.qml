import QtQuick
import QtTest
import "../package/contents/ui" as App

Item {
    id: scene
    property int liveProcesses: 0
    property int completions: 0
    Component {
        id: processComponent
        App.PlasmaProcess {
            Component.onCompleted: scene.liveProcesses++
            Component.onDestruction: scene.liveProcesses--
        }
    }
    TestCase {
        name: "ProcessLifetime"
        when: windowShown

        function test_completed_processes_are_released_data() {
            return [
                {
                    tag: "normal",
                    throws: false
                },
                {
                    tag: "callback error",
                    throws: true
                }
            ];
        }

        function test_completed_processes_are_released(data) {
            scene.completions = 0;
            for (let n = 0; n < 25; ++n) {
                if (data.throws)
                    ignoreWarning(/.*Error: deliberate callback failure.*/);
                const process = processComponent.createObject(scene);
                verify(process !== null);
                process.exec("printf lifetime-" + n, function (cmd, out, err, code) {
                    compare(code, 0);
                    compare(out, "lifetime-" + n);
                    scene.completions++;
                    if (data.throws)
                        throw new Error("deliberate callback failure");
                });
            }
            tryCompare(scene, "completions", 25);
            tryCompare(scene, "liveProcesses", 0);
        }
    }
}
