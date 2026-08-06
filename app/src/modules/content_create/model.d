module modules.content_create.model;

/// One row in a flattened type or lineage list.
struct ContentTypeListItem
{
    string typeId;
    string label;
    int depth;
    bool creatable;
    string edgeNote; /// Lineage-only subtitle (empty for job tree rows).
    string edgeKind; /// Lineage-only kind label.
}

struct ContentTypeNode
{
    string id;
    string label;
    string role;
    string description;
    string extension;
    string suggestedName;
    string templateBody;
    bool creatable;
    ContentTypeNode[] children;
}

struct ContentClassification
{
    string id;
    string label;
    string summary;
    ContentTypeNode[] types;
}

struct LineageEdge
{
    string fromId;
    string toId;
    string kind;
    string note;
}

struct LineageScope
{
    string scope; /// classification id
    LineageEdge[] edges;
}

struct ContentTypesCatalog
{
    int version_;
    ContentClassification[] classifications;
    LineageScope[] lineages;
}

ContentClassification* findClassification(ref ContentTypesCatalog cat, string id)
{
    foreach (ref c; cat.classifications)
        if (c.id == id)
            return &c;
    return null;
}

void collectTypeNodes(ContentTypeNode[] nodes, ref ContentTypeNode[] outNodes)
{
    foreach (ref n; nodes)
    {
        outNodes ~= n;
        if (n.children.length)
            collectTypeNodes(n.children, outNodes);
    }
}

ContentTypeNode* findTypeInTree(ref ContentTypeNode[] nodes, string id)
{
    foreach (ref n; nodes)
    {
        if (n.id == id)
            return &n;
        auto found = findTypeInTree(n.children, id);
        if (found !is null)
            return found;
    }
    return null;
}

ContentTypeNode* findTypeInClassification(ref ContentClassification c, string id)
{
    return findTypeInTree(c.types, id);
}

string labelForType(ContentClassification* klass, string id)
{
    if (klass is null)
        return id;
    ContentTypeNode[] stack = klass.types.dup;
    while (stack.length)
    {
        auto n = stack[0];
        stack = stack[1 .. $];
        if (n.id == id)
            return n.label.length ? n.label : id;
        foreach (ch; n.children)
            stack ~= ch;
    }
    return id;
}

bool creatableForType(ContentClassification* klass, string id)
{
    if (klass is null)
        return false;
    ContentTypeNode[] stack = klass.types.dup;
    while (stack.length)
    {
        auto n = stack[0];
        stack = stack[1 .. $];
        if (n.id == id)
            return n.creatable;
        foreach (ch; n.children)
            stack ~= ch;
    }
    return false;
}

void buildJobTreeItems(ContentTypeNode[] nodes, int depth, ref ContentTypeListItem[] items)
{
    foreach (ref n; nodes)
    {
        ContentTypeListItem item;
        item.typeId = n.id;
        item.label = n.label;
        item.depth = depth;
        item.creatable = n.creatable;
        items ~= item;
        if (n.children.length)
            buildJobTreeItems(n.children, depth + 1, items);
    }
}

/// Creatable leaves (no children, creatable, has extension).
ContentTypeNode[] creatableLeaves(ContentClassification c)
{
    ContentTypeNode[] all;
    collectTypeNodes(c.types, all);
    ContentTypeNode[] leaves;
    foreach (ref n; all)
    {
        if (n.children.length == 0 && n.creatable && n.extension.length > 0)
            leaves ~= n;
    }
    return leaves;
}

LineageScope* findLineage(ref ContentTypesCatalog cat, string scope)
{
    foreach (ref lin; cat.lineages)
        if (lin.scope == scope)
            return &lin;
    return null;
}

/// Indented lineage DAG list; optional focus restricts to connected component.
void buildLineageItems(LineageScope* lin, ContentClassification* klass,
    string focusId, ref ContentTypeListItem[] items)
{
    items = [];
    if (lin is null || lin.edges.length == 0)
        return;

    bool[string] mentioned;
    bool[string] hasIncoming;
    foreach (ref e; lin.edges)
    {
        mentioned[e.fromId] = true;
        mentioned[e.toId] = true;
        hasIncoming[e.toId] = true;
    }

    bool[string] keep;
    if (focusId.length > 0 && (focusId in mentioned))
    {
        void walk(string id)
        {
            if (id in keep)
                return;
            keep[id] = true;
            foreach (ref e; lin.edges)
            {
                if (e.fromId == id)
                    walk(e.toId);
                if (e.toId == id)
                    walk(e.fromId);
            }
        }
        walk(focusId);
    }
    else
    {
        foreach (id; mentioned.byKey)
            keep[id] = true;
    }

    string[] roots;
    foreach (id; keep.byKey)
    {
        if (id !in hasIncoming)
            roots ~= id;
    }
    if (roots.length == 0)
    {
        foreach (id; keep.byKey)
            roots ~= id;
    }

    bool[string] visited;
    void emit(string id, int depth, string kind, string note)
    {
        if (id !in keep || id in visited)
            return;
        visited[id] = true;
        ContentTypeListItem item;
        item.typeId = id;
        item.label = labelForType(klass, id);
        item.depth = depth;
        item.edgeKind = kind;
        item.edgeNote = note;
        item.creatable = creatableForType(klass, id);
        items ~= item;
        foreach (ref e; lin.edges)
        {
            if (e.fromId == id && (e.toId in keep))
                emit(e.toId, depth + 1, e.kind, e.note);
        }
    }

    foreach (r; roots)
        emit(r, 0, "", "");
}
