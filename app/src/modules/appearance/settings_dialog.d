module modules.appearance.settings_dialog;

import dlangui;
import dlangui.dialogs.dialog : Dialog, DialogFlag;
import modules.appearance.font_install;
import modules.appearance.fonts;
import modules.appearance.settings;
import std.conv : to;
import std.process : Pid, tryWait;

private final class FontInstallWatcher : Widget
{
    Pid _pid = Pid.init;
    ulong _timerId;
    void delegate(bool success) _onDone;

    this()
    {
        super(null);
        visibility = Visibility.Gone;
    }

    void watch(Pid pid, void delegate(bool success) onDone)
    {
        _pid = pid;
        _onDone = onDone;
        if (_timerId)
            cancelTimer(_timerId);
        _timerId = setTimer(500);
    }

    override bool onTimer(ulong id)
    {
        if (id != _timerId || _pid is Pid.init)
            return false;

        auto result = tryWait(_pid);
        if (!result.terminated)
            return true;

        cancelTimer(_timerId);
        _timerId = 0;
        _pid = Pid.init;
        if (_onDone !is null)
            _onDone(result.status == 0);
        return false;
    }
}

private string selectedCodeFontFace(RadioButton rbCascadia, RadioButton rbJetBrains,
    RadioButton rbFira, RadioButton rbIosevka, RadioButton rbMonaspace)
{
    if (rbJetBrains.checked)
        return CODE_FONT_JETBRAINS_MONO;
    if (rbFira.checked)
        return CODE_FONT_FIRA_CODE;
    if (rbIosevka.checked)
        return CODE_FONT_IOSEVKA;
    if (rbMonaspace.checked)
        return CODE_FONT_MONASPACE;
    return CODE_FONT_CASCADIA_MONO;
}

private void setCodeFontRadio(string face, RadioButton rbCascadia, RadioButton rbJetBrains,
    RadioButton rbFira, RadioButton rbIosevka, RadioButton rbMonaspace)
{
    face = normalizeCodeFontFace(face);
    rbCascadia.checked = face == CODE_FONT_CASCADIA_MONO;
    rbJetBrains.checked = face == CODE_FONT_JETBRAINS_MONO;
    rbFira.checked = face == CODE_FONT_FIRA_CODE;
    rbIosevka.checked = face == CODE_FONT_IOSEVKA;
    rbMonaspace.checked = face == CODE_FONT_MONASPACE;
}

/// Appearance preferences: code / terminal monospace font and env-refresh behavior.
void showAppearanceSettingsDialog(Window parent, string dataRoot,
    void delegate(AppearanceSettings s) onSave = null)
{
    auto current = loadAppearanceSettings(dataRoot);

    auto dlg = new Dialog(UIString.fromRaw("Appearance"d), parent,
        DialogFlag.Popup | DialogFlag.Resizable);
    dlg.minWidth(560).minHeight(580);

    auto content = new VerticalLayout();
    content.layoutWidth(FILL_PARENT).padding(15);

    content.addChild(new TextWidget(null,
        UIString.fromRaw("Code and terminal font. Cascadia Mono is the default (no ligatures — better for tables and grids). Fira Code and Monaspace are ligature-capable cuts; the preview toggle only affects the ligature demo line."d))
        .fontSize(9).textColor(0xAAAAAA).margins(Rect(0, 0, 0, 12)));

    content.addChild(new TextWidget(null, UIString.fromRaw("Monospace font"d))
        .fontSize(10).fontWeight(700).margins(Rect(0, 0, 0, 6)));

    auto rbCascadia = new RadioButton("font_cascadia",
        UIString.fromRaw("Cascadia Mono (recommended default)"d));
    auto rbJetBrains = new RadioButton("font_jetbrains",
        UIString.fromRaw("JetBrains Mono"d));
    auto rbFira = new RadioButton("font_fira",
        UIString.fromRaw("Fira Code"d));
    auto rbIosevka = new RadioButton("font_iosevka",
        UIString.fromRaw("Iosevka"d));
    auto rbMonaspace = new RadioButton("font_monaspace",
        UIString.fromRaw("GitHub Monaspace (Neon)"d));

    setCodeFontRadio(current.codeFontFace, rbCascadia, rbJetBrains, rbFira, rbIosevka, rbMonaspace);

    content.addChild(rbCascadia);
    content.addChild(rbJetBrains);
    content.addChild(rbFira);
    content.addChild(rbIosevka);
    content.addChild(rbMonaspace);

    auto fontStatus = new TextWidget(null, UIString.fromRaw(""d));
    fontStatus.fontSize(9).textColor(0xCC8844).margins(Rect(0, 8, 0, 4));
    content.addChild(fontStatus);

    content.addChild(new TextWidget(null, UIString.fromRaw("Preview"d))
        .fontSize(10).fontWeight(700).margins(Rect(0, 4, 0, 4)));

    auto preview = new EditBox("font_preview", to!dstring(defaultFontPreviewText()));
    preview.layoutWidth(FILL_PARENT).layoutHeight(120);
    preview.backgroundColor = 0x1B1B1B;
    content.addChild(preview);

    auto cbLigatures = new CheckBox("font_ligatures",
        UIString.fromRaw("Show ligature demo line in preview"d));
    cbLigatures.checked = current.codeFontLigatures;
    cbLigatures.margins(Rect(0, 6, 0, 2));
    content.addChild(cbLigatures);

    auto ligaturePreview = new EditBox("font_ligature_preview",
        to!dstring(FONT_PREVIEW_LIGATURES));
    ligaturePreview.layoutWidth(FILL_PARENT).layoutHeight(28);
    ligaturePreview.backgroundColor = 0x1B1B1B;
    ligaturePreview.readOnly = true;
    content.addChild(ligaturePreview);

    auto ligatureNote = new TextWidget(null,
        UIString.fromRaw("dlangui does not enable OpenType ligatures — characters render separately. Terminal and editor ligatures follow OS/editor settings."d));
    ligatureNote.fontSize(8).textColor(0x888888).margins(Rect(0, 2, 0, 4));
    content.addChild(ligatureNote);

    auto installRow = new HorizontalLayout();
    installRow.layoutWidth(FILL_PARENT).margins(Rect(0, 8, 0, 12));
    auto btnInstallFont = new Button(null, UIString.fromRaw("Install selected font"d));
    installRow.addChild(btnInstallFont);
    content.addChild(installRow);

    auto installWatcher = new FontInstallWatcher();
    content.addChild(installWatcher);

    void refreshFontPreview()
    {
        string face = selectedCodeFontFace(rbCascadia, rbJetBrains, rbFira, rbIosevka, rbMonaspace);
        applyPreviewCodeFont(preview, face);
        applyPreviewCodeFont(ligaturePreview, face);

        bool showLigatures = cbLigatures.checked;
        ligaturePreview.visibility = showLigatures ? Visibility.Visible : Visibility.Gone;
        ligatureNote.visibility = showLigatures ? Visibility.Visible : Visibility.Gone;

        if (isCodeFontInstalled(face))
        {
            fontStatus.text = UIString.fromRaw(to!dstring(face ~ " is installed on this system."));
            fontStatus.textColor(0x66AA66);
        }
        else
        {
            fontStatus.text = UIString.fromRaw(to!dstring(
                face ~ " is not installed — preview may fall back to another mono. Use Install or run the Scriptbook playbook."));
            fontStatus.textColor(0xCC8844);
        }

        auto hint = fontInstallAvailabilityHint(face, dataRoot);
        btnInstallFont.enabled = scriptbookOnPath() && hint.length == 0;
        if (!scriptbookOnPath())
            btnInstallFont.tooltipText = UIString.fromRaw(
                "Install scriptbook and add it to PATH to run font playbooks from Appearance."d);
        else if (hint.length)
            btnInstallFont.tooltipText = UIString.fromRaw(to!dstring(hint));
        else
            btnInstallFont.tooltipText = UIString.fromRaw(""d);

        if (dlg.window)
            dlg.window.update(true);
    }

    bool onFontRadioClick(Widget w)
    {
        refreshFontPreview();
        return false;
    }

    rbCascadia.click = &onFontRadioClick;
    rbJetBrains.click = &onFontRadioClick;
    rbFira.click = &onFontRadioClick;
    rbIosevka.click = &onFontRadioClick;
    rbMonaspace.click = &onFontRadioClick;

    cbLigatures.click = delegate(Widget w) {
        refreshFontPreview();
        return false;
    };

    btnInstallFont.click = delegate(Widget w) {
        string face = selectedCodeFontFace(rbCascadia, rbJetBrains, rbFira, rbIosevka, rbMonaspace);
        auto result = launchFontInstall(face, dataRoot);
        parent.showMessageBox(
            UIString.fromRaw(result.ok ? "Font install"d : "Install unavailable"d),
            UIString.fromRaw(to!dstring(result.message)));
        if (result.ok && result.pid !is Pid.init)
        {
            installWatcher.watch(result.pid, delegate(bool success) {
                refreshCodeFontCache();
                refreshFontPreview();
            });
        }
        else
        {
            refreshCodeFontCache();
            refreshFontPreview();
        }
        return true;
    };

    refreshCodeFontCache();
    refreshFontPreview();

    content.addChild(new TextWidget(null,
        UIString.fromRaw("New terminal blocks pick up the choice immediately; reopen open panels if needed."d))
        .fontSize(9).textColor(0x888888).margins(Rect(0, 0, 0, 12)));

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
        UIString.fromRaw("DevCentr on folders: New File…, New Project…, New Installer…, New Installer CI pipeline…, Install in-place PATH, Open. Win11 prefers the modern menu; classic or Linux adapters when needed."d))
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
        s.codeFontFace = selectedCodeFontFace(rbCascadia, rbJetBrains, rbFira, rbIosevka, rbMonaspace);
        s.codeFontLigatures = cbLigatures.checked;
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
