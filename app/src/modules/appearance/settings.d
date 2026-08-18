module modules.appearance.settings;

import std.algorithm : equal;
import std.file : exists, readText, write, mkdirRecurse;
import std.path : buildPath, dirName;
import std.json : JSONValue, parseJSON, JSONType;
import std.process : environment;
import std.string : strip, toLower;

/// Allowed code / terminal monospace faces in DevCentr.
enum string CODE_FONT_CASCADIA_MONO = "Cascadia Mono";
enum string CODE_FONT_JETBRAINS_MONO = "JetBrains Mono";
enum string CODE_FONT_FIRA_CODE = "Fira Code";
enum string CODE_FONT_IOSEVKA = "Iosevka";
/// Primary Monaspace cut for Appearance; other variants are install-detection fallbacks.
enum string CODE_FONT_MONASPACE = "Monaspace Neon";

struct AppearanceSettings
{
    /// Primary monospace face for terminals and code panels. Default: Cascadia Mono.
    string codeFontFace = CODE_FONT_CASCADIA_MONO;
    /// Preview-only ligature demo line in Appearance (dlangui does not apply OpenType features).
    bool codeFontLigatures = false;
    /// When true, Refresh injects and runs the env refresh command without requiring Enter.
    bool envRefreshAutoRun = false;
    /// Terminal shell preference: auto | nushell | powershell | cmd | bash | zsh | fish | sh
    string terminalShell = "auto";
}

bool isAllowedCodeFont(string face)
{
    return face == CODE_FONT_CASCADIA_MONO
        || face == CODE_FONT_JETBRAINS_MONO
        || face == CODE_FONT_FIRA_CODE
        || face == CODE_FONT_IOSEVKA
        || face == CODE_FONT_MONASPACE;
}

string normalizeCodeFontFace(string face)
{
    auto f = face.strip;
    if (f.equal("GitHub Monaspace"))
        return CODE_FONT_MONASPACE;
    if (isAllowedCodeFont(f))
        return f;
    return CODE_FONT_CASCADIA_MONO;
}

string normalizeTerminalShell(string pref)
{
    auto p = pref.strip.toLower;
    foreach (allowed; [
            "auto", "nushell", "nu", "powershell", "pwsh", "cmd",
            "bash", "zsh", "fish", "sh"
        ])
    {
        if (p == allowed)
        {
            if (p == "nu")
                return "nushell";
            if (p == "pwsh")
                return "powershell";
            return p;
        }
    }
    return "auto";
}

/// Comma-separated faces for dlangui (tries each until one exists).
string codeFontFaceList(string primary)
{
    auto p = normalizeCodeFontFace(primary);
    if (p == CODE_FONT_JETBRAINS_MONO)
        return "JetBrains Mono,Cascadia Mono,Consolas,Courier New";
    if (p == CODE_FONT_FIRA_CODE)
        return "Fira Code,Cascadia Mono,JetBrains Mono,Consolas,Courier New";
    if (p == CODE_FONT_IOSEVKA)
        return "Iosevka,Iosevka Fixed,Cascadia Mono,JetBrains Mono,Consolas,Courier New";
    if (p == CODE_FONT_MONASPACE)
        return "Monaspace Neon,Monaspace Argon,Monaspace Radon,Monaspace Krypton,Monaspace Xenon,Cascadia Mono,JetBrains Mono,Consolas,Courier New";
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
        if ("codeFontLigatures" in j && j["codeFontLigatures"].type == JSONType.true_)
            s.codeFontLigatures = true;
        else if ("codeFontLigatures" in j && j["codeFontLigatures"].type == JSONType.false_)
            s.codeFontLigatures = false;
        if ("envRefreshAutoRun" in j && j["envRefreshAutoRun"].type == JSONType.true_)
            s.envRefreshAutoRun = true;
        else if ("envRefreshAutoRun" in j && j["envRefreshAutoRun"].type == JSONType.false_)
            s.envRefreshAutoRun = false;
        if ("terminalShell" in j && j["terminalShell"].type == JSONType.string)
            s.terminalShell = normalizeTerminalShell(j["terminalShell"].str);
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
    s.terminalShell = normalizeTerminalShell(s.terminalShell);

    JSONValue j = parseJSON("{}");
    if (exists(path))
    {
        try
        {
            auto loaded = parseJSON(readText(path));
            if (loaded.type == JSONType.object)
                j = loaded;
        }
        catch (Exception) { }
    }

    j["codeFontFace"] = JSONValue(s.codeFontFace);
    j["codeFontLigatures"] = JSONValue(s.codeFontLigatures);
    j["envRefreshAutoRun"] = JSONValue(s.envRefreshAutoRun);
    j["terminalShell"] = JSONValue(s.terminalShell);
    write(path, j.toPrettyString());
}
