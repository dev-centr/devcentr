module modules.wsl_manager.ui;

import dlangui;
import modules.wsl_manager.model;
import modules.wsl_manager.guide_loader;
import modules.infra.ui : openUrlInBrowser;
import std.conv : to;

private enum Style {
    bg = 0x252525,
    muted = 0xAAAAAA,
    accent = 0x007AFF,
    body = 0xCCCCCC,
    warn = 0xCC8866,
}

/// WSL distro list + educational guide + links to official Settings / docs.
class WslManagerPanel : VerticalLayout
{
    DistroGuide _guide;
    WslDistro[] _distros;
    ListWidget _list;
    StringListAdapter _adapter;
    VerticalLayout _detail;
    TextWidget _statusLabel;
    void delegate(string title, string message) _notify;

    this(DistroGuide guide, void delegate(string title, string message) notify = null)
    {
        super("wslManagerPanel");
        layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).padding(8);
        _guide = guide;
        _notify = notify;

        auto intro = new TextWidget(null, to!dstring(_guide.intro));
        intro.fontSize(9).textColor(Style.muted).margins(Rect(0, 0, 0, 8));
        addChild(intro);

        auto actions = new HorizontalLayout();
        actions.layoutWidth(FILL_PARENT).margins(Rect(0, 0, 0, 8));

        auto btnRefresh = new Button(null, "Refresh list"d);
        btnRefresh.click = delegate(Widget w) { refresh(); return true; };
        actions.addChild(btnRefresh);

        auto btnSettings = new Button(null, "Open WSL Settings"d);
        btnSettings.click = delegate(Widget w) {
            string via;
            if (openWslSettings(via))
            {
                if (_notify !is null)
                    _notify("WSL Settings", "Opened official WSL Settings (" ~ via ~ "). Use it for memory/CPU/networking (.wslconfig).");
            }
            else
            {
                openUrlInBrowser(_guide.wslSettingsDocsUrl.length > 0
                    ? _guide.wslSettingsDocsUrl
                    : "https://learn.microsoft.com/windows/wsl/wsl-config");
                if (_notify !is null)
                    _notify("WSL Settings", "Could not launch the Settings app on this PC. Opened Microsoft docs instead. Look for “WSL Settings” in the Start menu after updating WSL.");
            }
            return true;
        };
        actions.addChild(btnSettings);

        auto btnCompare = new Button(null, "Distro comparison docs"d);
        btnCompare.click = delegate(Widget w) {
            openUrlInBrowser(_guide.docsComparisonUrl);
            return true;
        };
        actions.addChild(btnCompare);

        auto btnSetup = new Button(null, "Setup how-to"d);
        btnSetup.click = delegate(Widget w) {
            openUrlInBrowser(_guide.docsSetupUrl);
            return true;
        };
        actions.addChild(btnSetup);

        auto btnMs = new Button(null, "Microsoft WSL docs"d);
        btnMs.click = delegate(Widget w) {
            openUrlInBrowser(_guide.microsoftWslDocsUrl);
            return true;
        };
        actions.addChild(btnMs);

        addChild(actions);

        _statusLabel = new TextWidget(null, ""d);
        _statusLabel.fontSize(9).textColor(Style.muted).margins(Rect(0, 0, 0, 6));
        addChild(_statusLabel);

        auto split = new HorizontalLayout();
        split.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);

        auto left = new VerticalLayout();
        left.layoutWidth(WRAP_CONTENT).minWidth(320).layoutHeight(FILL_PARENT).padding(8);
        left.backgroundColor(Style.bg);

        left.addChild(new TextWidget(null, "Installed distros"d).fontSize(11).fontWeight(700).textColor(Style.accent));

        _adapter = new StringListAdapter();
        _list = new ListWidget("wslDistroList");
        _list.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).minHeight(200);
        _list.adapter = _adapter;
        _list.itemClick = delegate(Widget source, int itemIndex) {
            showDetail(itemIndex);
            return true;
        };
        left.addChild(_list);

        auto btnDefault = new Button(null, "Set as default"d);
        btnDefault.click = delegate(Widget w) {
            int idx = _list.selectedItemIndex;
            if (idx < 0 || idx >= cast(int)_distros.length)
            {
                notifyMsg("WSL", "Select a distro first.");
                return true;
            }
            auto d = _distros[idx];
            auto guide = findGuideForName(_guide, d.name);
            if (guide.id == "managed")
            {
                notifyMsg("WSL", "Refusing to set an engine-managed distro (Docker/Podman) as default. Pick Ubuntu LTS or another real workstation distro.");
                return true;
            }
            string err;
            if (!setDefaultDistro(d.name, err))
            {
                notifyMsg("WSL", err.length ? err : "Failed to set default.");
                return true;
            }
            notifyMsg("WSL", "Default distro set to " ~ d.name);
            refresh();
            return true;
        };
        left.addChild(btnDefault);

        split.addChild(left);

        auto rightScroll = new ScrollWidget();
        rightScroll.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).minWidth(360);
        _detail = new VerticalLayout();
        _detail.layoutWidth(FILL_PARENT).padding(12);
        rightScroll.contentWidget = _detail;
        split.addChild(rightScroll);

        addChild(split);
        refresh();
    }

    void refresh()
    {
        _adapter.clear();
        _distros = [];
        version (Windows)
        {
            if (!wslAvailable())
            {
                _statusLabel.text = "wsl.exe not found. Install WSL from Microsoft docs or run: wsl --install"d;
                showPlaceholderDetail("WSL is not available on this machine.");
                return;
            }
            _distros = listInstalledDistros();
            if (_distros.length == 0)
            {
                _statusLabel.text = "No distros listed. Install one from the Store or: wsl --install -d Ubuntu-24.04"d;
                showPlaceholderDetail("No installed distributions detected.");
                return;
            }
            string defName = "";
            foreach (d; _distros)
                if (d.isDefault)
                    defName = d.name;
            _statusLabel.text = to!dstring(
                "Found " ~ to!string(_distros.length) ~ " distro(s)."
                    ~ (defName.length ? (" Default: " ~ defName) : " (no default marker parsed)")
                    ~ "  |  WSL Settings = global VM config; this page = distro choice + education."
            );
            foreach (d; _distros)
            {
                string mark = d.isDefault ? "* " : "  ";
                _adapter.add(to!dstring(mark ~ d.name ~ "  [" ~ d.state ~ "]  WSL" ~ d.version_));
            }
            _list.selectedItemIndex = 0;
            showDetail(0);
        }
        else
        {
            _statusLabel.text = "WSL management is Windows-only."d;
            showPlaceholderDetail("Open this page on Windows to list distros and launch WSL Settings.");
        }
    }

    private void showPlaceholderDetail(string msg)
    {
        _detail.removeAllChildren();
        _detail.addChild(new TextWidget(null, to!dstring(msg)).textColor(Style.muted).fontSize(9));
    }

    private void showDetail(int index)
    {
        _detail.removeAllChildren();
        if (index < 0 || index >= cast(int)_distros.length)
        {
            showPlaceholderDetail("Select a distribution.");
            return;
        }
        auto d = _distros[index];
        auto g = findGuideForName(_guide, d.name);

        auto title = new TextWidget(null, to!dstring(d.name));
        title.fontSize(14).fontWeight(800).textColor(Style.accent);
        _detail.addChild(title);

        auto meta = new TextWidget(null, to!dstring(
            "State: " ~ d.state ~ "    WSL version: " ~ d.version_
                ~ (d.isDefault ? "    (default)" : "")
        ));
        meta.fontSize(8).textColor(0x88AA88).margins(Rect(0, 2, 0, 8));
        _detail.addChild(meta);

        auto role = new TextWidget(null, to!dstring(g.role));
        role.fontSize(11).fontWeight(700).textColor(g.id == "managed" ? Style.warn : Style.body);
        _detail.addChild(role);

        auto guideTitle = new TextWidget(null, to!dstring(g.title));
        guideTitle.fontSize(10).fontWeight(600).margins(Rect(0, 8, 0, 4));
        _detail.addChild(guideTitle);

        if (g.summary.length)
        {
            _detail.addChild(new TextWidget(null, "Overview"d).fontSize(9).fontWeight(700).textColor(Style.accent).margins(Rect(0, 6, 0, 2)));
            _detail.addChild(new TextWidget(null, to!dstring(g.summary)).fontSize(9).textColor(Style.body).margins(Rect(0, 0, 0, 6)));
        }
        if (g.preferWhen.length)
        {
            _detail.addChild(new TextWidget(null, "Prefer when"d).fontSize(9).fontWeight(700).textColor(Style.accent).margins(Rect(0, 4, 0, 2)));
            _detail.addChild(new TextWidget(null, to!dstring(g.preferWhen)).fontSize(9).textColor(Style.muted).margins(Rect(0, 0, 0, 6)));
        }
        if (g.avoidWhen.length)
        {
            _detail.addChild(new TextWidget(null, "Avoid when"d).fontSize(9).fontWeight(700).textColor(Style.accent).margins(Rect(0, 4, 0, 2)));
            _detail.addChild(new TextWidget(null, to!dstring(g.avoidWhen)).fontSize(9).textColor(Style.muted).margins(Rect(0, 0, 0, 6)));
        }

        auto tip = new TextWidget(null,
            "Official WSL Settings configures the shared WSL2 VM (.wslconfig). It does not replace picking which distro is default—that is still wsl --set-default (or the button on the left)."d);
        tip.fontSize(8).textColor(Style.muted).margins(Rect(0, 12, 0, 0));
        _detail.addChild(tip);
    }

    private void notifyMsg(string title, string message)
    {
        if (_notify !is null)
            _notify(title, message);
    }
}
