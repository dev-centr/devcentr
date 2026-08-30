module modules.cli_tools.catalog;

import modules.cli_tools.model;
import std.file : readText, exists;
import std.json : JSONValue, parseJSON, JSONType;
import std.string : toLower;
import std.algorithm : canFind, filter;
import std.array : array, split, join;

private string jsonStr(JSONValue j, string key) {
    if (key !in j || j[key].type == JSONType.null_)
        return "";
    if (j[key].type == JSONType.string)
        return j[key].str;
    return "";
}

private bool jsonBool(JSONValue j, string key, bool defaultVal) {
    if (key !in j) return defaultVal;
    if (j[key].type == JSONType.true_) return true;
    if (j[key].type == JSONType.false_) return false;
    if (j[key].type == JSONType.string) {
        auto s = j[key].str.toLower;
        if (s == "true" || s == "yes" || s == "1") return true;
        if (s == "false" || s == "no" || s == "0") return false;
    }
    return defaultVal;
}

private string[] jsonStrList(JSONValue j, string key) {
    string[] result;
    if (key !in j) return result;
    if (j[key].type == JSONType.string) {
        result ~= j[key].str;
        return result;
    }
    if (j[key].type == JSONType.array) {
        foreach (v; j[key].array)
            if (v.type == JSONType.string)
                result ~= v.str;
    }
    return result;
}

CliToolsCatalog loadCliToolsCatalogFromJson(string jsonPath) {
    CliToolsCatalog cat;
    if (!exists(jsonPath))
        return cat;
    auto root = parseJSON(readText(jsonPath));
    if ("version" in root && root["version"].type == JSONType.integer)
        cat.version_ = cast(int)root["version"].integer;
    else if ("version" in root && root["version"].type == JSONType.float_)
        cat.version_ = cast(int)root["version"].floating;

    if ("contexts" in root && root["contexts"].type == JSONType.array) {
        foreach (ctx; root["contexts"].array) {
            CliToolContext c;
            c.id = jsonStr(ctx, "id");
            c.label = jsonStr(ctx, "label");
            c.family = jsonStr(ctx, "family");
            c.packageManager = jsonStr(ctx, "packageManager");
            c.mutableInstall = jsonBool(ctx, "mutable", true);
            c.detect = jsonStr(ctx, "detect");
            c.inherits = jsonStr(ctx, "inherits");
            if (c.id.length) cat.contexts ~= c;
        }
    }

    if ("tools" in root && root["tools"].type == JSONType.array) {
        foreach (tool; root["tools"].array) {
            CliToolEntry t;
            t.id = jsonStr(tool, "id");
            t.name = jsonStr(tool, "name");
            t.description = jsonStr(tool, "description");
            t.categories = jsonStrList(tool, "categories");
            t.homepage = jsonStr(tool, "homepage");
            t.docs = jsonStr(tool, "docs");
            t.verifyCommand = jsonStr(tool, "verifyCommand");
            t.launchCommand = jsonStr(tool, "launchCommand");
            if ("install" in tool && tool["install"].type == JSONType.array) {
                foreach (m; tool["install"].array) {
                    CliToolInstallMethod im;
                    im.context = jsonStr(m, "context");
                    im.command = jsonStr(m, "command");
                    im.interactive = jsonBool(m, "interactive", true);
                    im.mutableInstall = jsonBool(m, "mutable", true);
                    im.fallback = jsonBool(m, "fallback", false);
                    im.auditNote = jsonStr(m, "auditNote");
                    if (im.command.length) t.install ~= im;
                }
            }
            if (t.id.length) cat.tools ~= t;
        }
    }
    return cat;
}

CliToolEntry* findTool(CliToolsCatalog* cat, string toolId) {
    if (cat is null) return null;
    foreach (ref t; cat.tools)
        if (t.id == toolId) return &t;
    return null;
}

CliToolInstallMethod resolveInstallMethod(
    const ref CliToolEntry tool,
    string context,
    bool preferImmutable = true
) {
    CliToolInstallMethod[] exact;
    foreach (m; tool.install)
        if (m.context == context) exact ~= m;

    if (exact.length > 0) {
        if (preferImmutable) {
            auto imm = exact.filter!(m => !m.mutableInstall).array;
            if (imm.length > 0) return imm[0];
        }
        return exact[0];
    }

    string[] parts = context.split("/");
    while (parts.length > 1) {
        parts = parts[0 .. $ - 1];
        string parentCtx = parts.join("/");
        CliToolInstallMethod[] inherited;
        foreach (m; tool.install)
            if (m.context == parentCtx) inherited ~= m;
        if (inherited.length > 0) {
            if (preferImmutable) {
                auto imm = inherited.filter!(m => !m.mutableInstall).array;
                if (imm.length > 0) return imm[0];
            }
            return inherited[0];
        }
    }

    auto fallbacks = tool.install.filter!(m => m.fallback).array;
    if (fallbacks.length > 0) return fallbacks[0];
    return CliToolInstallMethod.init;
}

bool isToolInstalled(string verifyCommand) {
    if (verifyCommand.length == 0) return false;
    import std.process : executeShell, spawnShell, wait;
    version (Windows) {
        auto r = executeShell("cmd /c " ~ verifyCommand ~ " >nul 2>&1");
        return r.status == 0;
    } else {
        // Redirect inside the shell and don't capture output: reading a pipe here
        // can fail with EINTR once the GC/SDL signal handlers are installed.
        try
            return wait(spawnShell(verifyCommand ~ " >/dev/null 2>&1")) == 0;
        catch (Exception)
            return false;
    }
}
