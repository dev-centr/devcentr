/// Rules editor: source on the left, installed templates on the right.
module modules.rules_editor.panel;

import dlangui;
import std.conv : to;
import std.file : exists;

import modules.extensions_catalog.catalog;
import modules.infra.ui : openUrlInBrowser;

class RulesEditorPanel : HorizontalLayout
{
    StringListAdapter _adapter;
    ListWidget _list;
    EditBox _source;
    TextWidget _detail;
    TextWidget _status;
    ExtensionEntry[] _installed;
    string _catalogPath;
    string _codeRoot;
    int _selected = -1;

    this(string catalogPath, string codeRoot)
    {
        super("rulesEditorPanel");
        _catalogPath = catalogPath;
        _codeRoot = codeRoot;
        layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);

        auto editor = new VerticalLayout();
        editor.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).padding(10);
        auto title = new TextWidget(null, "Rules editor"d);
        title.fontSize(18).fontWeight(700);
        editor.addChild(title);
        auto lede = new TextWidget(null, "Templates on this computer are links to files in their repositories. Select one to read the source. Edits in this window are not saved."d);
        lede.fontSize(10);
        editor.addChild(lede);
        _source = new EditBox("rulesSource", ""d);
        _source.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        editor.addChild(_source);
        auto openFile = new Button("btnOpenTemplateFile", "Open the template file"d);
        openFile.click = delegate(Widget w) {
            if (_selected >= 0 && _selected < _installed.length)
                openUrlInBrowser(_installed[_selected].install.pointer);
            return true;
        };
        editor.addChild(openFile);
        addChild(editor);

        auto side = new VerticalLayout("rulesTemplatePanel");
        side.layoutWidth(320).layoutHeight(FILL_PARENT).padding(10);
        side.backgroundColor = 0x1E1E1E;
        auto sideTitle = new TextWidget(null, "Templates on this computer"d);
        sideTitle.fontSize(12).fontWeight(700);
        side.addChild(sideTitle);
        _adapter = new StringListAdapter();
        _list = new ListWidget("listRulesTemplates");
        _list.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        _list.adapter = _adapter;
        _list.itemClick = delegate(Widget w, int idx) {
            showIndex(idx);
            return true;
        };
        side.addChild(_list);
        _detail = new TextWidget("rulesTemplateDetail", ""d);
        _detail.fontSize(10);
        side.addChild(_detail);
        _status = new TextWidget("rulesTemplateStatus", ""d);
        _status.fontSize(10);
        side.addChild(_status);
        auto more = new Button("btnInstallMoreTemplates", "Install more templates"d);
        more.layoutWidth(FILL_PARENT);
        more.click = delegate(Widget w) {
            openUrlInBrowser(onlineStoreUrl);
            _status.text = "Opened the extensions store in your browser. Rules templates are one section of that store."d;
            return true;
        };
        side.addChild(more);
        addChild(side);
        reload();
    }

    void reload()
    {
        _installed = loadOrSeed(_catalogPath);
        dstring[] labels;
        foreach (e; _installed)
            labels ~= to!dstring(e.name);
        _adapter.items = labels;
        if (_installed.length)
            showIndex(0);
        else
        {
            _selected = -1;
            _source.text = "No templates yet. Install more templates to add a link."d;
            _detail.text = ""d;
        }
    }

    void showIndex(int idx)
    {
        if (idx < 0 || idx >= _installed.length)
            return;
        _selected = idx;
        _list.selectItem(idx);
        auto e = _installed[idx];
        string body = readLocalTemplate(_codeRoot, e);
        if (body.length == 0)
        {
            body = "The catalog stores a link, not a copy of this template.\n\n"
                ~ e.install.pointer ~ "\n\n"
                ~ "Open the template file to read it on GitHub. "
                ~ "If the agent-rules clone is in your code hive, this window shows that file.";
        }
        _source.text = to!dstring(body);
        _detail.text = to!dstring(e.description ~ "\n\nLink: " ~ e.install.pointer);
    }
}

class ExtensionsStorePanel : VerticalLayout
{
    EditLine _search;
    EditLine _type;
    StringListAdapter _adapter;
    ListWidget _list;
    TextWidget _status;
    ExtensionEntry[] _shown;
    string _catalogPath;

    this(string catalogPath)
    {
        super("extensionsStorePanel");
        _catalogPath = catalogPath;
        layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).padding(10);
        auto title = new TextWidget(null, "Extensions store"d);
        title.fontSize(18).fontWeight(700);
        addChild(title);
        auto lede = new TextWidget(null, "Browse extensions. Rules templates are one kind. Install saves a link on this computer. The template text stays in its repository."d);
        lede.fontSize(10);
        addChild(lede);

        auto filters = new HorizontalLayout();
        filters.layoutWidth(FILL_PARENT);
        _search = new EditLine("extensionsSearch", ""d);
        _search.layoutWidth(FILL_PARENT);
        _search.contentChange = delegate(EditableContent c) { refresh(); };
        filters.addChild(_search);
        _type = new EditLine("extensionsType", "rules-template"d);
        _type.layoutWidth(220);
        _type.contentChange = delegate(EditableContent c) { refresh(); };
        filters.addChild(_type);
        addChild(filters);
        auto hint = new TextWidget(null, "Search box, then a type filter. Use all to see every kind. rules-template is the rules section."d);
        hint.fontSize(10);
        addChild(hint);

        _adapter = new StringListAdapter();
        _list = new ListWidget("listStoreTemplates");
        _list.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        _list.adapter = _adapter;
        addChild(_list);

        _status = new TextWidget("extensionsStoreStatus", ""d);
        _status.fontSize(10);
        addChild(_status);

        auto row = new HorizontalLayout();
        auto install = new Button("btnInstallStoreTemplate", "Install template"d);
        install.click = delegate(Widget w) {
            int idx = _list.selectedItemIndex;
            if (idx < 0 || idx >= _shown.length)
            {
                _status.text = "Select a template first."d;
                return true;
            }
            string msg;
            installPointer(_catalogPath, _shown[idx], msg);
            _status.text = to!dstring(msg);
            return true;
        };
        row.addChild(install);
        auto web = new Button("btnOpenOnlineStore", "Open the store in your browser"d);
        web.click = delegate(Widget w) {
            openUrlInBrowser(onlineStoreUrl);
            return true;
        };
        row.addChild(web);
        addChild(row);
        refresh();
    }

    void refresh()
    {
        string q = to!string(_search.text);
        string kind = to!string(_type.text);
        if (kind.length == 0)
            kind = "all";
        _shown = filterEntries(publishedCatalog(), kind, q);
        dstring[] labels;
        foreach (e; _shown)
            labels ~= to!dstring(e.name ~ "  ·  " ~ e.type);
        _adapter.items = labels;
        if (_shown.length == 0)
            _status.text = "No extensions match that search."d;
        else
            _status.text = to!dstring(to!string(_shown.length) ~ " shown. Install saves the link only.");
    }
}
