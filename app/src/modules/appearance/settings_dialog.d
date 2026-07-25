module modules.appearance.settings_dialog;

import dlangui;
import dlangui.dialogs.dialog : Dialog, DialogFlag;
import modules.appearance.settings;

/// Appearance preferences: code / terminal monospace font.
void showAppearanceSettingsDialog(Window parent, string dataRoot,
    void delegate(AppearanceSettings s) onSave = null)
{
    auto current = loadAppearanceSettings(dataRoot);

    auto dlg = new Dialog(UIString.fromRaw("Appearance"d), parent,
        DialogFlag.Popup | DialogFlag.Resizable);
    dlg.minWidth(480).minHeight(240);

    auto content = new VerticalLayout();
    content.layoutWidth(FILL_PARENT).padding(15);

    content.addChild(new TextWidget(null,
        UIString.fromRaw("Code and terminal font. Cascadia Mono is the default (no ligatures — better for tables and grids). JetBrains Mono is the other supported choice."d))
        .fontSize(9).textColor(0xAAAAAA).margins(Rect(0, 0, 0, 12)));

    content.addChild(new TextWidget(null, UIString.fromRaw("Monospace font"d))
        .fontSize(10).fontWeight(700).margins(Rect(0, 0, 0, 6)));

    auto rbCascadia = new RadioButton("font_cascadia",
        UIString.fromRaw("Cascadia Mono (recommended default)"d));
    auto rbJetBrains = new RadioButton("font_jetbrains",
        UIString.fromRaw("JetBrains Mono"d));

    if (current.codeFontFace == CODE_FONT_JETBRAINS_MONO)
        rbJetBrains.checked = true;
    else
        rbCascadia.checked = true;

    content.addChild(rbCascadia);
    content.addChild(rbJetBrains);

    content.addChild(new TextWidget(null,
        UIString.fromRaw("Install the font on your OS if glyphs fall back to Consolas/Courier. New terminal blocks pick up the choice immediately; reopen open panels if needed."d))
        .fontSize(9).textColor(0x888888).margins(Rect(0, 12, 0, 12)));

    auto row = new HorizontalLayout();
    row.layoutWidth(FILL_PARENT);
    auto btnCancel = new Button(null, UIString.fromRaw("Cancel"d));
    btnCancel.click = delegate(Widget w) { dlg.close(); return true; };
    row.addChild(btnCancel);

    auto btnSave = new Button(null, UIString.fromRaw("Save"d));
    btnSave.click = delegate(Widget w) {
        AppearanceSettings s;
        s.codeFontFace = rbJetBrains.checked
            ? CODE_FONT_JETBRAINS_MONO
            : CODE_FONT_CASCADIA_MONO;
        saveAppearanceSettings(dataRoot, s);
        dlg.close();
        if (onSave !is null)
            onSave(s);
        return true;
    };
    row.addChild(btnSave);
    content.addChild(row);

    dlg.contentWidget = content;
    dlg.show();
}
