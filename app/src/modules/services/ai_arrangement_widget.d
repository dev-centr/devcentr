module modules.services.ai_arrangement_widget;

import dlangui;
import dlangui.dialogs.dialog : Dialog, DialogFlag;
import modules.infra.logging : logInfo;
import modules.infra.ui : openUrlInBrowser;
import modules.services.ai_stack_loader : loadAIStackDomainPack;
import modules.services.ai_stack_model;
import modules.services.ai_stack_state;
import modules.services.topology_canvas_widget;
import std.conv : to;
import std.string : strip;

/// Arrangement tab: topology canvas + layout recipes + guided add.
class AIArrangementWidget : VerticalLayout
{
    Window _parentWindow;
    AIStackDomainPack _pack;
    AIStackTopologyState _state;
    TopologyCanvasWidget _canvas;
    TextWidget _status;
    TextWidget _inspector;
    ComboBox _recipeCombo;
    AIStackLayoutRecipe[] _recipes;

    this(Window parentWindow)
    {
        super("aiArrangement");
        _parentWindow = parentWindow;
        layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).padding(8);

        _pack = loadAIStackDomainPack();
        _state = loadTopologyState();
        ensureHumanShell(_state, _pack.humanShellProduct);
        saveTopologyState(_state);

        auto heading = new TextWidget(null, to!dstring(_pack.canvasLabel.length ? _pack.canvasLabel : "AI stack"));
        heading.fontSize(15).fontWeight(700).margins(Rect(0, 0, 0, 4));
        addChild(heading);

        auto charter = new TextWidget(null, to!dstring(_pack.charter));
        charter.textColor(0xAAAAAA).fontSize(9).margins(Rect(0, 0, 0, 8));
        addChild(charter);

        auto toolbar = new HorizontalLayout();
        toolbar.layoutWidth(FILL_PARENT).margins(Rect(0, 0, 0, 8));

        auto addBtn = new Button(null, to!dstring(_pack.guidedAddLabel.length ? _pack.guidedAddLabel : "Add an AI tool…"));
        addBtn.click = delegate(Widget w) {
            openGuidedAdd("");
            return true;
        };
        toolbar.addChild(addBtn);

        toolbar.addChild(new TextWidget(null, "  Layout: "d).textColor(0xAAAAAA));

        _recipes = _pack.layoutRecipes;
        dstring[] recipeLabels;
        foreach (r; _recipes)
            recipeLabels ~= to!dstring(r.title.length ? r.title : r.id);
        _recipeCombo = new ComboBox("layoutRecipe", recipeLabels);
        _recipeCombo.layoutWidth(280);
        if (_state.layoutRecipeId.length > 0)
        {
            foreach (i, r; _recipes)
                if (r.id == _state.layoutRecipeId)
                {
                    _recipeCombo.selectedItemIndex = cast(int)i;
                    break;
                }
        }
        _recipeCombo.itemClick = delegate(Widget source, int itemIndex) {
            if (itemIndex < 0 || itemIndex >= cast(int)_recipes.length)
                return true;
            applyLayoutRecipeSoft(_state, _recipes[itemIndex].id, _pack.humanShellProduct);
            saveTopologyState(_state);
            refreshCanvas();
            updateInspectorRecipe(_recipes[itemIndex]);
            return true;
        };
        toolbar.addChild(_recipeCombo);

        auto applyBtn = new Button(null, "Apply layout"d);
        applyBtn.click = delegate(Widget w) {
            int idx = _recipeCombo.selectedItemIndex;
            if (idx >= 0 && idx < cast(int)_recipes.length)
            {
                applyLayoutRecipeSoft(_state, _recipes[idx].id, _pack.humanShellProduct);
                saveTopologyState(_state);
                refreshCanvas();
                updateInspectorRecipe(_recipes[idx]);
            }
            return true;
        };
        toolbar.addChild(applyBtn);

        auto saveBtn = new Button(null, "Save map"d);
        saveBtn.click = delegate(Widget w) {
            saveTopologyState(_state);
            if (_parentWindow)
                _parentWindow.showMessageBox(UIString.fromRaw("AI stack"d), UIString.fromRaw("Saved topology map."d));
            return true;
        };
        toolbar.addChild(saveBtn);

        addChild(toolbar);

        _status = new TextWidget(null, ""d);
        _status.textColor(0x88CC88).fontSize(9).margins(Rect(0, 0, 0, 6));
        addChild(_status);
        updateStatus();

        auto split = new HorizontalLayout();
        split.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);

        _canvas = new TopologyCanvasWidget();
        _canvas.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).minHeight(pointsToPixels(240));
        _canvas.onHit = &onCanvasHit;
        refreshCanvas();
        split.addChild(_canvas);

        auto side = new VerticalLayout();
        side.layoutWidth(280).minWidth(pointsToPixels(180)).layoutHeight(FILL_PARENT).padding(8).backgroundColor(0x222222);
        side.addChild(new TextWidget(null, "Inspector"d).fontWeight(700).margins(Rect(0, 0, 0, 6)));
        _inspector = new TextWidget(null,
            "Blank map: use Add an AI tool… or click + Add on a layer.\n\nOrthogonal follow-ons (Providers / MCP / Skills) stay on the other tabs."d);
        _inspector.textColor(0xCCCCCC).fontSize(9);
        side.addChild(_inspector);

        auto removeBtn = new Button(null, "Remove selected node"d);
        removeBtn.click = delegate(Widget w) {
            auto sel = _canvas.selectedNodeId;
            if (sel.length > 0)
            {
                removeNode(_state, sel);
                ensureHumanShell(_state, _pack.humanShellProduct);
                saveTopologyState(_state);
                refreshCanvas();
                _inspector.text = "Node removed."d;
            }
            return true;
        };
        side.addChild(removeBtn);

        auto mcpHint = new Button(null, "Open Providers / MCP / Skills →"d);
        mcpHint.click = delegate(Widget w) {
            _inspector.text =
                "Use the Providers, MCP Setup, and Skills tabs for orthogonal config. Those are not layer rungs on this spine."d;
            return true;
        };
        side.addChild(mcpHint);

        split.addChild(side);
        addChild(split);

        // First-run nudge
        if (_state.nodes.length <= 1)
            _status.text = "Map is nearly empty — Add an AI tool… walks the layer spine (first-run guided add)."d;
    }

    private void updateStatus()
    {
        string msg = "Pack " ~ _pack.id ~ " v" ~ _pack.version_ ~ " · " ~ to!string(_state.nodes.length) ~ " nodes";
        if (_state.layoutRecipeId.length)
            msg ~= " · layout " ~ _state.layoutRecipeId;
        _status.text = to!dstring(msg);
    }

    private void refreshCanvas()
    {
        _canvas.setData(_pack, _state);
        updateStatus();
    }

    private void updateInspectorRecipe(AIStackLayoutRecipe recipe)
    {
        string text = recipe.title ~ "\n\n" ~ recipe.fit;
        if (recipe.avoidWhen.length)
            text ~= "\n\nAvoid when: " ~ recipe.avoidWhen;
        _inspector.text = to!dstring(text);
    }

    private void onCanvasHit(CanvasHit hit)
    {
        if (hit.kind == CanvasHit.Kind.vacancy)
        {
            openGuidedAdd(hit.roleId);
            return;
        }
        if (hit.kind == CanvasHit.Kind.node)
        {
            foreach (n; _state.nodes)
            {
                if (n.id != hit.nodeId)
                    continue;
                string text = n.label ~ "\nrole: " ~ n.roleId ~ "\nproduct: " ~ n.productId;
                auto prod = findProduct(_pack, n.productId);
                if (prod !is null)
                {
                    if (prod.notes.length)
                        text ~= "\n\n" ~ prod.notes;
                    if (prod.homepage.length)
                        text ~= "\n\n" ~ prod.homepage;
                }
                if (n.roleId == "human-shell")
                    text ~= "\n\nThis is DevCentr’s env-aware ops shell — independent of agent-manager PTYs.";
                _inspector.text = to!dstring(text);
                return;
            }
        }
    }

    private void openGuidedAdd(string roleFilter)
    {
        logInfo("Opening AI guided add" ~ (roleFilter.length ? " for role " ~ roleFilter : " (full spine)"));
        auto dlg = new Dialog(UIString.fromRaw("Add an AI tool"d), _parentWindow,
            DialogFlag.Popup | DialogFlag.Resizable);
        dlg.minWidth(pointsToPixels(390)).minHeight(pointsToPixels(360));

        auto content = new VerticalLayout();
        content.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).padding(12);

        auto roles = sortedRoles(_pack.roles);
        string[] roleIds;
        dstring[] roleLabels;
        int initialRole = 0;
        foreach (i, r; roles)
        {
            if (r.id == "human-shell" && roleFilter.length == 0)
                continue; // auto-managed unless vacancy targeted
            roleIds ~= r.id;
            roleLabels ~= to!dstring(r.title ~ " — " ~ r.memoryBin);
            if (roleFilter.length && r.id == roleFilter)
                initialRole = cast(int)roleIds.length - 1;
        }
        if (roleFilter == "human-shell")
        {
            roleIds = ["human-shell"];
            roleLabels = ["Human ops shell"d];
            initialRole = 0;
        }

        content.addChild(new TextWidget(null, "Layer (memory bin)"d).fontWeight(700));
        auto roleCombo = new ComboBox("guidedRole", roleLabels);
        roleCombo.layoutWidth(FILL_PARENT);
        if (initialRole >= 0 && initialRole < cast(int)roleIds.length)
            roleCombo.selectedItemIndex = initialRole;
        content.addChild(roleCombo);

        content.addChild(new TextWidget(null, "Product"d).fontWeight(700).margins(Rect(0, 10, 0, 0)));
        auto productList = new ListWidget();
        productList.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).minHeight(pointsToPixels(165));
        auto productAdapter = new StringListAdapter();
        productList.ownAdapter = productAdapter;
        content.addChild(productList);

        AIStackCatalogProduct[] currentProducts;

        void reloadProducts()
        {
            productAdapter.clear();
            currentProducts.length = 0;
            int idx = roleCombo.selectedItemIndex;
            if (idx < 0 || idx >= cast(int)roleIds.length)
                return;
            string rid = roleIds[idx];
            currentProducts = productsForRole(_pack, rid);
            foreach (p; currentProducts)
            {
                dstring line = to!dstring(p.displayName);
                if (p.status.length)
                    line ~= to!dstring(" (" ~ p.status ~ ")");
                productAdapter.add(line);
            }
        }

        roleCombo.itemClick = delegate(Widget source, int itemIndex) {
            reloadProducts();
            return true;
        };
        reloadProducts();

        auto allowMulti = new CheckBox(null, "Keep as alternative (do not replace existing in this layer)"d);
        allowMulti.checked = roleFilter.length > 0;
        content.addChild(allowMulti);

        auto btns = new HorizontalLayout();
        btns.layoutWidth(FILL_PARENT).margins(Rect(0, 12, 0, 0));
        auto cancel = new Button(null, "Cancel"d);
        cancel.click = delegate(Widget w) { dlg.close(null); return true; };
        btns.addChild(cancel);

        auto add = new Button(null, "Add to map"d);
        add.click = delegate(Widget w) {
            int ridx = roleCombo.selectedItemIndex;
            int pidx = productList.selectedItemIndex;
            if (ridx < 0 || ridx >= cast(int)roleIds.length)
                return true;
            if (pidx < 0 || pidx >= cast(int)currentProducts.length)
            {
                if (_parentWindow)
                    _parentWindow.showMessageBox(UIString.fromRaw("Add an AI tool"d),
                        UIString.fromRaw("Select a product in the list."d));
                return true;
            }
            auto prod = currentProducts[pidx];
            string rid = roleIds[ridx];
            bool multi = allowMulti.checked || (rid != "env-host" && rid != "human-shell");
            // cardinality 1 roles: never multi unless checkbox forced for alternatives on 0-n
            auto role = findRole(_pack, rid);
            if (role !is null && role.cardinality == "1")
                multi = false;

            addOrReplaceProduct(_state, rid, prod.id, prod.displayName, multi);
            ensureHumanShell(_state, _pack.humanShellProduct);
            saveTopologyState(_state);
            refreshCanvas();
            _inspector.text = to!dstring("Added " ~ prod.displayName ~ " to " ~ rid);
            dlg.close(null);
            return true;
        };
        btns.addChild(add);
        content.addChild(btns);

        // Optional: open homepage for selected
        auto homeBtn = new Button(null, "Open selected homepage"d);
        homeBtn.click = delegate(Widget w) {
            int pidx = productList.selectedItemIndex;
            if (pidx >= 0 && pidx < cast(int)currentProducts.length && currentProducts[pidx].homepage.length)
                openUrlInBrowser(currentProducts[pidx].homepage);
            return true;
        };
        content.addChild(homeBtn);

        dlg.addChild(content);
        dlg.show();
    }
}
