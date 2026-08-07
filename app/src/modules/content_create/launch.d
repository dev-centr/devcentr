module modules.content_create.launch;

import dlangui;
import modules.content_create.ecosystem_tags : resolveInitialTags;
import modules.content_create.model : CreateContentOptions;
import modules.content_create.project_create : showNewProjectDialog;
import modules.content_create.ui : showNewFileLauncher;
import std.algorithm : startsWith;
import std.array : split;
import std.conv : to;
import std.string : strip;

struct LaunchArgs
{
    string mode; /// new-file | new-project | new-installer | emit-ci | inplace-path | open | ""
    string path;
    string[] tags;
}

LaunchArgs parseLaunchArgs(string[] args)
{
    LaunchArgs la;
    foreach (a; args)
    {
        if (a.startsWith("--mode="))
            la.mode = a["--mode=".length .. $].strip();
        else if (a.startsWith("--path="))
            la.path = a["--path=".length .. $].strip();
        else if (a.startsWith("--tags="))
        {
            auto raw = a["--tags=".length .. $].strip();
            foreach (t; raw.split(","))
            {
                auto s = t.strip();
                if (s.length)
                    la.tags ~= s;
            }
        }
    }
    return la;
}

/// Host window for specialized create modes (Explorer / CLI).
void runSpecializedMode(LaunchArgs la)
{
    import modules.content_create.installer_create : showNewInstallerDialog, runInPlacePath;

    if (la.mode == "inplace-path")
    {
        // Minimal host for message box
        auto win = Platform.instance.createWindow("DevCentr — Install in-place"d, null, WindowFlag.Resizable, 480, 200);
        win.mainWidget = new VerticalLayout();
        win.show();
        runInPlacePath(win, la.path);
        return;
    }

    auto title = la.mode == "new-project" ? "DevCentr — New Project"
        : la.mode == "emit-ci" ? "DevCentr — New Installer CI pipeline"
        : la.mode == "new-installer" ? "DevCentr — New Installer Project"
        : "DevCentr — New File";
    auto win = Platform.instance.createWindow(
        to!dstring(title),
        null,
        WindowFlag.Resizable,
        640, 480);
    auto root = new VerticalLayout();
    root.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).padding(20);
    root.addChild(new TextWidget(null, "DevCentr"d).fontSize(14).fontWeight(800));
    root.addChild(new TextWidget(null, to!dstring("Path: " ~ la.path)).fontSize(9).textColor(0x888888)
        .margins(Rect(0, 8, 0, 12)));
    win.mainWidget = root;
    win.show();

    if (la.mode == "new-project")
    {
        showNewProjectDialog(win, la.path, la.tags);
    }
    else if (la.mode == "new-installer" || la.mode == "emit-ci")
    {
        showNewInstallerDialog(win, la.path, la.mode == "emit-ci");
    }
    else
    {
        CreateContentOptions opts;
        opts.repoPath = la.path;
        auto inferred = resolveInitialTags(la.path, la.tags);
        opts.initialTags = inferred.tags;
        opts.tagSourceHint = inferred.hint;
        showNewFileLauncher(win, opts);
    }
}
