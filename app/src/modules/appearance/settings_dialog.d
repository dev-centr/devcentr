module modules.appearance.settings_dialog;

import dlangui;
import dlangui.dialogs.dialog : Dialog, DialogFlag;
import modules.appearance.settings;
import std.conv : to;

/// Appearance preferences: code / terminal monospace font and env-refresh behavior.
void showAppearanceSettingsDialog(Window parent, string dataRoot,
    void delegate(AppearanceSettings s) onSave = null)
{
    auto current = loadAppearanceSettings(dataRoot);

    auto dlg = new Dialog(UIString.fromRaw("Appearance"d), parent,
        DialogFlag.Popup | DialogFlag.Resizable);
    dlg.minWidth(520).minHeight(360);

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

    content.addChild(new TextWidget(null, UIString.fromRaw("Repository terminal"d))
        .fontSize(10).fontWeight(700).margins(Rect(0, 4, 0, 6)));

    content.addChild(new TextWidget(null,
        UIString.fromRaw("Shell preference (auto prefers Nushell when nu is on PATH)."d))
        .fontSize(9).textColor(0xAAAAAA).margins(Rect(0, 0, 0, 4)));

    auto shellCombo = new ComboBox("terminal_shell",
        [
            "auto"d,
            "nushell"d,
            "powershell"d,
            "cmd"d,
            "bash"d,
            "zsh"d,
            "fish"d,
            "sh"d
        ]);
    shellCombo.layoutWidth(FILL_PARENT);
    auto shellPref = normalizeTerminalShell(current.terminalShell);
    int shellIdx = 0;
    auto shellItems = [
        "auto", "nushell", "powershell", "cmd", "bash", "zsh", "fish", "sh"
    ];
    foreach (i, item; shellItems)
        if (item == shellPref)
            shellIdx = cast(int) i;
    shellCombo.selectedItemIndex = shellIdx;
    content.addChild(shellCombo);

    auto cbAutoRun = new CheckBox("env_refresh_autorun",
        UIString.fromRaw("Env refresh: inject and run (skip Enter)"d));
    cbAutoRun.checked = current.envRefreshAutoRun;
    cbAutoRun.margins(Rect(0, 10, 0, 4));
    content.addChild(cbAutoRun);

    content.addChild(new TextWidget(null,
        UIString.fromRaw("When unchecked, Refresh fills the command preview so you can learn the shell-specific recipe. Prefer OpenShellOrg env-refresh when installed."d))
        .fontSize(9).textColor(0x888888).margins(Rect(0, 0, 0, 12)));

    content.addChild(new TextWidget(null, UIString.fromRaw("File manager menu"d))
        .fontSize(10).fontWeight(700).margins(Rect(0, 4, 0, 6)));
    content.addChild(new TextWidget(null,
        UIString.fromRaw("DevCentr on folders: New File…, New Project…, New Installer…, Install in-place PATH, Open. Win11 prefers the modern menu; classic or Linux adapters when needed."d))
        .fontSize(9).textColor(0xAAAAAA).margins(Rect(0, 0, 0, 6)));

    import modules.shell_integration.explorer_menu : installExplorerMenu, uninstallExplorerMenu,
        explorerMenuStatusText;
    auto explorerStatus = new TextWidget(null,
        UIString.fromRaw(to!dstring(explorerMenuStatusText())));
    explorerStatus.fontSize(8).textColor(0x888888).margins(Rect(0, 0, 0, 6));
    content.addChild(explorerStatus);

    auto explorerRow = new HorizontalLayout();
    explorerRow.layoutWidth(FILL_PARENT).margins(Rect(0, 0, 0, 12));
    auto btnInstallExplorer = new Button(null, UIString.fromRaw("Install file-manager menu"d));
    btnInstallExplorer.click = delegate(Widget w) {
        auto msg = installExplorerMenu();
        explorerStatus.text = UIString.fromRaw(to!dstring(explorerMenuStatusText()));
        parent.showMessageBox(UIString.fromRaw("File-manager integration"d), UIString.fromRaw(to!dstring(msg)));
        return true;
    };
    auto btnRemoveExplorer = new Button(null, UIString.fromRaw("Remove"d));
    btnRemoveExplorer.click = delegate(Widget w) {
        auto msg = uninstallExplorerMenu();
        explorerStatus.text = UIString.fromRaw(to!dstring(explorerMenuStatusText()));
        parent.showMessageBox(UIString.fromRaw("File-manager integration"d), UIString.fromRaw(to!dstring(msg)));
        return true;
    };
    explorerRow.addChild(btnInstallExplorer);
    explorerRow.addChild(btnRemoveExplorer);
    content.addChild(explorerRow);

    auto row = new HorizontalLayout();
    row.layoutWidth(FILL_PARENT);
    auto btnCancel = new Button(null, UIString.fromRaw("Cancel"d));
    btnCancel.click = delegate(Widget w) { dlg.close(new Action(2)); return true; };
    row.addChild(btnCancel);

    auto btnSave = new Button(null, UIString.fromRaw("Save"d));
    btnSave.click = delegate(Widget w) {
        AppearanceSettings s = loadAppearanceSettings(dataRoot);
        s.codeFontFace = rbJetBrains.checked
            ? CODE_FONT_JETBRAINS_MONO
            : CODE_FONT_CASCADIA_MONO;
        s.envRefreshAutoRun = cbAutoRun.checked;
        auto idx = shellCombo.selectedItemIndex;
        if (idx >= 0 && idx < cast(int) shellItems.length)
            s.terminalShell = shellItems[idx];
        else
            s.terminalShell = "auto";
        saveAppearanceSettings(dataRoot, s);
        dlg.close(new Action(1));
        if (onSave !is null)
            onSave(s);
        return true;
    };
    row.addChild(btnSave);
    content.addChild(row);

    dlg.addChild(content);
    dlg.show();
}
