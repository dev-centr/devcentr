module modules.services.ai_stack_model;

/// Layer-spine data for the AI stack Role Topology Composer pack.

struct AIStackRole
{
    string id;
    string title;
    int spineOrder;
    string cardinality;
    string memoryBin;
    string fixedProduct;
    string[] catalogFrom;
    string notes;
}

struct AIStackEdgeKind
{
    string id;
    string title;
    string[] fromRoles;
    string[] toRoles;
}

struct AIStackLayoutRecipe
{
    string id;
    string arrangementRef;
    string iconKey;
    string title;
    string fit;
    string avoidWhen;
    string[] preferShells;
    string[] preferInference;
    string[] preferInterconnects;
    string uiHost;
    string envHost;
    string inferenceHost;
    string devcentrShell;
}

struct AIStackCatalogProduct
{
    string id;
    string displayName;
    string category; /// shell | runtime | ide | inference | interconnect
    string homepage;
    string launchCommand;
    string status;
    string notes;
    string[] backends;
}

struct AIStackDomainPack
{
    string id;
    string title;
    string version_;
    string charter;
    string guidedAddLabel;
    string canvasLabel;
    string humanShellProduct;
    AIStackRole[] roles;
    AIStackEdgeKind[] edgeKinds;
    AIStackLayoutRecipe[] layoutRecipes;
    AIStackCatalogProduct[] products;
}

struct TopologyNode
{
    string id; /// stable instance id
    string roleId;
    string productId;
    string label;
    bool primary;
}

struct TopologyEdge
{
    string id;
    string kindId;
    string fromNodeId;
    string toNodeId;
}

struct AIStackTopologyState
{
    string layoutRecipeId;
    TopologyNode[] nodes;
    TopologyEdge[] edges;
}

AIStackRole[] sortedRoles(AIStackRole[] roles)
{
    import std.algorithm : sort;
    import std.array : array;
    return roles.dup.sort!((a, b) => a.spineOrder < b.spineOrder).array;
}

TopologyNode[] nodesForRole(const AIStackTopologyState state, string roleId)
{
    TopologyNode[] result;
    foreach (n; state.nodes)
        if (n.roleId == roleId)
            result ~= n;
    return result;
}

AIStackCatalogProduct* findProduct(ref AIStackDomainPack pack, string productId)
{
    foreach (ref p; pack.products)
        if (p.id == productId)
            return &p;
    return null;
}

AIStackRole* findRole(ref AIStackDomainPack pack, string roleId)
{
    foreach (ref r; pack.roles)
        if (r.id == roleId)
            return &r;
    return null;
}

AIStackLayoutRecipe* findLayoutRecipe(ref AIStackDomainPack pack, string recipeId)
{
    foreach (ref r; pack.layoutRecipes)
        if (r.id == recipeId)
            return &r;
    return null;
}

/// Products that belong to a spine role via catalogFrom tags.
AIStackCatalogProduct[] productsForRole(AIStackDomainPack pack, string roleId)
{
    AIStackCatalogProduct[] result;
    AIStackRole role;
    bool found;
    foreach (r; pack.roles)
        if (r.id == roleId)
        {
            role = r;
            found = true;
            break;
        }
    if (!found)
        return result;

    if (role.fixedProduct.length > 0)
    {
        AIStackCatalogProduct fixed;
        fixed.id = role.fixedProduct;
        fixed.displayName = "DevCentr repository terminal";
        fixed.category = "human-shell";
        fixed.status = "active";
        fixed.notes = role.notes;
        result ~= fixed;
        return result;
    }

    if (roleId == "env-host")
    {
        foreach (p; pack.products)
            if (p.category == "env-host")
                result ~= p;
        return result;
    }

    foreach (p; pack.products)
    {
        if (roleId == "control-plane-ui" && (p.category == "shell" || p.category == "ide" || p.category == "fleet-orchestrator"))
            result ~= p;
        else if (roleId == "agent-runtime" && p.category == "runtime")
            result ~= p;
        else if (roleId == "inference-host" && (p.category == "inference" || p.category == "interconnect"))
            result ~= p;
        else
        {
            foreach (c; role.catalogFrom)
                if (c == p.category)
                {
                    result ~= p;
                    break;
                }
        }
    }
    return result;
}
