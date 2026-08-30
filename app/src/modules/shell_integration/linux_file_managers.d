module modules.shell_integration.linux_file_managers;

version (linux):

import std.algorithm : canFind;
import std.array : join;
import std.file : exists, mkdirRecurse, write, remove, readText, dirEntries, SpanMode;
import std.path : buildPath, expandTilde, dirName;
import std.process : environment;
import modules.util.proc : executeShell = executeShellRetry;
import std.file : thisExePath;
import std.string : replace, indexOf;

import modules.shell_integration.actions : fmActions;

private string xdgDataHome()
{
    auto v = environment.get("XDG_DATA_HOME", "");
    if (v.length)
        return v;
    return expandTilde("~/.local/share");
}

private string xdgConfigHome()
{
    auto v = environment.get("XDG_CONFIG_HOME", "");
    if (v.length)
        return v;
    return expandTilde("~/.config");
}

private string exeQuoted()
{
    auto p = thisExePath();
    return `"` ~ p ~ `"`;
}

private string execFor(string mode)
{
    // %f = selected folder (Desktop Entry / DES-EMA)
    return exeQuoted() ~ " --mode=" ~ mode ~ " --path=%f";
}

private void ensureDir(string path)
{
    if (!exists(path))
        mkdirRecurse(path);
}

private void writeText(string path, string content)
{
    ensureDir(dirName(path));
    write(path, content);
}

private void tryRemove(string path)
{
    if (exists(path))
        remove(path);
}

/// DES-EMA catalog under ~/.local/share/file-manager/actions/
string installDesemaActions()
{
    auto root = buildPath(xdgDataHome(), "file-manager", "actions");
    ensureDir(root);

    // Submenu
    writeText(buildPath(root, "devcentr-menu.desktop"),
`[Desktop Entry]
Type=Menu
Name=DevCentr
Tooltip=Create or open with DevCentr
Icon=folder
ItemsList=devcentr-new-file;devcentr-new-project;devcentr-new-installer;devcentr-emit-ci;devcentr-inplace-path;devcentr-open;
`);

    foreach (a; fmActions)
    {
        auto body =
`[Desktop Entry]
Type=Action
Name=` ~ a.label ~ `
Tooltip=` ~ a.label ~ `
Icon=folder
Profiles=` ~ a.desemaProfile ~ `;

[X-Action-Profile ` ~ a.desemaProfile ~ `]
Name=` ~ a.label ~ `
MimeTypes=inode/directory;
SelectionCount=< 2
Exec=` ~ execFor(a.mode) ~ `
`;
        writeText(buildPath(root, "devcentr-" ~ a.id ~ ".desktop"), body);
    }
    return "DES-EMA actions written to " ~ root;
}

string uninstallDesemaActions()
{
    auto root = buildPath(xdgDataHome(), "file-manager", "actions");
    tryRemove(buildPath(root, "devcentr-menu.desktop"));
    foreach (a; fmActions)
        tryRemove(buildPath(root, "devcentr-" ~ a.id ~ ".desktop"));
    return "DES-EMA DevCentr actions removed.";
}

bool desemaInstalled()
{
    return exists(buildPath(xdgDataHome(), "file-manager", "actions", "devcentr-menu.desktop"));
}

/// Dolphin / KDE service menus
string installDolphinServiceMenu()
{
    auto dirs = [
        buildPath(xdgDataHome(), "kio", "servicemenus"),
        buildPath(xdgDataHome(), "kservices6", "ServiceMenus"),
        buildPath(xdgDataHome(), "kservices5", "ServiceMenus"),
    ];
    // Prefer modern kio path; also write kservices6 for broader coverage
    string[] written;
    auto content =
`[Desktop Entry]
Type=Service
ServiceTypes=KonqPopupMenu/Plugin
MimeType=inode/directory;
Actions=NewFile;NewProject;NewInstaller;EmitCi;InPlacePath;Open;
X-KDE-Priority=TopLevel
X-KDE-Submenu=DevCentr

[Desktop Action NewFile]
Name=New File…
Exec=` ~ execFor("new-file") ~ `

[Desktop Action NewProject]
Name=New Project…
Exec=` ~ execFor("new-project") ~ `

[Desktop Action NewInstaller]
Name=New Installer Project…
Exec=` ~ execFor("new-installer") ~ `

[Desktop Action EmitCi]
Name=New Installer CI pipeline…
Exec=` ~ execFor("emit-ci") ~ `

[Desktop Action InPlacePath]
Name=Install in-place (add to PATH)
Exec=` ~ execFor("inplace-path") ~ `

[Desktop Action Open]
Name=Open folder in DevCentr
Exec=` ~ execFor("open") ~ `
`;
    foreach (d; dirs[0 .. 2]) // kio + kservices6
    {
        ensureDir(d);
        auto path = buildPath(d, "devcentr.desktop");
        write(path, content);
        written ~= path;
    }
    return "Dolphin service menus:\n" ~ written.join("\n");
}

string uninstallDolphinServiceMenu()
{
    auto paths = [
        buildPath(xdgDataHome(), "kio", "servicemenus", "devcentr.desktop"),
        buildPath(xdgDataHome(), "kservices6", "ServiceMenus", "devcentr.desktop"),
        buildPath(xdgDataHome(), "kservices5", "ServiceMenus", "devcentr.desktop"),
    ];
    foreach (p; paths)
        tryRemove(p);
    return "Dolphin DevCentr service menus removed.";
}

/// Nemo actions
string installNemoActions()
{
    auto dir = buildPath(xdgDataHome(), "nemo", "actions");
    ensureDir(dir);
    string[] written;
    foreach (a; fmActions)
    {
        auto path = buildPath(dir, "devcentr-" ~ a.id ~ ".nemo_action");
        auto body =
`[Nemo Action]
Active=true
Name=` ~ a.label ~ `
Comment=` ~ a.label ~ `
Exec=` ~ exeQuoted() ~ ` --mode=` ~ a.mode ~ ` --path=%F
Selection=s
Extensions=dir;
Dependencies=devcentr;
`;
        write(path, body);
        written ~= path;
    }
    return "Nemo actions:\n" ~ written.join("\n");
}

string uninstallNemoActions()
{
    auto dir = buildPath(xdgDataHome(), "nemo", "actions");
    foreach (a; fmActions)
        tryRemove(buildPath(dir, "devcentr-" ~ a.id ~ ".nemo_action"));
    return "Nemo DevCentr actions removed.";
}

/// Thunar UCA — merge idempotent marker blocks
private enum thunarBegin = "<!-- BEGIN DevCentr -->";
private enum thunarEnd = "<!-- END DevCentr -->";

string installThunarActions()
{
    auto path = buildPath(xdgConfigHome(), "Thunar", "uca.xml");
    ensureDir(dirName(path));
    string block = thunarBegin ~ "\n";
    foreach (a; fmActions)
    {
        block ~=
`  <action>
    <icon>folder</icon>
    <name>` ~ a.label ~ `</name>
    <unique-id>devcentr-` ~ a.id ~ `</unique-id>
    <command>` ~ exeQuoted() ~ ` --mode=` ~ a.mode ~ ` --path=%f</command>
    <description>` ~ a.label ~ `</description>
    <patterns>*</patterns>
    <directories/>
  </action>
`;
    }
    block ~= thunarEnd;

    string doc;
    if (exists(path))
    {
        doc = readText(path);
        auto b = doc.indexOf(thunarBegin);
        auto e = doc.indexOf(thunarEnd);
        if (b >= 0 && e > b)
        {
            e += thunarEnd.length;
            doc = doc[0 .. b] ~ block ~ doc[e .. $];
        }
        else
        {
            // Insert before </actions>
            auto close = doc.indexOf("</actions>");
            if (close >= 0)
                doc = doc[0 .. close] ~ block ~ "\n" ~ doc[close .. $];
            else
                doc = `<?xml version="1.0" encoding="UTF-8"?>` ~ "\n"
                    ~ `<actions>` ~ "\n" ~ block ~ "\n</actions>\n";
        }
    }
    else
    {
        doc = `<?xml version="1.0" encoding="UTF-8"?>` ~ "\n"
            ~ `<actions>` ~ "\n" ~ block ~ "\n</actions>\n";
    }
    write(path, doc);
    return "Thunar custom actions merged into " ~ path;
}

string uninstallThunarActions()
{
    auto path = buildPath(xdgConfigHome(), "Thunar", "uca.xml");
    if (!exists(path))
        return "Thunar uca.xml not present.";
    auto doc = readText(path);
    auto b = doc.indexOf(thunarBegin);
    auto e = doc.indexOf(thunarEnd);
    if (b < 0 || e < b)
        return "No DevCentr Thunar block found.";
    e += thunarEnd.length;
    write(path, doc[0 .. b] ~ doc[e .. $]);
    return "Thunar DevCentr actions removed.";
}

/// Nautilus scripts (no Python extension required)
string installNautilusScripts()
{
    auto dir = buildPath(xdgDataHome(), "nautilus", "scripts", "DevCentr");
    ensureDir(dir);
    string[] written;
    foreach (a; fmActions)
    {
        auto path = buildPath(dir, a.label.replace("…", "..."));
        // Nautilus passes selected paths via env / args — use NAUTILUS_SCRIPT_SELECTED_FILE_PATHS
        auto body =
`#!/bin/sh
# DevCentr — ` ~ a.id ~ `
TARGET="$1"
if [ -z "$TARGET" ] && [ -n "$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS" ]; then
  TARGET=$(printf '%s' "$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS" | head -n1)
fi
if [ -z "$TARGET" ]; then
  TARGET=$(pwd)
fi
exec ` ~ exeQuoted() ~ ` --mode=` ~ a.mode ~ ` --path="$TARGET"
`;
        write(path, body);
        // best-effort +x
        executeShell(`chmod +x '` ~ path.replace(`'`, `'\\''`) ~ `'`);
        written ~= path;
    }
    return "Nautilus scripts:\n" ~ written.join("\n");
}

string uninstallNautilusScripts()
{
    auto dir = buildPath(xdgDataHome(), "nautilus", "scripts", "DevCentr");
    if (!exists(dir))
        return "Nautilus DevCentr scripts not present.";
    foreach (e; dirEntries(dir, SpanMode.shallow))
        tryRemove(e.name);
    return "Nautilus DevCentr scripts removed.";
}

string installLinuxFileManagerMenus()
{
    string[] parts;
    parts ~= installDesemaActions();
    parts ~= installDolphinServiceMenu();
    parts ~= installNemoActions();
    parts ~= installThunarActions();
    parts ~= installNautilusScripts();
    return "Linux file-manager menus installed:\n" ~ parts.join("\n\n");
}

string uninstallLinuxFileManagerMenus()
{
    string[] parts;
    parts ~= uninstallDesemaActions();
    parts ~= uninstallDolphinServiceMenu();
    parts ~= uninstallNemoActions();
    parts ~= uninstallThunarActions();
    parts ~= uninstallNautilusScripts();
    return "Linux file-manager menus removed:\n" ~ parts.join("\n");
}

bool linuxFileManagerMenusInstalled()
{
    return desemaInstalled()
        || exists(buildPath(xdgDataHome(), "kio", "servicemenus", "devcentr.desktop"))
        || exists(buildPath(xdgDataHome(), "nemo", "actions", "devcentr-new-file.nemo_action"))
        || exists(buildPath(xdgDataHome(), "nautilus", "scripts", "DevCentr"));
}
