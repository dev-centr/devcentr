module modules.content_create.project_create;

import dlangui;
import dlangui.dialogs.dialog : Dialog, DialogFlag;
import modules.content_create.ecosystem_tags : resolveInitialTags;
import std.array : join;
import std.conv : to;
import std.file : exists, mkdirRecurse, write;
import std.path : buildPath;
import std.string : strip;

/// Lightweight New Project: folder + README + empty .gitignore.
void showNewProjectDialog(Window parent, string parentDir, string[] initialTags = null)
{
    if (parentDir.length == 0)
        parentDir = ".";

    auto inferred = resolveInitialTags(parentDir, initialTags);
    auto tags = inferred.tags;

    auto dlg = new Dialog(UIString.fromRaw("New Project"d), parent,
        DialogFlag.Popup | DialogFlag.Resizable);
    dlg.minWidth(pointsToPixels(360)).minHeight(pointsToPixels(210));

    auto content = new VerticalLayout();
    content.layoutWidth(FILL_PARENT).padding(15);

    content.addChild(new TextWidget(null, UIString.fromRaw("Parent folder"d)).fontSize(10).fontWeight(700));
    auto parentEdit = new EditLine("parentDir", to!dstring(parentDir));
    parentEdit.layoutWidth(FILL_PARENT).margins(Rect(0, 4, 0, 10));
    content.addChild(parentEdit);

    content.addChild(new TextWidget(null, UIString.fromRaw("Project name"d)).fontSize(10).fontWeight(700));
    auto nameEdit = new EditLine("projectName", "my-project"d);
    nameEdit.layoutWidth(FILL_PARENT).margins(Rect(0, 4, 0, 10));
    content.addChild(nameEdit);

    content.addChild(new TextWidget(null,
        UIString.fromRaw(to!dstring("Ecosystem tags: " ~ tags.join(", ") ~ " (" ~ inferred.hint ~ ")")))
        .fontSize(8).textColor(0x888888).margins(Rect(0, 0, 0, 12)));

    auto row = new HorizontalLayout();
    auto cancel = new Button(null, "Cancel"d);
    auto create = new Button(null, "Create"d);
    row.addChild(cancel);
    row.addChild(create);
    content.addChild(row);
    dlg.addChild(content);

    cancel.click = delegate(Widget w) { dlg.close(new Action(2)); return true; };
    create.click = delegate(Widget w) {
        auto parentPath = to!string(parentEdit.text).strip();
        auto name = to!string(nameEdit.text).strip();
        if (name.length == 0)
        {
            parent.showMessageBox(UIString.fromRaw("New Project"d), UIString.fromRaw("Enter a project name."d));
            return true;
        }
        auto dest = buildPath(parentPath, name);
        try
        {
            if (!exists(parentPath))
                mkdirRecurse(parentPath);
            if (exists(dest))
            {
                parent.showMessageBox(UIString.fromRaw("New Project"d),
                    UIString.fromRaw(to!dstring("Already exists: " ~ dest)));
                return true;
            }
            mkdirRecurse(dest);
            bool preferCmk = false;
            foreach (t; tags)
                if (t == "docs" || t == "d")
                    preferCmk = true;
            if (preferCmk)
                write(buildPath(dest, "README.cmk"), "# " ~ name ~ "\n\nNew project.\n\n:: toc\n");
            else
                write(buildPath(dest, "README.md"), "# " ~ name ~ "\n\nNew project.\n");
            write(buildPath(dest, ".gitignore"), "# Add ignore rules\n");
        }
        catch (Exception e)
        {
            parent.showMessageBox(UIString.fromRaw("New Project failed"d), UIString.fromRaw(to!dstring(e.msg)));
            return true;
        }
        dlg.close(new Action(1));
        parent.showMessageBox(UIString.fromRaw("Created"d),
            UIString.fromRaw(to!dstring("Created " ~ dest
                ~ ". Open it from Browse Projects or Explorer → Open folder in DevCentr.")));
        return true;
    };

    dlg.show();
}
