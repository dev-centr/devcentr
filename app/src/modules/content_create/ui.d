module modules.content_create.ui;

import dlangui;
import dlangui.dialogs.dialog : Dialog, DialogFlag;
import dlangui.widgets.popup : PopupAlign;
import modules.content_create.create : createContentStub;
import modules.content_create.loader : loadContentTypesCatalog;
import modules.content_create.model;
import modules.infra.ui : openUrlInBrowser;
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

void showContentSubtypeDialog(Window parent, string repoPath, ContentTypesCatalog catalog,
    ContentClassification classification)
{
    auto dlg = new Dialog(UIString.fromRaw(to!dstring("Create — " ~ classification.label)), parent,
        DialogFlag.Popup | DialogFlag.Resizable);
    dlg.minWidth(860).minHeight(520);

    auto root = new HorizontalLayout();
    root.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).padding(12);

    auto leftCol = new VerticalLayout();
    leftCol.layoutWidth(280).layoutHeight(FILL_PARENT);
    leftCol.addChild(new TextWidget(null, "By job / role"d).fontSize(10).fontWeight(700));
    auto jobList = new ListWidget("contentJobTree");
    jobList.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
    auto jobAdapter = new StringListAdapter();
    jobList.ownAdapter = jobAdapter;
    leftCol.addChild(jobList);
    root.addChild(leftCol);

    auto rightCol = new VerticalLayout();
    rightCol.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);

    auto lineageWrap = new VerticalLayout();
    lineageWrap.layoutWidth(FILL_PARENT).layoutHeight(200);
    auto lineageHead = new HorizontalLayout();
    lineageHead.layoutWidth(FILL_PARENT);
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

    root.addChild(rightCol);
    dlg.addChild(root);

    ContentTypeListItem[] jobItems;
    buildJobTreeItems(classification.types, 0, jobItems);
    foreach (ref it; jobItems)
        jobAdapter.add(jobTreeLabel(it));

    auto lin = findLineage(catalog, classification.id);
    bool hasLineage = lin !is null && lin.edges.length > 0;
    if (!hasLineage)
        lineageWrap.visibility = Visibility.Gone;

    ContentTypeListItem[] lineageItems;
    string selectedId = "";

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
            auto t = new TextWidget(null, to!dstring("Unknown type: " ~ selectedId));
            t.textColor(0x888888);
            detail.addChild(t);
            btnCreate.enabled = false;
            return;
        }

        auto titleRow = new HorizontalLayout();
        titleRow.layoutWidth(FILL_PARENT);
        titleRow.addChild(makeLed(node.vitality));
        auto head = new TextWidget(null, to!dstring(node.label));
        head.fontSize(13).fontWeight(800);
        titleRow.addChild(head);
        auto vit = new TextWidget(null, to!dstring("  [" ~ vitalityLabel(node.vitality) ~ "]"));
        vit.fontSize(8).textColor(vitalityLedColor(node.vitality));
        titleRow.addChild(vit);
        detail.addChild(titleRow);

        if (node.role.length)
        {
            auto role = new TextWidget(null, to!dstring(node.role.strip()));
            role.fontSize(9).textColor(0x88AA88).margins(Rect(0, 4, 0, 8));
            detail.addChild(role);
        }

        auto metaHead = new TextWidget(null, "Facts"d);
        metaHead.fontSize(10).fontWeight(700).margins(Rect(0, 4, 0, 2));
        detail.addChild(metaHead);

        if (node.inventedYear > 0)
            addDetailField(detail, "Invented", to!string(node.inventedYear));
        addDetailField(detail, "Last updated", node.lastUpdated);
        addDetailField(detail, "Extension", node.extension);
        addDetailField(detail, "Vitality", vitalityLabel(node.vitality));
        addLinkRow(detail, "Homepage", node.homepage);
        addLinkRow(detail, "Repository", node.repoUrl);
        addLinkRow(detail, "Specification", node.specUrl);

        if (node.description.length)
        {
            auto descHead = new TextWidget(null, "Description"d);
            descHead.fontSize(10).fontWeight(700).margins(Rect(0, 10, 0, 4));
            detail.addChild(descHead);
            auto desc = new TextWidget(null, to!dstring(node.description.replace("\r\n", "\n").strip()));
            desc.fontSize(9).textColor(0xCCCCCC);
            detail.addChild(desc);
        }
        if (!node.creatable)
        {
            auto warn = new TextWidget(null, "Lineage / reference entry — cannot create a stub from this node."d);
            warn.fontSize(9).textColor(0xCC8888).margins(Rect(0, 10, 0, 0));
            detail.addChild(warn);
        }
        btnCreate.enabled = node.creatable && node.extension.length > 0;
    }

    void refreshLineage(string focus)
    {
        lineageRows.removeAllChildren();
        lineageItems = [];
        if (!hasLineage)
            return;
        buildLineageItems(lin, &classification, focus, lineageItems);
        foreach (ref it; lineageItems)
        {
            auto row = new HorizontalLayout();
            row.layoutWidth(FILL_PARENT).margins(Rect(0, 1, 0, 1));
            row.padding(Rect(cast(int)(it.depth * 12), 2, 4, 2));
            if (it.typeId == selectedId)
                row.backgroundColor(0x333344);

            row.addChild(makeLed(it.vitality));

            dstring yearText = it.inventedYear > 0 ? to!dstring(to!string(it.inventedYear)) : "—"d;
            auto yearBox = new TextWidget(null, yearText);
            yearBox.minWidth(40).fontSize(8).fontWeight(700).textColor(0xCCCCCC);
            yearBox.margins(Rect(0, 0, 6, 0));
            row.addChild(yearBox);

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

            if (it.edgeNote.length)
            {
                auto note = it.edgeNote;
                if (note.length > 40)
                    note = note[0 .. 37] ~ "...";
                auto noteW = new TextWidget(null, to!dstring("  — " ~ note));
                noteW.fontSize(7).textColor(0x888888);
                row.addChild(noteW);
            }

            lineageRows.addChild(row);
        }
    }

    void selectFromJob(string id)
    {
        selectedId = id;
        if (hasLineage)
            refreshLineage(id);
        refreshDetail();
    }

    refreshLineage("");
    refreshDetail();

    jobList.itemClick = delegate(Widget source, int itemIndex) {
        if (itemIndex >= 0 && itemIndex < cast(int)jobItems.length)
            selectFromJob(jobItems[itemIndex].typeId);
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
        auto path = createContentStub(repoPath, *node, err);
        if (err.length)
            parent.showMessageBox(UIString.fromRaw("Create failed"d), UIString.fromRaw(to!dstring(err)));
        else
            parent.showMessageBox(UIString.fromRaw("Created"d), UIString.fromRaw(to!dstring(path)));
        dlg.close(new Action(1));
        return true;
    };

    dlg.show();
}

void beginCreateForClassification(Window parent, string repoPath, ContentTypesCatalog catalog,
    string classificationId)
{
    auto klass = findClassification(catalog, classificationId);
    if (klass is null)
    {
        parent.showMessageBox(UIString.fromRaw("Create"d), UIString.fromRaw("Unknown classification."d));
        return;
    }
    auto leaves = creatableLeaves(*klass);
    if (leaves.length == 1)
    {
        string err;
        auto path = createContentStub(repoPath, leaves[0], err);
        if (err.length)
            parent.showMessageBox(UIString.fromRaw("Create failed"d), UIString.fromRaw(to!dstring(err)));
        else
            parent.showMessageBox(UIString.fromRaw("Created"d), UIString.fromRaw(to!dstring(path)));
        return;
    }
    if (leaves.length == 0)
    {
        parent.showMessageBox(UIString.fromRaw("Create"d),
            UIString.fromRaw(to!dstring("No creatable types under " ~ klass.label ~ ".")));
        return;
    }
    showContentSubtypeDialog(parent, repoPath, catalog, *klass);
}

void showCreateContentMenu(Window parent, Widget anchor, int x, int y, string repoPath)
{
    auto catalog = loadContentTypesCatalog();
    if (catalog.classifications.length == 0)
    {
        parent.showMessageBox(UIString.fromRaw("Create"d),
            UIString.fromRaw("Could not load content-types.sdl."d));
        return;
    }

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
            beginCreateForClassification(parent, repoPath, catalog, idByAction[a.id]);
            return true;
        }
        return false;
    };
    parent.showPopup(menu, anchor, PopupAlign.Point | PopupAlign.Right, x, y);
}
