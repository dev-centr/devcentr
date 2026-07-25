module modules.cli_tools.context;

import modules.cli_tools.model;
import std.process : execute;
import std.algorithm : canFind;

private bool detectCommandWorks(string detectCmd) {
    if (detectCmd.length == 0) return false;
    version (Windows) {
        auto r = execute(["cmd", "/c", detectCmd ~ " >nul 2>&1"]);
        return r.status == 0;
    } else {
        auto r = execute(["sh", "-c", detectCmd ~ " >/dev/null 2>&1"]);
        return r.status == 0;
    }
}

/// Pick the best host context for install resolution (immutable contexts first when preferImmutable).
string detectHostContext(const ref CliToolsCatalog catalog, bool preferImmutable = true) {
    CliToolContext[] matches;
    foreach (c; catalog.contexts) {
        if (c.detect.length == 0) continue;
        if (!detectCommandWorks(c.detect)) continue;
        matches ~= c;
    }

    if (matches.length == 0) {
        foreach (c; catalog.contexts)
            if (c.id == "default/npm-global" && detectCommandWorks("which npm"))
                return c.id;
        return "default/curl-script";
    }

    if (preferImmutable) {
        foreach (c; matches)
            if (!c.mutableInstall) return c.id;
    }

    string[] priority = [
        "windows/winget", "windows/scoop", "macos/homebrew",
        "linux/debian/default", "linux/fedora/default", "linux/arch/default",
        "linux/alpine/default", "linux/homebrew",
    ];
    foreach (pid; priority)
        foreach (c; matches)
            if (c.id == pid) return c.id;

    return matches[0].id;
}

string contextLabel(const ref CliToolsCatalog catalog, string contextId) {
    foreach (c; catalog.contexts)
        if (c.id == contextId) return c.label.length ? c.label : c.id;
    return contextId;
}
