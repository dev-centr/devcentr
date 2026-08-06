module modules.shell_integration.modern_package;

version (Windows):

import std.algorithm : canFind;
import std.array : join;
import std.conv : to;
import std.file : exists, mkdirRecurse, thisExePath, copy, write;
import std.path : buildPath, dirName;
import std.process : executeShell;
import std.string : replace, strip;

/// Package family identity from AppxManifest.
enum sparsePackageName = "DevCentr.ShellExtension";
enum sparsePublisherCn = "CN=DevCentr Local";

private string exeDir()
{
    return dirName(thisExePath());
}

/// Locate repo/app shell assets relative to the running executable or source layout.
string shellAssetsRoot()
{
    auto beside = buildPath(exeDir(), "shell");
    if (exists(buildPath(beside, "sparse-package", "AppxManifest.xml")))
        return beside;

    // Running from app/ after dub build
    auto fromApp = buildPath(exeDir(), "..", "shell");
    if (exists(buildPath(fromApp, "sparse-package", "AppxManifest.xml")))
        return buildPath(exeDir(), "..", "shell");

    // Source tree: app/src/… → app/shell
    auto fromSrc = buildPath(dirName(dirName(dirName(exeDir()))), "shell");
    // Prefer known relative from thisExePath when cwd is app/
    auto candidates = [
        buildPath(exeDir(), "shell"),
        buildPath(dirName(exeDir()), "shell"),
        buildPath(exeDir(), "..", "app", "shell"),
    ];
    foreach (c; candidates)
    {
        if (exists(buildPath(c, "sparse-package", "AppxManifest.xml")))
            return c;
    }
    return beside;
}

bool isWindows11OrNewer()
{
    // RtlGetVersion via cmd is awkward; use [Environment]::OSVersion via PowerShell.
    auto r = executeShell(
        `powershell -NoProfile -Command "[System.Environment]::OSVersion.Version.Build"`);
    if (r.status != 0)
        return false;
    try
    {
        auto build = to!int(r.output.strip);
        return build >= 22000;
    }
    catch (Exception)
    {
        return false;
    }
}

bool modernDllPresent(string assetsRoot)
{
    auto built = buildPath(assetsRoot, "explorer_command", "build", "DevCentrExplorerCommand.dll");
    auto staged = buildPath(exeDir(), "DevCentrExplorerCommand.dll");
    return exists(built) || exists(staged);
}

bool modernPackageRegistered()
{
    auto r = executeShell(
        `powershell -NoProfile -Command "Get-AppxPackage -Name '` ~ sparsePackageName ~ `' | Select-Object -ExpandProperty PackageFullName"`);
    return r.status == 0 && r.output.strip.length > 0;
}

private void copyIfExists(string src, string dst)
{
    if (!exists(src))
        return;
    auto ddir = dirName(dst);
    if (!exists(ddir))
        mkdirRecurse(ddir);
    copy(src, dst);
}

/// Stage DLL + manifest beside the exe for ExternalLocation registration.
string stageModernPackageFiles()
{
    auto assets = shellAssetsRoot();
    auto dest = exeDir();
    string[] notes;

    auto dllSrc = buildPath(assets, "explorer_command", "build", "DevCentrExplorerCommand.dll");
    auto dllDst = buildPath(dest, "DevCentrExplorerCommand.dll");
    if (exists(dllSrc))
    {
        copy(dllSrc, dllDst);
        notes ~= "Staged DevCentrExplorerCommand.dll";
    }
    else if (!exists(dllDst))
        return "Modern host DLL missing. Build app/shell/explorer_command with build.ps1 first.";

    auto manSrc = buildPath(assets, "sparse-package", "AppxManifest.xml");
    auto manDst = buildPath(dest, "AppxManifest.xml");
    if (!exists(manSrc))
        return "AppxManifest.xml not found under " ~ assets;
    copy(manSrc, manDst);

    auto logoSrc = buildPath(assets, "sparse-package", "Assets", "StoreLogo.png");
    auto logoDst = buildPath(dest, "Assets", "StoreLogo.png");
    if (exists(logoSrc))
        copyIfExists(logoSrc, logoDst);
    else if (!exists(logoDst))
        notes ~= "Warning: StoreLogo.png missing";

    // Point DLL at this exe explicitly
    auto ini = buildPath(dest, "DevCentrShell.ini");
    write(ini, "[Shell]\r\nExePath=" ~ thisExePath() ~ "\r\n");

    return notes.join("; ");
}

string installModernExplorerMenu()
{
    if (!isWindows11OrNewer())
        return "OS build < 22000; modern menu unavailable.";

    auto stageMsg = stageModernPackageFiles();
    if (stageMsg.canFind("missing") || stageMsg.canFind("not found"))
        return stageMsg;

    auto dest = exeDir();
    auto man = buildPath(dest, "AppxManifest.xml");
    auto script = buildPath(dest, "DevCentr-register-sparse.ps1");
    write(script,
        "Add-AppxPackage -Path '" ~ man.replace("'", "''")
            ~ "' -ExternalLocation '" ~ dest.replace("'", "''")
            ~ "' -Register -ErrorAction Stop\n");
    auto r = executeShell(`powershell -NoProfile -ExecutionPolicy Bypass -File "` ~ script ~ `"`);
    if (r.status != 0)
        return "Modern package register failed:\n" ~ r.output.strip
            ~ "\n(Enable Developer Mode and/or sign the sparse package; see app/shell/README.adoc)";
    return "Modern Win11 Explorer menu registered (sparse package)."
        ~ (stageMsg.length ? "\n" ~ stageMsg : "");
}

string uninstallModernExplorerMenu()
{
    auto r = executeShell(
        `powershell -NoProfile -Command "Get-AppxPackage -Name '` ~ sparsePackageName
            ~ `' | Remove-AppxPackage -ErrorAction SilentlyContinue"`);
    if (r.status != 0 && r.output.strip.length)
        return "Modern package removal: " ~ r.output.strip;
    return "Modern sparse package removed (if it was installed).";
}
