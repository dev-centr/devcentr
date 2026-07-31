module modules.services.ai_stack_state;

import modules.services.ai_stack_model;
import std.datetime.systime : Clock;
import std.random : uniform;
import std.conv : to;
import std.file : exists, mkdirRecurse, readText, write;
import std.json : JSONValue, parseJSON, JSONType;
import std.path : buildPath;
import std.process : environment;
import std.string : strip;

string aiStackConfigRoot()
{
    version (Windows)
    {
        auto drive = environment.get("HOMEDRIVE");
        auto path = environment.get("HOMEPATH");
        if (drive && path)
            return buildPath(drive, path, ".dev-center");
        return buildPath(environment.get("USERPROFILE"), ".dev-center");
    }
    else
    {
        return buildPath(environment.get("HOME"), ".dev-center");
    }
}

string topologyStatePath()
{
    return buildPath(aiStackConfigRoot(), "ai-stack-topology.json");
}

private string jsonStr(JSONValue j, string key)
{
    if (key !in j)
        return "";
    if (j[key].type == JSONType.string)
        return j[key].str;
    return "";
}

private bool jsonBool(JSONValue j, string key, bool def = false)
{
    if (key !in j)
        return def;
    if (j[key].type == JSONType.true_ || j[key].type == JSONType.false_)
        return j[key].type == JSONType.true_;
    return def;
}

AIStackTopologyState loadTopologyState()
{
    AIStackTopologyState state;
    auto path = topologyStatePath();
    if (!exists(path))
        return state;
    try
    {
        auto root = parseJSON(readText(path));
        state.layoutRecipeId = jsonStr(root, "layoutRecipeId");
        if ("nodes" in root && root["nodes"].type == JSONType.array)
        {
            foreach (n; root["nodes"].array)
            {
                TopologyNode node;
                node.id = jsonStr(n, "id");
                node.roleId = jsonStr(n, "roleId");
                node.productId = jsonStr(n, "productId");
                node.label = jsonStr(n, "label");
                node.primary = jsonBool(n, "primary", true);
                if (node.id.length == 0)
                    node.id = newNodeId();
                state.nodes ~= node;
            }
        }
        if ("edges" in root && root["edges"].type == JSONType.array)
        {
            foreach (e; root["edges"].array)
            {
                TopologyEdge edge;
                edge.id = jsonStr(e, "id");
                edge.kindId = jsonStr(e, "kindId");
                edge.fromNodeId = jsonStr(e, "fromNodeId");
                edge.toNodeId = jsonStr(e, "toNodeId");
                if (edge.id.length == 0)
                    edge.id = newNodeId();
                state.edges ~= edge;
            }
        }
    }
    catch (Exception)
    {
    }
    return state;
}

void saveTopologyState(const AIStackTopologyState state)
{
    auto rootDir = aiStackConfigRoot();
    if (!exists(rootDir))
        mkdirRecurse(rootDir);

    JSONValue root;
    root["layoutRecipeId"] = JSONValue(state.layoutRecipeId);
    JSONValue nodes = JSONValue.emptyArray;
    foreach (n; state.nodes)
    {
        JSONValue j;
        j["id"] = JSONValue(n.id);
        j["roleId"] = JSONValue(n.roleId);
        j["productId"] = JSONValue(n.productId);
        j["label"] = JSONValue(n.label);
        j["primary"] = JSONValue(n.primary);
        nodes.array ~= j;
    }
    root["nodes"] = nodes;

    JSONValue edges = JSONValue.emptyArray;
    foreach (e; state.edges)
    {
        JSONValue j;
        j["id"] = JSONValue(e.id);
        j["kindId"] = JSONValue(e.kindId);
        j["fromNodeId"] = JSONValue(e.fromNodeId);
        j["toNodeId"] = JSONValue(e.toNodeId);
        edges.array ~= j;
    }
    root["edges"] = edges;

    write(topologyStatePath(), root.toPrettyString());
}

string newNodeId()
{
    auto t = Clock.currTime().stdTime;
    return "n-" ~ to!string(t) ~ "-" ~ to!string(uniform(0, 1_000_000));
}

/// Apply a layout recipe: set recipe id and ensure human-shell + vacancies implied by clearing unrelated nodes optionally.
/// Soft apply: only sets layoutRecipeId and ensures human-shell node exists; does not wipe user nodes.
void applyLayoutRecipeSoft(ref AIStackTopologyState state, string recipeId, string humanShellProduct)
{
    state.layoutRecipeId = recipeId;
    ensureHumanShell(state, humanShellProduct);
}

void ensureHumanShell(ref AIStackTopologyState state, string humanShellProduct)
{
    foreach (n; state.nodes)
        if (n.roleId == "human-shell")
            return;
    TopologyNode node;
    node.id = newNodeId();
    node.roleId = "human-shell";
    node.productId = humanShellProduct.length ? humanShellProduct : "devcentr-repo-terminal";
    node.label = "DevCentr repository terminal";
    node.primary = true;
    state.nodes ~= node;
}

void addOrReplaceProduct(ref AIStackTopologyState state, string roleId, string productId, string label, bool allowMultiple)
{
    if (!allowMultiple)
    {
        TopologyNode[] kept;
        foreach (n; state.nodes)
            if (n.roleId != roleId)
                kept ~= n;
        state.nodes = kept;
    }
    TopologyNode node;
    node.id = newNodeId();
    node.roleId = roleId;
    node.productId = productId;
    node.label = label;
    node.primary = true;
    if (allowMultiple)
    {
        foreach (ref n; state.nodes)
            if (n.roleId == roleId)
                n.primary = false;
    }
    state.nodes ~= node;
}

void removeNode(ref AIStackTopologyState state, string nodeId)
{
    TopologyNode[] kept;
    foreach (n; state.nodes)
        if (n.id != nodeId)
            kept ~= n;
    state.nodes = kept;
    TopologyEdge[] edges;
    foreach (e; state.edges)
        if (e.fromNodeId != nodeId && e.toNodeId != nodeId)
            edges ~= e;
    state.edges = edges;
}
