pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    readonly property string aetherDir: Quickshell.env("AETHER_DIR")
    readonly property string qsDir: Quickshell.env("QS_DIR")
    readonly property string mainQml: Quickshell.env("MAIN_QML")

    readonly property string home: Quickshell.env("HOME")
    readonly property string xdgRuntimeDir: Quickshell.env("XDG_RUNTIME_DIR")

    readonly property string cacheDir: Quickshell.env("QS_CACHE_DIR") ? Quickshell.env("QS_CACHE_DIR") : (home + "/.cache/aether")
    readonly property string stateDir: Quickshell.env("QS_STATE_DIR") ? Quickshell.env("QS_STATE_DIR") : (home + "/.local/state/aether")
    readonly property string runDir: Quickshell.env("QS_RUN_DIR") ? Quickshell.env("QS_RUN_DIR") : ((xdgRuntimeDir !== "" ? xdgRuntimeDir : "/tmp") + "/aether")
    readonly property string logDir: Quickshell.env("QS_LOG_DIR") ? Quickshell.env("QS_LOG_DIR") : (runDir + "/logs")

    property var ensuredDirs: ({})

    function ensureDir(path) {
        if (!path)
            return path;
        if (root.ensuredDirs[path])
            return path;
        root.ensuredDirs[path] = true;
        Quickshell.execDetached(["mkdir", "-p", path]);
        return path;
    }

    function getCacheDir(widgetName) {
        if (!widgetName || widgetName === "aether" || cacheDir.endsWith("/" + widgetName))
            return ensureDir(cacheDir);
        var envPath = Quickshell.env("QS_CACHE_" + widgetName.toUpperCase());
        return ensureDir(envPath ? envPath : (cacheDir + "/" + widgetName));
    }

    function getStateDir(widgetName) {
        if (!widgetName || widgetName === "aether" || stateDir.endsWith("/" + widgetName))
            return ensureDir(stateDir);
        var envPath = Quickshell.env("QS_STATE_" + widgetName.toUpperCase());
        return ensureDir(envPath ? envPath : (stateDir + "/" + widgetName));
    }

    function getRunDir(widgetName) {
        if (!widgetName || widgetName === "aether" || runDir.endsWith("/" + widgetName))
            return ensureDir(runDir);
        var envPath = Quickshell.env("QS_RUN_" + widgetName.toUpperCase());
        return ensureDir(envPath ? envPath : (runDir + "/" + widgetName));
    }

    function getLogDir(widgetName) {
        if (!widgetName || widgetName === "aether" || logDir.endsWith("/" + widgetName))
            return ensureDir(logDir);
        var envPath = Quickshell.env("QS_LOG_" + widgetName.toUpperCase());
        return ensureDir(envPath ? envPath : (logDir + "/" + widgetName));
    }
}
