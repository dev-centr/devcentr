module modules.services.topology_canvas_widget;

import dlangui;
import dlangui.graphics.drawbuf : DrawBuf;
import modules.services.ai_stack_model;
import std.algorithm : max, min;

private enum CanvasStyle
{
    bg = 0x1A1A1A,
    columnBg = 0x222222,
    vacancy = 0x3A3A3A,
    vacancyBorder = 0x666666,
    nodeFill = 0x2A3A4A,
    nodeBorder = 0x007AFF,
    text = 0xEEEEEE,
    muted = 0xAAAAAA,
    accent = 0x007AFF,
    connector = 0x555555,
}

struct CanvasHit
{
    enum Kind
    {
        none,
        vacancy,
        node,
    }

    Kind kind;
    string roleId;
    string nodeId;
}

/// Draws the AI stack layer spine as columns with nodes / vacancies.
class TopologyCanvasWidget : Widget
{
    AIStackDomainPack _pack;
    AIStackTopologyState _state;
    string _selectedNodeId;
    string _selectedRoleId;
    void delegate(CanvasHit hit) _onHit;

    private struct ColLayout
    {
        string roleId;
        Rect column;
        Rect vacancy;
        Rect[] nodeRects;
        string[] nodeIds;
    }

    private ColLayout[] _cols;

    this()
    {
        super("topologyCanvas");
        layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        backgroundColor(CanvasStyle.bg);
        clickable = true;
        focusable = true;
    }

    void setData(AIStackDomainPack pack, AIStackTopologyState state)
    {
        _pack = pack;
        _state = state;
        invalidate();
    }

    string selectedNodeId() const
    {
        return _selectedNodeId;
    }

    void selectedNodeId(string id)
    {
        _selectedNodeId = id;
        invalidate();
    }

    void onHit(void delegate(CanvasHit) cb)
    {
        _onHit = cb;
    }

    override void measure(int parentWidth, int parentHeight)
    {
        int w = parentWidth > 0 ? parentWidth : 800;
        int h = parentHeight > 0 ? parentHeight : 360;
        measuredContent(parentWidth, parentHeight, w, h);
    }

    override void onDraw(DrawBuf buf)
    {
        super.onDraw(buf);
        auto rc = _pos;
        if (rc.empty)
            return;
            buf.fillRect(rc, CanvasStyle.bg);
        _cols.length = 0;

        auto roles = sortedRoles(_pack.roles);
        auto fnt = font;
        if (roles.length == 0)
        {
            if (fnt)
                fnt.drawText(buf, rc.left + 16, rc.top + 16, "No layer spine loaded."d, CanvasStyle.muted);
            return;
        }

        int pad = 12;
        int gap = 10;
        int n = cast(int)roles.length;
        int usable = rc.width - pad * 2 - gap * (n - 1);
        if (usable < 40)
            usable = 40;
        int colW = usable / n;
        int top = rc.top + pad;
        int bottom = rc.bottom - pad;
        int headerH = 48;
        int bodyTop = top + headerH;

        // connectors behind columns
        for (int i = 0; i + 1 < n; i++)
        {
            int x1 = rc.left + pad + i * (colW + gap) + colW;
            int x2 = x1 + gap;
            int cy = (bodyTop + bottom) / 2;
            buf.fillRect(Rect(x1, cy - 1, x2, cy + 1), CanvasStyle.connector);
        }

        foreach (i, role; roles)
        {
            ColLayout col;
            col.roleId = role.id;
            int x = rc.left + pad + cast(int)i * (colW + gap);
            col.column = Rect(x, top, x + colW, bottom);
            buf.fillRect(col.column, CanvasStyle.columnBg);

            auto title = to!dstring(role.title);
            if (fnt)
            {
                fnt.drawText(buf, x + 8, top + 8, title, CanvasStyle.accent);
                auto bin = to!dstring(role.memoryBin);
                if (bin.length > 42)
                    bin = bin[0 .. 39] ~ "..."d;
                fnt.drawText(buf, x + 8, top + 26, bin, CanvasStyle.muted);
            }

            auto nodes = nodesForRole(_state, role.id);
            int y = bodyTop + 8;
            int nodeH = 36;
            int nodeGap = 8;

            if (nodes.length == 0)
            {
                col.vacancy = Rect(x + 8, y, x + colW - 8, y + 44);
                drawDashedRect(buf, col.vacancy, CanvasStyle.vacancyBorder, CanvasStyle.vacancy);
                if (fnt)
                    fnt.drawText(buf, col.vacancy.left + 10, col.vacancy.top + 14, "+ Add…"d, CanvasStyle.muted);
            }
            else
            {
                foreach (node; nodes)
                {
                    Rect nr = Rect(x + 8, y, x + colW - 8, y + nodeH);
                    uint fill = (node.id == _selectedNodeId) ? 0x1E4A6E : CanvasStyle.nodeFill;
                    uint border = (node.id == _selectedNodeId) ? CanvasStyle.accent : CanvasStyle.nodeBorder;
                    buf.fillRect(nr, fill);
                    buf.drawFrame(nr, border, Rect(1, 1, 1, 1));
                    auto label = to!dstring(node.label.length ? node.label : node.productId);
                    if (fnt)
                        fnt.drawText(buf, nr.left + 8, nr.top + 10, label, CanvasStyle.text);
                    col.nodeRects ~= nr;
                    col.nodeIds ~= node.id;
                    y += nodeH + nodeGap;
                }
                bool allowMore = role.cardinality != "1" || nodes.length == 0;
                if (role.id == "human-shell")
                    allowMore = false;
                if (allowMore)
                {
                    col.vacancy = Rect(x + 8, y, x + colW - 8, y + 28);
                    drawDashedRect(buf, col.vacancy, CanvasStyle.vacancyBorder, 0x252525);
                    if (fnt)
                        fnt.drawText(buf, col.vacancy.left + 8, col.vacancy.top + 6, "+ alternative"d, CanvasStyle.muted);
                }
            }

            _cols ~= col;
        }
    }

    private void drawDashedRect(DrawBuf buf, Rect r, uint border, uint fill)
    {
        buf.fillRect(r, fill);
        // simple dashed frame via segments
        int step = 6;
        for (int x = r.left; x < r.right; x += step * 2)
        {
            int x2 = min(x + step, r.right);
            buf.fillRect(Rect(x, r.top, x2, r.top + 1), border);
            buf.fillRect(Rect(x, r.bottom - 1, x2, r.bottom), border);
        }
        for (int y = r.top; y < r.bottom; y += step * 2)
        {
            int y2 = min(y + step, r.bottom);
            buf.fillRect(Rect(r.left, y, r.left + 1, y2), border);
            buf.fillRect(Rect(r.right - 1, y, r.right, y2), border);
        }
    }

    override bool onMouseEvent(MouseEvent event)
    {
        if (event.action != MouseAction.ButtonDown || event.button != MouseButton.Left)
            return super.onMouseEvent(event);

        CanvasHit hit;
        hit.kind = CanvasHit.Kind.none;
        foreach (col; _cols)
        {
            foreach (i, nr; col.nodeRects)
            {
                if (nr.isPointInside(event.x, event.y))
                {
                    hit.kind = CanvasHit.Kind.node;
                    hit.roleId = col.roleId;
                    hit.nodeId = col.nodeIds[i];
                    _selectedNodeId = hit.nodeId;
                    _selectedRoleId = hit.roleId;
                    if (_onHit)
                        _onHit(hit);
                    invalidate();
                    return true;
                }
            }
            if (!col.vacancy.empty && col.vacancy.isPointInside(event.x, event.y))
            {
                hit.kind = CanvasHit.Kind.vacancy;
                hit.roleId = col.roleId;
                _selectedRoleId = hit.roleId;
                if (_onHit)
                    _onHit(hit);
                invalidate();
                return true;
            }
        }
        return true;
    }
}
