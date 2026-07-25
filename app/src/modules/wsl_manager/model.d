module modules.wsl_manager.model;

import std.algorithm : canFind, filter, startsWith, splitter;
import std.array : array, appender;
import std.conv : to;
import std.file : exists;
import std.path : buildPath;
import std.process : execute, spawnProcess;
import std.string : splitLines, toLower, strip;

/// One installed WSL distribution from `wsl -l -v`.
struct WslDistro
{
    string name;
    string state;   /// Running / Stopped / …
    string version_; /// 1 or 2
    bool isDefault;
}

/// Educational blurb matched to a distro name.
struct DistroGuideEntry
{
    string id;
    string[] matchTokens; /// substrings matched against lowercased distro name
    string title;
    string role;
    string summary;
    string preferWhen;
    string avoidWhen;
}

/// Bundle of guide copy + doc URLs.
struct DistroGuide
{
    string docsComparisonUrl;
    string docsSetupUrl;
    string wslSettingsDocsUrl;
    string microsoftWslDocsUrl;
    string intro;
    DistroGuideEntry[] distros;
}

DistroGuideEntry findGuideForName(const DistroGuide guide, string distroName)
{
    string lower = toLower(distroName);
    DistroGuideEntry wildcard;
    foreach (e; guide.distros)
    {
        foreach (tok; e.matchTokens)
        {
            if (tok == "*")
            {
                wildcard = e;
                continue;
            }
            if (lower.canFind(toLower(tok)))
                return e;
        }
    }
    return wildcard;
}

/// `wsl -l -v` on Windows often emits UTF-16LE; strip NULs so line parsing works.
string decodeWslListOutput(string raw)
{
    if (raw.length == 0)
        return raw;
    auto buf = appender!string();
    foreach (char c; raw)
    {
        if (c != '\0')
            buf.put(c);
    }
    return buf.data;
}

WslDistro[] listInstalledDistros()
{
    WslDistro[] result;
    version (Windows)
    {
        auto res = execute(["wsl", "-l", "-v"]);
        // wsl returns 0 even when listing; non-zero if WSL missing
        string text = decodeWslListOutput(res.output);
        foreach (line; text.splitLines)
        {
            string s = line.strip;
            if (s.length == 0)
                continue;
            string lower = toLower(s);
            if (lower.startsWith("name") && lower.canFind("state"))
                continue; // header
            if (lower.startsWith("windows subsystem"))
                continue;

            WslDistro d;
            d.isDefault = s.startsWith("*");
            if (d.isDefault)
                s = s[1 .. $].strip;

            // Columns are whitespace-separated: NAME STATE VERSION
            auto parts = s.splitter().filter!(p => p.length > 0).array;
            if (parts.length < 2)
                continue;
            d.name = parts[0].idup;
            d.state = parts[1].idup;
            d.version_ = parts.length >= 3 ? parts[2].idup : "";
            // Skip empty placeholder rows
            if (d.name.length == 0)
                continue;
            result ~= d;
        }
    }
    return result;
}

bool setDefaultDistro(string name, out string errorMessage)
{
    errorMessage = "";
    version (Windows)
    {
        auto res = execute(["wsl", "--set-default", name]);
        if (res.status != 0)
        {
            errorMessage = decodeWslListOutput(res.output).strip;
            if (errorMessage.length == 0)
                errorMessage = "wsl --set-default failed (exit " ~ to!string(res.status) ~ ")";
            return false;
        }
        return true;
    }
    else
    {
        errorMessage = "WSL management is only available on Windows.";
        return false;
    }
}

bool wslAvailable()
{
    version (Windows)
    {
        auto res = execute(["where", "wsl"]);
        return res.status == 0 && res.output.strip.length > 0;
    }
    else
        return false;
}

/// Try to launch the official WSL Settings GUI; fall back to Microsoft docs.
bool openWslSettings(out string openedVia)
{
    openedVia = "";
    version (Windows)
    {
        string[] candidates = [
            buildPath(environmentGet("ProgramFiles"), "WSL", "wslsettings.exe"),
            buildPath(environmentGet("LocalAppData"), "Microsoft", "WindowsApps", "wslsettings.exe"),
        ];
        foreach (p; candidates)
        {
            if (p.length > 0 && exists(p))
            {
                spawnProcess([p]);
                openedVia = p;
                return true;
            }
        }
        // Start-menu app alias / shell execute by display name often works when exe path varies
        auto start = execute(["cmd", "/c", "start", "", "wslsettings:"]);
        if (start.status == 0)
        {
            openedVia = "wslsettings:";
            return true;
        }
        auto start2 = execute(["cmd", "/c", "start", "", "WSL Settings"]);
        if (start2.status == 0)
        {
            openedVia = "WSL Settings (Start)";
            return true;
        }
    }
    return false;
}

private string environmentGet(string key)
{
    import std.process : environment;
    try
        return environment.get(key, "");
    catch (Exception)
        return "";
}
