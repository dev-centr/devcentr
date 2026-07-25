module modules.toolchain_advisor.settings_dialog;

import dlangui;
import dlangui.dialogs.dialog : Dialog, DialogFlag;
import modules.toolchain_advisor.settings;
import std.conv : to;

void showAdvisorSettingsDialog(Window parent, string dataRoot, string currentRepoUrl,
    void delegate(string newRepoUrl) onSave)
{
    auto dlg = new Dialog(UIString.fromRaw("Toolchain Advisor definitions"d), parent,
        DialogFlag.Popup | DialogFlag.Resizable);
    dlg.minWidth(560).minHeight(200);

    auto content = new VerticalLayout();
    content.layoutWidth(FILL_PARENT).padding(15);

    content.addChild(new TextWidget(null,
        UIString.fromRaw("Git repository URL for toolchain advisor definitions (SDL). DevCentr syncs via git clone/pull only—not HTTP download."d))
        .fontSize(9).textColor(0xAAAAAA).margins(Rect(0, 0, 0, 10)));

    content.addChild(new TextWidget(null, UIString.fromRaw("Definitions repo URL"d)).fontSize(10).fontWeight(700));
    auto repoEdit = new EditLine("advisorRepoUrl", to!dstring(currentRepoUrl));
    repoEdit.layoutWidth(FILL_PARENT).margins(Rect(0, 4, 0, 12));
    content.addChild(repoEdit);

    auto row = new HorizontalLayout();
    row.layoutWidth(FILL_PARENT);
    auto btnCancel = new Button(null, UIString.fromRaw("Cancel"d));
    btnCancel.click = delegate(Widget w) { dlg.close(); return true; };
    row.addChild(btnCancel);
    auto btnSave = new Button(null, UIString.fromRaw("Save"d));
    btnSave.click = delegate(Widget w) {
        AdvisorSettings s;
        s.definitionsRepoUrl = to!string(repoEdit.text);
        saveAdvisorSettings(dataRoot, s);
        dlg.close();
        if (onSave !is null)
            onSave(s.definitionsRepoUrl);
        return true;
    };
    row.addChild(btnSave);
    content.addChild(row);

    dlg.contentWidget = content;
    dlg.show();
}
