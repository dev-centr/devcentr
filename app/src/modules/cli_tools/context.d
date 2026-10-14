module modules.cli_tools.context;

import modules.cli_tools.catalog : isToolInstalled;
import modules.cli_tools.model;
import std.algorithm : canFind;
import std.array : join;
import std.string : split, strip;

private bool detectCommandWorks(string detectCmd)
{
    if (detectCmd.length == 0)
        return false;
    // Catalog detect strings look like `where winget` / `which brew`.
    // Strip the locator; PATH-check the target only (no cmd.exe console flash).
    auto parts = detectCmd.strip.split();
    if (parts.length == 0)
        return false;
    size_t i = 0;
    if (parts[0] == "where" || parts[0] == "which")
        i = 1;
    if (i >= parts.length)
        return false;
    return isToolInstalled(parts[i .. $].join(" "));
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
