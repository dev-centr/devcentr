module modules.content_create.ui;

import dlangui;
import dlangui.dialogs.dialog : Dialog, DialogFlag;
import dlangui.widgets.popup : PopupAlign;
import modules.content_create.create : createContentStub;
import modules.content_create.loader : loadContentTypesCatalog;
import modules.content_create.model;
import std.conv : to;
import std.string : replace;

private dstring indentLabel(const ContentTypeListItem item)
{
    dstring prefix;
    foreach (i; 0 .. item.depth)
        prefix ~= "  "d;
    dstring line = prefix ~ to!dstring(item.label);
    if (item.edgeKind.length)
        line ~= to!dstring("  [" ~ item.edgeKind ~ "]");
    if (!item.creatable)
        line ~= "  (ref)"d;
    return line;
}

/// Show subtype picker; on Create writes stub. Returns true if created.
void showContentSubtypeDialog(Window parent, string repoPath, ContentTypesCatalog catalog,
    ContentClassification classification)
{
    auto dlg = new Dialog(UIString.fromRaw(to!dstring("Create — " ~ classification.label)), parent,
        DialogFlag.Popup | DialogFlag.Resizable);
    dlg.minWidth(780).minHeight(480);

    auto root = new HorizontalLayout();
    root.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).padding(12);

    // Left: job tree
    auto leftCol = new VerticalLayout();
    leftCol.layoutWidth(280).layoutHeight(FILL_PARENT);
    leftCol.addChild(new TextWidget(null, "By job / role"d).fontSize(10).fontWeight(700));
    auto jobList = new ListWidget("contentJobTree");
    jobList.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
    auto jobAdapter = new StringListAdapter();
    jobList.ownAdapter = jobAdapter;
    leftCol.addChild(jobList);
    root.addChild(leftCol);

    // Right: lineage (top) + detail (bottom)
    auto rightCol = new VerticalLayout();
    rightCol.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);

    auto lineageWrap = new VerticalLayout();
    lineageWrap.layoutWidth(FILL_PARENT).layoutHeight(180);
    lineageWrap.addChild(new TextWidget(null, "Lineage (evolution)"d).fontSize(10).fontWeight(700));
    auto lineageList = new ListWidget("contentLineageTree");
    lineageList.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
    auto lineageAdapter = new StringListAdapter();
    lineageList.ownAdapter = lineageAdapter;
    lineageWrap.addChild(lineageList);
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
        jobAdapter.add(indentLabel(it));

    auto lin = findLineage(catalog, classification.id);
    bool hasLineage = lin !is null && lin.edges.length > 0;
    if (!hasLineage)
        lineageWrap.visibility = Visibility.Gone;

    ContentTypeListItem[] lineageItems;
    string selectedId = "";

    void refreshLineage(string focus)
    {
        lineageAdapter.clear();
        lineageItems = [];
        if (!hasLineage)
            return;
        buildLineageItems(lin, &classification, focus, lineageItems);
        foreach (ref it; lineageItems)
        {
            auto line = indentLabel(it);
            if (it.edgeNote.length)
            {
                auto note = it.edgeNote;
                if (note.length > 72)
                    note = note[0 .. 69] ~ "...";
                line ~= to!dstring(" — " ~ note);
            }
            lineageAdapter.add(line);
        }
    }

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
        auto head = new TextWidget(null, to!dstring(node.label));
        head.fontSize(13).fontWeight(800);
        detail.addChild(head);
        if (node.role.length)
        {
            auto role = new TextWidget(null, to!dstring(node.role));
            role.fontSize(9).textColor(0x88AA88).margins(Rect(0, 4, 0, 8));
            detail.addChild(role);
        }
        if (node.extension.length)
        {
            auto ext = new TextWidget(null, to!dstring("Extension: " ~ node.extension));
            ext.fontSize(8).textColor(0xAAAAAA);
            detail.addChild(ext);
        }
        if (node.description.length)
        {
            auto descHead = new TextWidget(null, "Description"d);
            descHead.fontSize(10).fontWeight(700).margins(Rect(0, 8, 0, 4));
            detail.addChild(descHead);
            auto desc = new TextWidget(null, to!dstring(node.description.replace("\r\n", "\n")));
            desc.fontSize(9).textColor(0xCCCCCC);
            detail.addChild(desc);
        }
        if (!node.creatable)
        {
            auto warn = new TextWidget(null, "This entry is a lineage reference only and cannot be created as a stub."d);
            warn.fontSize(9).textColor(0xCC8888).margins(Rect(0, 10, 0, 0));
            detail.addChild(warn);
        }
        btnCreate.enabled = node.creatable && node.extension.length > 0;
    }

    void selectType(string id)
    {
        selectedId = id;
        // sync job list selection
        foreach (i, ref it; jobItems)
        {
            if (it.typeId == id)
            {
                jobList.selectedItemIndex = cast(int)i;
                break;
            }
        }
        if (hasLineage)
        {
            refreshLineage(id);
            foreach (i, ref it; lineageItems)
            {
                if (it.typeId == id)
                {
                    lineageList.selectedItemIndex = cast(int)i;
                    break;
                }
            }
        }
        refreshDetail();
    }

    refreshLineage("");
    refreshDetail();

    jobList.itemClick = delegate(Widget source, int itemIndex) {
        if (itemIndex >= 0 && itemIndex < cast(int)jobItems.length)
            selectType(jobItems[itemIndex].typeId);
        return true;
    };

    lineageList.itemClick = delegate(Widget source, int itemIndex) {
        if (itemIndex >= 0 && itemIndex < cast(int)lineageItems.length)
            selectType(lineageItems[itemIndex].typeId);
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

/// Handle choosing a classification: single creatable leaf → create; else dialog.
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

/// Popup Create… menu at point; classifications are flat (no nested submenu tree).
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
