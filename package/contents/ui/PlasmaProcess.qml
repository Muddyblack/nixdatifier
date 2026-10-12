import QtQuick
import org.kde.plasma.plasma5support as P5Support

P5Support.DataSource {
    id: process
    engine: "executable"
    connectedSources: []
    property var callback: null
    property string command: ""
    property string sourceName: ""
    // The executable engine keys running processes by their command text. Two
    // identical commands at once would share one process, and one issued just
    // after could be answered with the earlier output or not at all, leaving
    // this job (and the spinner) waiting forever. A no-op `:` with a unique
    // tag makes every job its own source; the shell ignores it.
    function exec(cmd, cb) {
        command = cmd;
        callback = cb;
        sourceName = ": nixdatifier-" + Date.now().toString(36) + Math.random().toString(36).slice(2, 8) + "; " + cmd;
        connectSource(sourceName);
    }
    onNewData: (source, data) => {
        disconnectSource(sourceName);
        const cb = callback;
        callback = null;
        try {
            if (cb)
                cb(command, data.stdout || "", data.stderr || "", data["exit code"] || 0);
        } finally {
            destroy();
        }
    }
    Component.onDestruction: if (sourceName)
        disconnectSource(sourceName)
}
