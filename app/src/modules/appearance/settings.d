module modules.appearance.settings;

import std.file : exists, readText, write, mkdirRecurse;
import std.path : buildPath, dirName;
import std.json : JSONValue, parseJSON, JSONType;
import std.process : environment;

/// Allowed code / terminal monospace faces in DevCentr.
enum string CODE_FONT_CASCADIA_MONO = "Cascadia Mono";
enum string CODE_FONT_JETBRAINS_MONO = "JetBrains Mono";

struct AppearanceSettings
{
    /// Primary monospace face for terminals and code panels. Default: Cascadia Mono.
    string codeFontFace = CODE_FONT_CASCADIA_MONO;
}

bool isAllowedCodeFont(string face)
{
    return face == CODE_FONT_CASCADIA_MONO || face == CODE_FONT_JETBRAINS_MONO;
}

string normalizeCodeFontFace(string face)
{
    if (isAllowedCodeFont(face))
        return face;
    return CODE_FONT_CASCADIA_MONO;
}

/// Comma-separated faces for dlangui (tries each until one exists).
string codeFontFaceList(string primary)
{
    auto p = normalizeCodeFontFace(primary);
    if (p == CODE_FONT_JETBRAINS_MONO)
        return "JetBrains Mono,Cascadia Mono,Consolas,Courier New";
    return "Cascadia Mono,JetBrains Mono,Consolas,Courier New";
}

string appearanceDataRoot()
{
    version (Windows)
    {
        auto home = environment.get("USERPROFILE");
        if (home.length == 0)
            home = environment.get("HOME");
        return buildPath(home, ".dev-center");
    }
    else
    {
        return buildPath(environment.get("HOME"), ".dev-center");
    }
}

AppearanceSettings loadAppearanceSettings(string dataRoot = null)
{
    if (dataRoot is null || dataRoot.length == 0)
        dataRoot = appearanceDataRoot();
    auto path = buildPath(dataRoot, "ui-settings.json");
    AppearanceSettings s;
    if (!exists(path))
        return s;
    try
    {
        auto j = parseJSON(readText(path));
        if ("codeFontFace" in j && j["codeFontFace"].type == JSONType.string)
            s.codeFontFace = normalizeCodeFontFace(j["codeFontFace"].str);
    }
    catch (Exception) { }
    return s;
}

void saveAppearanceSettings(string dataRoot, AppearanceSettings s)
{
    auto path = buildPath(dataRoot, "ui-settings.json");
    auto dir = dirName(path);
    if (!exists(dir))
        mkdirRecurse(dir);
    s.codeFontFace = normalizeCodeFontFace(s.codeFontFace);
    JSONValue j;
    j["codeFontFace"] = JSONValue(s.codeFontFace);
    write(path, j.toPrettyString());
}
