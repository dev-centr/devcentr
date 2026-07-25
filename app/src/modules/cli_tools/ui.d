module modules.cli_tools.ui;

import dlangui;
import modules.cli_tools.model;
import modules.cli_tools.catalog;
import modules.cli_tools.context;
import modules.cli_tools.install_runner;
import modules.infra.ui : openUrlInBrowser;
import std.conv : to;
import std.algorithm : canFind, sort;
import std.array : array;
import std.string : toLower;

private enum PanelStyle {
    bg = 0x252525,
    accent = 0x007AFF,
    muted = 0xAAAAAA,
    success = 0x00FF00,
    danger = 0xFF4444,
}

class CliToolCard : VerticalLayout {
    CliToolEntry _tool;
    bool _installed;
    string _contextId;
    bool _preferImmutable;
    string _dataRoot;
    void delegate() _onInstalled;

    this(
        CliToolEntry tool,
        bool installed,
        string contextId,
        bool preferImmutable,
        string dataRoot,
        void delegate() onInstalled
    ) {
        super("cli_tool_" ~ tool.id);
        _tool = tool;
        _installed = installed;
        _contextId = contextId;
        _preferImmutable = preferImmutable;
        _dataRoot = dataRoot;
        _onInstalled = onInstalled;
        layoutWidth(FILL_PARENT).padding(10).margins(5).backgroundColor(PanelStyle.bg);

        auto header = new HorizontalLayout();
        header.layoutWidth(FILL_PARENT);

        auto name = new TextWidget(null, to!dstring(tool.name));
        name.fontSize(14).fontWeight(700).textColor(PanelStyle.accent).layoutWidth(FILL_PARENT);
        header.addChild(name);

        auto status = new TextWidget(null, to!dstring(_installed ? "Installed" : "Not installed"));
        status.fontSize(10).textColor(_installed ? PanelStyle.success : PanelStyle.muted);
        header.addChild(status);
        addChild(header);

        if (tool.description.length > 0) {
            auto desc = new TextWidget(null, to!dstring(tool.description));
            desc.fontSize(9).textColor(PanelStyle.muted).margins(Rect(0, 4, 0, 4));
            addChild(desc);
        }

        if (tool.categories.length > 0) {
            auto cats = new TextWidget(null, to!dstring(tool.categories.join(" \u2022 ")));
            cats.fontSize(8).textColor(0x666666);
            addChild(cats);
        }

        auto actions = new HorizontalLayout();
        actions.layoutWidth(FILL_PARENT).margins(Rect(6, 0, 0, 0));

        if (!_installed) {
            auto btnInstall = new Button(null, "Install"d);
            btnInstall.click = delegate(Widget w) {
                auto method = resolveInstallMethod(_tool, _contextId, _preferImmutable);
                if (method.command.length == 0) {
                    return true;
                }
                auto r = runInteractiveInstall(_dataRoot, _tool.id, _tool.name, method, _tool.verifyCommand);
                if (_onInstalled !is null)
                    _onInstalled();
                return true;
            };
            actions.addChild(btnInstall);
        }

        if (tool.docs.length > 0) {
            auto btnDocs = new Button(null, "Docs"d);
            btnDocs.click = delegate(Widget w) {
                openUrlInBrowser(tool.docs);
                return true;
            };
            actions.addChild(btnDocs);
        }

        addChild(actions);
    }
}

class CliToolsCatalogPanel : ScrollWidget {
    CliToolsCatalog _catalog;
    string _contextId;
    bool _preferImmutable;
    string _dataRoot;
    EditLine _filter;
    VerticalLayout _content;
    void delegate() _onChange;

    this(
        CliToolsCatalog catalog,
        string contextId,
        bool preferImmutable,
        string dataRoot,
        void delegate() onChange = null
    ) {
        super("cliToolsCatalogPanel");
        layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        _catalog = catalog;
        _contextId = contextId;
        _preferImmutable = preferImmutable;
        _dataRoot = dataRoot;
        _onChange = onChange;

        auto root = new VerticalLayout();
        root.layoutWidth(FILL_PARENT);

        auto ctxLabel = new TextWidget(null,
            to!dstring("Host context: " ~ contextLabel(_catalog, _contextId)));
        ctxLabel.fontSize(9).textColor(PanelStyle.muted).margins(Rect(0, 0, 0, 6));
        root.addChild(ctxLabel);

        _filter = new EditLine("cliToolsFilter", "Filter tools…"d);
        _filter.layoutWidth(FILL_PARENT).margins(Rect(0, 0, 0, 8));
        _filter.contentChange = delegate(EditableContent content) {
            rebuildList(to!string(_filter.text));
            return true;
        };
        root.addChild(_filter);

        _content = new VerticalLayout();
        _content.layoutWidth(FILL_PARENT);
        root.addChild(_content);

        contentWidget = root;
        rebuildList("");
    }

    static string bundledFallbackJsonPath() {
        import std.path : buildPath, dirName;
        import std.file : exists, thisExePath;
        string p = buildPath(getcwd(), "src", "modules", "cli_tools", "fallback-tools.json");
        if (exists(p))
            return p;
        return buildPath(dirName(thisExePath()), "fallback-tools.json");
    }

    void rebuildList(string query) {
        _content.removeAllChildren();
        string q = toLower(query);

        string[] categories;
        foreach (t; _catalog.tools) {
            foreach (c; t.categories)
                if (!categories.canFind(c)) categories ~= c;
        }
        sort(categories);

        foreach (cat; categories) {
            CliToolEntry[] inCat;
            foreach (t; _catalog.tools) {
                if (!t.categories.canFind(cat)) continue;
                if (q.length > 0) {
                    if (!toLower(t.name).canFind(q) && !toLower(t.id).canFind(q) &&
                        !toLower(t.description).canFind(q) && !toLower(cat).canFind(q))
                        continue;
                }
                inCat ~= t;
            }
            if (inCat.length == 0) continue;

            auto expander = new VerticalLayout();
            expander.layoutWidth(FILL_PARENT);
            auto header = new TextWidget(null, to!dstring(cat ~ " (" ~ cast(string)inCat.length ~ ")"));
            header.fontSize(11).fontWeight(700).padding(6).backgroundColor(0x222222);
            expander.addChild(header);

            auto list = new VerticalLayout();
            list.layoutWidth(FILL_PARENT).padding(4);
            foreach (t; inCat) {
                bool installed = isToolInstalled(t.verifyCommand);
                list.addChild(new CliToolCard(t, installed, _contextId, _preferImmutable, _dataRoot, _onChange));
            }
            expander.addChild(list);
            _content.addChild(expander);
        }
    }
}
