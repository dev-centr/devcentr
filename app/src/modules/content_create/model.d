module modules.content_create.model;

/// One row in a flattened type or lineage list.
struct ContentTypeListItem
{
    string typeId;
    string label;
    int depth;
    bool creatable;
    string edgeNote;
    string edgeKind;
    int inventedYear;
    string vitality;
    string[] ecosystems;
}

struct CreateContentOptions
{
    string repoPath;
    string[] initialTags; /// from CLI or inference; empty → infer
    bool allowTagEdit = true;
    string classificationId; /// when opening past the classification menu
    string tagSourceHint; /// "inferred" | "default" | "cli"
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
    int inventedYear;     /// calendar year introduced (0 = unknown)
    string lastUpdated;   /// YYYY or YYYY-MM of last notable release/spec touch
    string repoUrl;       /// official source repository
    string specUrl;       /// official specification or language definition
    string homepage;      /// project / marketing home
    string vitality;      /// current | mature | legacy | outdated | reference
    string[] ecosystems;  /// filter tags: general, js, jvm, java, …
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
    string scopeId;
    LineageEdge[] edges;
}

struct ContentTypesCatalog
{
    int version_;
    ContentClassification[] classifications;
    LineageScope[] lineages;
}

/// LED / status chip colors for vitality.
uint vitalityLedColor(string vitality)
{
    switch (vitality)
    {
    case "current":
        return 0x22CC55; // green — prefer for new work
    case "mature":
        return 0x55AAEE; // blue — solid, maintained
    case "legacy":
        return 0xE6A817; // amber — still used; prefer successors for greenfield
    case "outdated":
        return 0xDD4444; // red — avoid for new work
    case "reference":
    default:
        return 0x888888; // gray — lineage anchor / non-creatable ref
    }
}

string vitalityLabel(string vitality)
{
    switch (vitality)
    {
    case "current":
        return "current";
    case "mature":
        return "mature";
    case "legacy":
        return "legacy";
    case "outdated":
        return "outdated";
    case "reference":
        return "reference";
    default:
        return vitality.length ? vitality : "unknown";
    }
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

ContentTypeNode* findTypePtr(ContentClassification* klass, string id)
{
    if (klass is null)
        return null;
    return findTypeInTree(klass.types, id);
}

string labelForType(ContentClassification* klass, string id)
{
    auto n = findTypePtr(klass, id);
    if (n is null)
        return id;
    return n.label.length ? n.label : id;
}

bool creatableForType(ContentClassification* klass, string id)
{
    auto n = findTypePtr(klass, id);
    return n !is null && n.creatable;
}

int inventedYearForType(ContentClassification* klass, string id)
{
    auto n = findTypePtr(klass, id);
    return n is null ? 0 : n.inventedYear;
}

string vitalityForType(ContentClassification* klass, string id)
{
    auto n = findTypePtr(klass, id);
    if (n is null)
        return "reference";
    if (n.vitality.length)
        return n.vitality;
    return n.creatable ? "mature" : "reference";
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
        item.inventedYear = n.inventedYear;
        item.vitality = n.vitality.length ? n.vitality : (n.creatable ? "mature" : "reference");
        item.ecosystems = n.ecosystems;
        items ~= item;
        if (n.children.length)
            buildJobTreeItems(n.children, depth + 1, items);
    }
}

bool typeMatchesTags(const ref ContentTypeNode n, const string[] selectedTags)
{
    if (selectedTags.length == 0)
        return true;
    auto eco = n.ecosystems.length ? n.ecosystems : ["general"];
    foreach (t; selectedTags)
    {
        foreach (e; eco)
            if (e == t)
                return true;
    }
    return false;
}

bool itemMatchesTags(const ContentTypeListItem item, ContentClassification* klass, const string[] selectedTags)
{
    if (klass is null)
        return true;
    auto n = findTypePtr(klass, item.typeId);
    if (n is null)
    {
        foreach (t; selectedTags)
            if (t == "general")
                return true;
        return selectedTags.length == 0;
    }
    return typeMatchesTags(*n, selectedTags);
}

/// Filter job tree: keep nodes that match OR have a matching descendant.
ContentTypeNode[] filterTypeTree(ContentTypeNode[] nodes, const string[] selectedTags)
{
    ContentTypeNode[] outNodes;
    foreach (n; nodes)
    {
        auto kids = filterTypeTree(n.children, selectedTags);
        bool selfMatch = typeMatchesTags(n, selectedTags);
        if (selfMatch || kids.length > 0)
        {
            n.children = kids;
            outNodes ~= n;
        }
    }
    return outNodes;
}

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

ContentTypeNode[] creatableLeavesFiltered(ContentClassification c, const string[] selectedTags)
{
    ContentTypeNode[] leaves;
    foreach (ref n; creatableLeaves(c))
    {
        if (typeMatchesTags(n, selectedTags))
            leaves ~= n;
    }
    return leaves;
}

string[] ecosystemsForType(ContentClassification* klass, string id)
{
    auto n = findTypePtr(klass, id);
    if (n is null || n.ecosystems.length == 0)
        return ["general"];
    return n.ecosystems;
}

LineageScope* findLineage(ref ContentTypesCatalog cat, string scopeId)
{
    foreach (ref lin; cat.lineages)
        if (lin.scopeId == scopeId)
            return &lin;
    return null;
}

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
        item.inventedYear = inventedYearForType(klass, id);
        item.vitality = vitalityForType(klass, id);
        item.ecosystems = ecosystemsForType(klass, id);
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
