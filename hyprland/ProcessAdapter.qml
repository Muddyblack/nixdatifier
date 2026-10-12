import QtQuick
import Quickshell.Io

Process {
    id: process
    property var callback: null
    property string sourceCommand: ""
    stdout: StdioCollector {
        id: output
    }
    stderr: StdioCollector {
        id: errors
    }
    function exec(cmd, cb) {
        sourceCommand = cmd;
        callback = cb;
        command = ["bash", "-c", cmd];
        running = true;
    }
    property bool _finished: false
    function finish(out, err, exitCode) {
        if (_finished)
            return;
        _finished = true;
        const cb = callback;
        callback = null;
        try {
            if (cb)
                cb(sourceCommand, out, err, exitCode);
        } finally {
            destroy();
        }
    }
    onExited: (exitCode, exitStatus) => finish(output.text, errors.text, exitCode)
    // FailedToStart changes running without emitting exited; without this the
    // job and its caller's busy flag would stay stuck forever.
    onRunningChanged: if (!running && callback)
        finish("", "Could not start bash", 127)
}
