module modules.appearance.font_install;

import modules.appearance.settings;
import modules.cli_tools.cache : CliToolsCatalogCache;
import modules.project_recognizer.profiles_dir : codeHiveRoots;
import std.file : exists;
import std.path : absolutePath, buildPath, dirName;
import std.process : environment, execute, spawnProcess, Pid;
import std.string : strip;

/// True when `scriptbook` resolves on PATH.
bool scriptbookOnPath()
{
    try
    {
        version (Windows)
            auto r = execute(["where", "scriptbook"]);
        else
            auto r = execute(["which", "scriptbook"]);
        return r.status == 0 && r.output.strip.length > 0;
    }
    catch (Exception)
    {
        return false;
    }
}

/// Playbook filename for an Appearance code font face.
string fontInstallPlaybookFile(string face)
{
    face = normalizeCodeFontFace(face);
    if (face == CODE_FONT_CASCADIA_MONO)
        return "install-cascadia-mono.cmk";
    if (face == CODE_FONT_JETBRAINS_MONO)
        return "install-jetbrains-mono.cmk";
    if (face == CODE_FONT_FIRA_CODE)
        return "install-fira-code.cmk";
    if (face == CODE_FONT_IOSEVKA)
        return "install-iosevka.cmk";
    if (face == CODE_FONT_MONASPACE)
        return "install-monaspace.cmk";
    return null;
}

/// Preferred `--format` for Scriptbook on this host (empty = let Scriptbook list options).
string scriptbookInstallFormat()
{
    version (Windows)
        return "choco";
    else version (OSX)
        return "brew";
    else
    {
        if (commandOnPath("nix"))
            return "nix";
        return "";
    }
}

private bool commandOnPath(string name)
{
    try
    {
        version (Windows)
            auto r = execute(["where", name]);
        else
            auto r = execute(["which", name]);
        return r.status == 0 && r.output.strip.length > 0;
    }
    catch (Exception)
    {
        return false;
    }
}

/// Resolve `equivalence-rules-cli/catalog/tools.sdl` for font install playbooks.
string resolveFontCatalogPath(string dataRoot)
{
    auto cache = new CliToolsCatalogCache(buildPath(dataRoot, "equivalence-rules-cli"));
    cache.updateCache(false);
    auto cached = cache.cachedCatalogSdlPath;
    if (exists(cached))
        return absolutePath(cached);

    foreach (hive; codeHiveRoots())
    {
        auto p = buildPath(hive, "github.com", "dev-centr", "equivalence-rules-cli", "catalog", "tools.sdl");
        if (exists(p))
            return absolutePath(p);
    }
    return "";
}

/// Resolve a Scriptbook font playbook for the given Appearance face.
string resolveFontPlaybookPath(string face, string dataRoot)
{
    auto file = fontInstallPlaybookFile(face);
    if (file is null || file.length == 0)
        return "";

    foreach (hive; codeHiveRoots())
    {
        auto p = buildPath(hive, "github.com", "dev-centr", "scriptbook", "examples", "fonts", file);
        if (exists(p))
            return absolutePath(p);
    }

    import std.file : getcwd, thisExePath;
    string[] devCandidates = [
        buildPath(getcwd(), "..", "..", "scriptbook", "examples", "fonts", file),
        buildPath(getcwd(), "..", "scriptbook", "examples", "fonts", file),
        buildPath(dirName(thisExePath()), "..", "..", "scriptbook", "examples", "fonts", file),
    ];
    foreach (p; devCandidates)
    {
        if (exists(p))
            return absolutePath(p);
    }
    return "";
}

struct FontInstallLaunch
{
    bool ok;
    string message;
    Pid pid;
}

/// Spawn `scriptbook run` for the selected Appearance face. Returns a user-facing status message.
FontInstallLaunch launchFontInstall(string face, string dataRoot)
{
    if (!scriptbookOnPath())
        return FontInstallLaunch(false, "scriptbook is not on PATH.", Pid.init);

    auto playbook = resolveFontPlaybookPath(face, dataRoot);
    if (playbook.length == 0)
        return FontInstallLaunch(false,
            "Font playbook not found. Check out dev-centr/scriptbook (examples/fonts/).", Pid.init);

    auto catalog = resolveFontCatalogPath(dataRoot);
    if (catalog.length == 0)
        return FontInstallLaunch(false,
            "Catalog tools.sdl not found. Sync equivalence-rules-cli or set CODE_ROOT/code hive.", Pid.init);

    string[] args = ["scriptbook", "run", playbook, "--catalog", catalog, "--yes"];
    auto format = scriptbookInstallFormat();
    if (format.length)
        args ~= ["--format", format];

    try
    {
        auto pid = spawnProcess(args);
        return FontInstallLaunch(true,
            "Started Scriptbook install for " ~ normalizeCodeFontFace(face)
            ~ ". Preview refreshes when install finishes.", pid);
    }
    catch (Exception e)
    {
        return FontInstallLaunch(false, "Could not start scriptbook: " ~ e.msg, Pid.init);
    }
}

/// Tooltip / status when Install is disabled or limited.
string fontInstallAvailabilityHint(string face, string dataRoot)
{
    if (!scriptbookOnPath())
        return "Install scriptbook and add it to PATH to run font playbooks from Appearance.";
    if (resolveFontPlaybookPath(face, dataRoot).length == 0)
        return "Scriptbook font playbook not found (dev-centr/scriptbook/examples/fonts/).";
    if (resolveFontCatalogPath(dataRoot).length == 0)
        return "equivalence-rules-cli catalog/tools.sdl not found.";
    return "";
}
