module modules.content_create.installer_create;

import dlangui;
import dlangui.dialogs.dialog : Dialog, DialogFlag;
import std.conv : to;
import std.file : exists;
import std.process : executeShell;
import std.string : strip, splitLines;

/// Resolve easy-installer on PATH or common sibling location.
string findEasyInstaller()
{
    version (Windows)
    {
        auto r = executeShell(`where easy-installer 2>NUL`);
        if (r.status == 0 && r.output.strip.length)
            return r.output.splitLines[0].strip;
        foreach (c; [
            `C:\code\github.com\dev-centr\easy-installer\easy-installer.exe`,
        ])
            if (exists(c))
                return c;
    }
    else
    {
        auto r = executeShell(`command -v easy-installer`);
        if (r.status == 0 && r.output.strip.length)
            return r.output.splitLines[0].strip;
    }
    return "";
}

string runEasyInstaller(string[] args)
{
    auto exe = findEasyInstaller();
    if (!exe.length)
        return "easy-installer not found on PATH. Install from https://github.com/dev-centr/easy-installer/releases";
    string cmd = `"` ~ exe ~ `"`;
    foreach (a; args)
        cmd ~= ` "` ~ a ~ `"`;
    auto r = executeShell(cmd);
    if (r.status != 0)
        return r.output.length ? r.output : ("exit " ~ to!string(r.status));
    return r.output.length ? r.output : "OK";
}

void showNewInstallerDialog(Window parent, string folderPath)
{
    auto dlg = new Dialog(UIString.fromRaw("New Installer Project"d), parent,
        DialogFlag.Modal | DialogFlag.Resizable, 480, 220);
    auto root = new VerticalLayout();
    root.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).padding(12);
    root.addChild(new TextWidget(null,
        UIString.fromRaw("Creates installer.kdl via easy-installer (portable-zip default)."d))
        .fontSize(9).textColor(0xAAAAAA));
    root.addChild(new TextWidget(null, to!dstring("Folder: " ~ folderPath))
        .fontSize(8).textColor(0x888888).margins(Rect(0, 8, 0, 8)));

    auto pluginEdit = new EditLine("plugin");
    pluginEdit.text = "portable-zip"d;
    root.addChild(new TextWidget(null, "Plugin id:"d).fontSize(9));
    root.addChild(pluginEdit);

    auto row = new HorizontalLayout();
    auto ok = new Button(null, "Create"d);
    ok.click = delegate(Widget w) {
        auto plugin = to!string(pluginEdit.text).strip;
        if (!plugin.length)
            plugin = "portable-zip";
        auto msg = runEasyInstaller(["new-project", folderPath, "--plugin=" ~ plugin]);
        parent.showMessageBox(UIString.fromRaw("Installer Project"d), UIString.fromRaw(to!dstring(msg)));
        dlg.close(null);
        return true;
    };
    auto cancel = new Button(null, "Cancel"d);
    cancel.click = delegate(Widget w) { dlg.close(null); return true; };
    row.addChild(ok);
    row.addChild(cancel);
    root.addChild(row);
    dlg.addChild(root);
    dlg.show();
}

void runInPlacePath(Window parent, string folderPath)
{
    auto msg = runEasyInstaller(["inplace-path", "add", folderPath]);
    parent.showMessageBox(UIString.fromRaw("Install in-place (add to PATH)"d),
        UIString.fromRaw(to!dstring(msg)));
}
