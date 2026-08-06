module modules.content_create.ui;

import dlangui;
import dlangui.dialogs.dialog : Dialog, DialogFlag;
import dlangui.widgets.popup : PopupAlign;
import modules.content_create.create : createContentStub;
import modules.content_create.ecosystem_tags : resolveInitialTags;
import modules.content_create.loader : loadContentTypesCatalog;
import modules.content_create.model;
import modules.infra.ui : openUrlInBrowser;
import std.algorithm : canFind, sort;
import std.array : join;
import std.conv : to;
import std.string : replace, strip;

private dstring indentSpaces(int depth)
{
    dstring prefix;
    foreach (i; 0 .. depth)
        prefix ~= "  "d;
    return prefix;
}

private dstring jobTreeLabel(const ContentTypeListItem item)
{
    dstring line = indentSpaces(item.depth) ~ to!dstring(item.label);
    if (item.inventedYear > 0)
        line ~= to!dstring("  (" ~ to!string(item.inventedYear) ~ ")");
    if (!item.creatable)
        line ~= "  (ref)"d;
    return line;
}

private Widget makeLed(string vitality)
{
    auto led = new Widget("vitalityLed");
    led.minWidth(12).maxWidth(12).minHeight(12).maxHeight(12);
    led.layoutWidth(12).layoutHeight(12);
    led.backgroundColor(vitalityLedColor(vitality));
    led.margins(Rect(0, 2, 6, 2));
    return led;
}

private void addDetailField(VerticalLayout detail, string title, string value)
{
    if (value.length == 0)
        return;
    auto row = new HorizontalLayout();
    row.layoutWidth(FILL_PARENT).margins(Rect(0, 2, 0, 0));
    auto t = new TextWidget(null, to!dstring(title ~ ": "));
    t.fontSize(8).fontWeight(700).textColor(0xAAAAAA);
    row.addChild(t);
    auto v = new TextWidget(null, to!dstring(value));
    v.fontSize(8).textColor(0xCCCCCC);
    row.addChild(v);
    detail.addChild(row);
}

private void addLinkRow(VerticalLayout detail, string title, string url)
{
    if (url.length == 0)
        return;
    auto row = new HorizontalLayout();
    row.layoutWidth(FILL_PARENT).margins(Rect(0, 2, 0, 0));
    auto t = new TextWidget(null, to!dstring(title ~ ": "));
    t.fontSize(8).fontWeight(700).textColor(0xAAAAAA);
    row.addChild(t);
    auto btn = new Button(null, to!dstring(url));
    btn.fontSize(8);
    string captured = url;
    btn.click = delegate(Widget w) {
        openUrlInBrowser(captured);
        return true;
    };
    row.addChild(btn);
    detail.addChild(row);
}

private string tagHintText(string hint)
{
    switch (hint)
    {
    case "cli":
        return "Ecosystems from command line (toggle to refine).";
    case "inferred":
        return "Ecosystems inferred from project contents.";
    case "default":
    default:
        return "No stack detected — defaulting to general purpose.";
    }
}

/// Show subtype picker for one classification with ecosystem filter chips.
void showContentSubtypeDialog(Window parent, ContentTypesCatalog catalog,
    ContentClassification classification, CreateContentOptions opts)
{
    auto dlg = new Dialog(UIString.fromRaw(to!dstring("Create — " ~ classification.label)), parent,
        DialogFlag.Popup | DialogFlag.Resizable);
    dlg.minWidth(900).minHeight(560);

    auto root = new VerticalLayout();
    root.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).padding(12);

    // Tag chip strip
    auto chipHint = new TextWidget(null, to!dstring(tagHintText(opts.tagSourceHint)));
    chipHint.fontSize(8).textColor(0x888888).margins(Rect(0, 0, 0, 4));
    root.addChild(chipHint);

    auto chipRow = new HorizontalLayout();
    chipRow.layoutWidth(FILL_PARENT).margins(Rect(0, 0, 0, 8));
    root.addChild(chipRow);

    string[] selectedTags = opts.initialTags.dup;
    if (selectedTags.length == 0)
        selectedTags = ["general"];

    // Universe: known tags that appear in catalog or in initial set
    bool[string] universe;
    foreach (t; selectedTags)
        universe[t] = true;
    universe["general"] = true;
    foreach (ref n; classification.types)
    {
        ContentTypeNode[] all;
        collectTypeNodes([n], all);
        foreach (ref x; all)
            foreach (e; x.ecosystems)
                universe[e] = true;
    }

    CheckBox[string] chipBoxes;
    auto bodyRow = new HorizontalLayout();
    bodyRow.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);

    auto leftCol = new VerticalLayout();
    leftCol.layoutWidth(280).layoutHeight(FILL_PARENT);
    leftCol.addChild(new TextWidget(null, "By job / role"d).fontSize(10).fontWeight(700));
    auto jobList = new ListWidget("contentJobTree");
    jobList.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
    auto jobAdapter = new StringListAdapter();
    jobList.ownAdapter = jobAdapter;
    leftCol.addChild(jobList);
    bodyRow.addChild(leftCol);

    auto rightCol = new VerticalLayout();
    rightCol.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);

    auto lineageWrap = new VerticalLayout();
    lineageWrap.layoutWidth(FILL_PARENT).layoutHeight(200);
    auto lineageHead = new HorizontalLayout();
    lineageHead.addChild(new TextWidget(null, "Lineage (evolution)"d).fontSize(10).fontWeight(700));
    auto legend = new TextWidget(null, "  LED: green=current  blue=mature  amber=legacy  red=outdated"d);
    legend.fontSize(7).textColor(0x888888);
    lineageHead.addChild(legend);
    lineageWrap.addChild(lineageHead);

    auto lineageScroll = new ScrollWidget("contentLineageScroll");
    lineageScroll.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
    auto lineageRows = new VerticalLayout();
    lineageRows.layoutWidth(FILL_PARENT).padding(4);
    lineageScroll.contentWidget = lineageRows;
    lineageWrap.addChild(lineageScroll);
    rightCol.addChild(lineageWrap);

    auto detailScroll = new ScrollWidget();
    detailScroll.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
    auto detail = new VerticalLayout();
    detail.layoutWidth(FILL_PARENT).padding(8);
    detailScroll.contentWidget = detail;
    rightCol.addChild(detailScroll);

    auto btnRow = new HorizontalLayout();
    btnRow.layoutWidth(FILL_PARENT).margins(Rect(0, 8, 0, 0));
    auto btnCancel = new Button(null, "Cancel"d);
    auto btnCreate = new Button(null, "Create"d);
    btnCreate.enabled = false;
    btnRow.addChild(btnCancel);
    btnRow.addChild(btnCreate);
    rightCol.addChild(btnRow);

    bodyRow.addChild(rightCol);
    root.addChild(bodyRow);
    dlg.addChild(root);

    ContentTypeListItem[] jobItems;
    ContentTypeListItem[] lineageItems;
    string selectedId = "";
    auto lin = findLineage(catalog, classification.id);
    bool hasLineage = lin !is null && lin.edges.length > 0;
    if (!hasLineage)
        lineageWrap.visibility = Visibility.Gone;

    ContentClassification filteredClass;

    void refreshDetail()
    {
        detail.removeAllChildren();
        if (selectedId.length == 0)
        {
            auto t = new TextWidget(null, "Select a type on the left or in the lineage list."d);
            t.textColor(0x888888).fontSize(9);
            detail.addChild(t);
            btnCreate.enabled = false;
            return;
        }
        auto node = findTypeInClassification(classification, selectedId);
        if (node is null)
        {
            detail.addChild(new TextWidget(null, to!dstring("Unknown type: " ~ selectedId)).textColor(0x888888));
            btnCreate.enabled = false;
            return;
        }

        auto titleRow = new HorizontalLayout();
        titleRow.addChild(makeLed(node.vitality));
        titleRow.addChild(new TextWidget(null, to!dstring(node.label)).fontSize(13).fontWeight(800));
        auto vit = new TextWidget(null, to!dstring("  [" ~ vitalityLabel(node.vitality) ~ "]"));
        vit.fontSize(8).textColor(vitalityLedColor(node.vitality));
        titleRow.addChild(vit);
        detail.addChild(titleRow);

        if (node.role.length)
            detail.addChild(new TextWidget(null, to!dstring(node.role.strip()))
                .fontSize(9).textColor(0x88AA88).margins(Rect(0, 4, 0, 8)));

        detail.addChild(new TextWidget(null, "Facts"d).fontSize(10).fontWeight(700).margins(Rect(0, 4, 0, 2)));
        if (node.inventedYear > 0)
            addDetailField(detail, "Invented", to!string(node.inventedYear));
        addDetailField(detail, "Last updated", node.lastUpdated);
        addDetailField(detail, "Extension", node.extension);
        addDetailField(detail, "Vitality", vitalityLabel(node.vitality));
        if (node.ecosystems.length)
            addDetailField(detail, "Ecosystems", node.ecosystems.join(", "));
        addLinkRow(detail, "Homepage", node.homepage);
        addLinkRow(detail, "Repository", node.repoUrl);
        addLinkRow(detail, "Specification", node.specUrl);

        if (node.description.length)
        {
            detail.addChild(new TextWidget(null, "Description"d).fontSize(10).fontWeight(700).margins(Rect(0, 10, 0, 4)));
            detail.addChild(new TextWidget(null, to!dstring(node.description.replace("\r\n", "\n").strip()))
                .fontSize(9).textColor(0xCCCCCC));
        }
        if (!node.creatable)
            detail.addChild(new TextWidget(null, "Lineage / reference entry — cannot create a stub."d)
                .fontSize(9).textColor(0xCC8888).margins(Rect(0, 10, 0, 0)));
        btnCreate.enabled = node.creatable && node.extension.length > 0;
    }

    void refreshLineage(string focus)
    {
        lineageRows.removeAllChildren();
        lineageItems = [];
        if (!hasLineage)
            return;
        ContentTypeListItem[] raw;
        buildLineageItems(lin, &classification, focus, raw);
        foreach (ref it; raw)
        {
            if (!itemMatchesTags(it, &classification, selectedTags))
                continue;
            lineageItems ~= it;
            auto row = new HorizontalLayout();
            row.layoutWidth(FILL_PARENT).margins(Rect(0, 1, 0, 1));
            row.padding(Rect(cast(int)(it.depth * 12), 2, 4, 2));
            if (it.typeId == selectedId)
                row.backgroundColor(0x333344);
            row.addChild(makeLed(it.vitality));
            dstring yearText = it.inventedYear > 0 ? to!dstring(to!string(it.inventedYear)) : "—"d;
            row.addChild(new TextWidget(null, yearText).minWidth(40).fontSize(8).fontWeight(700).textColor(0xCCCCCC)
                .margins(Rect(0, 0, 6, 0)));
            dstring label = to!dstring(it.label);
            if (it.edgeKind.length)
                label ~= to!dstring("  [" ~ it.edgeKind ~ "]");
            string capturedId = it.typeId;
            auto pick = new Button(null, label);
            pick.fontSize(9);
            pick.click = delegate(Widget w) {
                selectedId = capturedId;
                foreach (i, ref jt; jobItems)
                {
                    if (jt.typeId == capturedId)
                    {
                        jobList.selectedItemIndex = cast(int)i;
                        break;
                    }
                }
                refreshLineage(capturedId);
                refreshDetail();
                return true;
            };
            row.addChild(pick);
            lineageRows.addChild(row);
        }
    }

    void rebuildLists()
    {
        filteredClass = classification;
        filteredClass.types = filterTypeTree(classification.types, selectedTags);
        jobAdapter.clear();
        jobItems = [];
        buildJobTreeItems(filteredClass.types, 0, jobItems);
        foreach (ref it; jobItems)
            jobAdapter.add(jobTreeLabel(it));
        if (selectedId.length)
        {
            bool still = false;
            foreach (ref it; jobItems)
                if (it.typeId == selectedId)
                    still = true;
            if (!still)
                selectedId = "";
        }
        refreshLineage(selectedId);
        refreshDetail();
        if (jobItems.length == 0)
        {
            detail.removeAllChildren();
            detail.addChild(new TextWidget(null,
                "No types for these ecosystems — enable General or another tag."d)
                .fontSize(9).textColor(0xCC8888));
        }
    }

    // Build chips
    string[] chipIds;
    foreach (k; universe.byKey)
        chipIds ~= k;
    chipIds.sort();
    foreach (id; chipIds)
    {
        auto cb = new CheckBox(null, to!dstring(id));
        cb.checked = selectedTags.canFind(id);
        cb.enabled = opts.allowTagEdit;
        cb.fontSize(8);
        cb.margins(Rect(0, 0, 8, 0));
        string captured = id;
        cb.click = delegate(Widget w) {
            bool checked = cb.checked;
            if (checked)
            {
                if (!selectedTags.canFind(captured))
                    selectedTags ~= captured;
            }
            else
            {
                string[] next;
                foreach (t; selectedTags)
                    if (t != captured)
                        next ~= t;
                selectedTags = next;
                if (selectedTags.length == 0)
                {
                    selectedTags = ["general"];
                    if ("general" in chipBoxes)
                        chipBoxes["general"].checked = true;
                }
            }
            rebuildLists();
            return true;
        };
        chipBoxes[id] = cb;
        chipRow.addChild(cb);
    }

    rebuildLists();

    jobList.itemClick = delegate(Widget source, int itemIndex) {
        if (itemIndex >= 0 && itemIndex < cast(int)jobItems.length)
        {
            selectedId = jobItems[itemIndex].typeId;
            refreshLineage(selectedId);
            refreshDetail();
        }
        return true;
    };

    btnCancel.click = delegate(Widget w) {
        dlg.close(new Action(2));
        return true;
    };

    btnCreate.click = delegate(Widget w) {
        auto node = findTypeInClassification(classification, selectedId);
        if (node is null || !node.creatable)
            return true;
        string err;
        auto path = createContentStub(opts.repoPath, *node, err);
        if (err.length)
            parent.showMessageBox(UIString.fromRaw("Create failed"d), UIString.fromRaw(to!dstring(err)));
        else
            parent.showMessageBox(UIString.fromRaw("Created"d), UIString.fromRaw(to!dstring(path)));
        dlg.close(new Action(1));
        return true;
    };

    dlg.show();
}

void beginCreateForClassification(Window parent, ContentTypesCatalog catalog,
    string classificationId, CreateContentOptions opts)
{
    auto klass = findClassification(catalog, classificationId);
    if (klass is null)
    {
        parent.showMessageBox(UIString.fromRaw("Create"d), UIString.fromRaw("Unknown classification."d));
        return;
    }
    opts.classificationId = classificationId;
    auto leaves = creatableLeavesFiltered(*klass, opts.initialTags);
    if (leaves.length == 0 && opts.initialTags != ["general"])
    {
        // widen to general
        opts.initialTags = ["general"];
        opts.tagSourceHint = "default";
        leaves = creatableLeavesFiltered(*klass, opts.initialTags);
    }
    if (leaves.length == 1 && opts.initialTags.canFind("general") && opts.initialTags.length == 1
            && classificationId == "plaintext")
    {
        string err;
        auto path = createContentStub(opts.repoPath, leaves[0], err);
        if (err.length)
            parent.showMessageBox(UIString.fromRaw("Create failed"d), UIString.fromRaw(to!dstring(err)));
        else
            parent.showMessageBox(UIString.fromRaw("Created"d), UIString.fromRaw(to!dstring(path)));
        return;
    }
    if (leaves.length == 0)
    {
        parent.showMessageBox(UIString.fromRaw("Create"d),
            UIString.fromRaw(to!dstring("No creatable types under " ~ klass.label ~ " for these ecosystems.")));
        return;
    }
    showContentSubtypeDialog(parent, catalog, *klass, opts);
}

/// Classification menu then subtype dialog; infers tags when opts.initialTags empty.
void showCreateContentMenu(Window parent, Widget anchor, int x, int y, CreateContentOptions opts)
{
    auto catalog = loadContentTypesCatalog();
    if (catalog.classifications.length == 0)
    {
        parent.showMessageBox(UIString.fromRaw("Create"d),
            UIString.fromRaw("Could not load content-types.sdl."d));
        return;
    }

    if (opts.initialTags.length == 0)
    {
        auto inferred = resolveInitialTags(opts.repoPath, null);
        opts.initialTags = inferred.tags;
        opts.tagSourceHint = inferred.hint;
    }
    else if (opts.tagSourceHint.length == 0)
        opts.tagSourceHint = "cli";

    MenuItem menuRoot = new MenuItem();
    MenuItem createRoot = new MenuItem(new Action(1000, "Create…"d));
    MenuItem sub = new MenuItem();
    int nextId = 1100;
    string[int] idByAction;
    foreach (ref c; catalog.classifications)
    {
        auto act = new Action(nextId, to!dstring(c.label));
        idByAction[nextId] = c.id;
        sub.add(act);
        nextId++;
    }
    createRoot.add(sub);
    menuRoot.add(createRoot);

    PopupMenu menu = new PopupMenu(menuRoot);
    menu.menuItemAction = delegate(const Action a) {
        if (a.id in idByAction)
        {
            beginCreateForClassification(parent, catalog, idByAction[a.id], opts);
            return true;
        }
        return false;
    };
    parent.showPopup(menu, anchor, PopupAlign.Point | PopupAlign.Right, x, y);
}

/// Open New File flow as a classification picker dialog (Explorer / CLI).
void showNewFileLauncher(Window parent, CreateContentOptions opts)
{
    auto catalog = loadContentTypesCatalog();
    if (catalog.classifications.length == 0)
    {
        parent.showMessageBox(UIString.fromRaw("Create"d),
            UIString.fromRaw("Could not load content-types.sdl."d));
        return;
    }
    if (opts.initialTags.length == 0)
    {
        auto inferred = resolveInitialTags(opts.repoPath, null);
        opts.initialTags = inferred.tags;
        opts.tagSourceHint = inferred.hint;
    }

    auto dlg = new Dialog(UIString.fromRaw("New File — choose classification"d), parent,
        DialogFlag.Popup | DialogFlag.Resizable);
    dlg.minWidth(420).minHeight(360);
    auto content = new VerticalLayout();
    content.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).padding(12);
    content.addChild(new TextWidget(null, to!dstring("Folder: " ~ opts.repoPath)).fontSize(8).textColor(0x888888));
    content.addChild(new TextWidget(null, to!dstring(tagHintText(opts.tagSourceHint))).fontSize(8).textColor(0x888888)
        .margins(Rect(0, 0, 0, 8)));
    auto list = new ListWidget("classList");
    list.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
    auto adapter = new StringListAdapter();
    list.ownAdapter = adapter;
    foreach (ref c; catalog.classifications)
        adapter.add(to!dstring(c.label));
    content.addChild(list);
    auto row = new HorizontalLayout();
    auto cancel = new Button(null, "Cancel"d);
    auto next = new Button(null, "Next"d);
    row.addChild(cancel);
    row.addChild(next);
    content.addChild(row);
    dlg.addChild(content);

    cancel.click = delegate(Widget w) { dlg.close(new Action(2)); return true; };
    next.click = delegate(Widget w) {
        auto idx = list.selectedItemIndex;
        if (idx < 0 || idx >= cast(int)catalog.classifications.length)
            return true;
        dlg.close(new Action(1));
        beginCreateForClassification(parent, catalog, catalog.classifications[idx].id, opts);
        return true;
    };
    list.itemClick = delegate(Widget source, int itemIndex) {
        list.selectedItemIndex = itemIndex;
        return true;
    };
    dlg.show();
}
