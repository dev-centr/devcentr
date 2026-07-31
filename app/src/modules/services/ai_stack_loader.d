module modules.services.ai_stack_loader;

import sdlang;
import modules.services.ai_stack_model;
import std.algorithm : canFind, sort;
import std.array : array;
import std.conv : to;
import std.file : exists, getcwd, readText, thisExePath;
import std.path : buildPath, dirName;

private string tagStr(Tag t, string name)
{
    auto x = t.getTag(name);
    if (x is null || x.values.length == 0)
        return "";
    try
        return x.values[0].get!string;
    catch (Exception)
    {
        try
            return to!string(x.values[0].get!long);
        catch (Exception)
            return "";
    }
}

private int tagInt(Tag t, string name, int defaultVal = 0)
{
    auto x = t.getTag(name);
    if (x is null || x.values.length == 0)
        return defaultVal;
    try
        return cast(int)x.values[0].get!long;
    catch (Exception)
    {
        try
            return to!int(x.values[0].get!string);
        catch (Exception)
            return defaultVal;
    }
}

private string[] tagStrList(Tag t, string name)
{
    string[] result;
    foreach (child; t.tags)
    {
        if (child.name != name)
            continue;
        foreach (v; child.values)
        {
            try
                result ~= v.get!string;
            catch (Exception)
            {
            }
        }
    }
    return result;
}

private bool tagBool(Tag t, string name, bool defaultVal = false)
{
    auto x = t.getTag(name);
    if (x is null || x.values.length == 0)
        return defaultVal;
    try
        return x.values[0].get!bool;
    catch (Exception)
    {
        try
        {
            auto s = x.values[0].get!string;
            return s == "true" || s == "1";
        }
        catch (Exception)
            return defaultVal;
    }
}

string resolveServicesSdlPath(string fileName)
{
    string[] candidates = [
        buildPath(getcwd(), "src", "modules", "services", fileName),
        buildPath(getcwd(), "app", "src", "modules", "services", fileName),
        buildPath(dirName(thisExePath()), "src", "modules", "services", fileName),
        buildPath(dirName(thisExePath()), fileName),
    ];
    foreach (c; candidates)
        if (exists(c))
            return c;
    return candidates[0];
}

private Tag parseSdlFile(string path)
{
    if (!exists(path))
        return null;
    try
        return parseSource(readText(path), path);
    catch (Exception)
        return null;
}

private AIStackRole parseRole(Tag t)
{
    AIStackRole r;
    r.id = tagStr(t, "id");
    r.title = tagStr(t, "title");
    r.spineOrder = tagInt(t, "spineOrder", 0);
    r.cardinality = tagStr(t, "cardinality");
    r.memoryBin = tagStr(t, "memoryBin");
    r.fixedProduct = tagStr(t, "fixedProduct");
    r.notes = tagStr(t, "notes");
    r.catalogFrom = tagStrList(t, "catalogFrom");
    return r;
}

private AIStackEdgeKind parseEdgeKind(Tag t)
{
    AIStackEdgeKind e;
    e.id = tagStr(t, "id");
    e.title = tagStr(t, "title");
    e.fromRoles = tagStrList(t, "from");
    e.toRoles = tagStrList(t, "to");
    return e;
}

private AIStackLayoutRecipe parseLayoutRecipeRef(Tag t)
{
    AIStackLayoutRecipe r;
    r.id = tagStr(t, "id");
    r.arrangementRef = tagStr(t, "arrangementRef");
    if (r.arrangementRef.length == 0)
        r.arrangementRef = r.id;
    r.iconKey = tagStr(t, "iconKey");
    return r;
}

private void enrichLayoutFromArrangement(ref AIStackLayoutRecipe recipe, Tag arr)
{
    if (arr is null)
        return;
    if (recipe.title.length == 0)
        recipe.title = tagStr(arr, "title");
    recipe.fit = tagStr(arr, "fit");
    recipe.avoidWhen = tagStr(arr, "avoidWhen");
    recipe.preferShells = tagStrList(arr, "preferShells");
    recipe.preferInference = tagStrList(arr, "preferInference");
    recipe.preferInterconnects = tagStrList(arr, "preferInterconnects");
    recipe.uiHost = tagStr(arr, "uiHost");
    recipe.envHost = tagStr(arr, "envHost");
    recipe.inferenceHost = tagStr(arr, "inferenceHost");
    recipe.devcentrShell = tagStr(arr, "devcentrShell");
    if (recipe.iconKey.length == 0)
        recipe.iconKey = tagStr(arr, "iconKey");
}

private AIStackCatalogProduct parseProduct(Tag t, string category)
{
    AIStackCatalogProduct p;
    p.id = tagStr(t, "id");
    p.displayName = tagStr(t, "displayName");
    p.category = category;
    p.homepage = tagStr(t, "homepage");
    p.launchCommand = tagStr(t, "launchCommand");
    if (p.launchCommand.length == 0)
        p.launchCommand = tagStr(t, "detectCommand");
    p.status = tagStr(t, "status");
    p.notes = tagStr(t, "notes");
    p.backends = tagStrList(t, "backends");
    return p;
}

private AIStackDomainPack builtinFallbackPack()
{
    AIStackDomainPack pack;
    pack.id = "ai-stack";
    pack.title = "AI stack";
    pack.version_ = "0.1.0-fallback";
    pack.charter = "Cast only layered AI-stack concerns into a hierarchy so users get clean memory bins.";
    pack.guidedAddLabel = "Add an AI tool…";
    pack.canvasLabel = "AI stack";
    pack.humanShellProduct = "devcentr-repo-terminal";

    pack.roles = [
        AIStackRole("env-host", "Environment / ops host", 1, "1-n", "Where tools and the working tree run", "", null, ""),
        AIStackRole("inference-host", "Inference", 2, "0-n", "Where model weights run", "", ["inference", "interconnect"], ""),
        AIStackRole("agent-runtime", "Agent runtime", 3, "0-n", "What plans, tools, and edits", "", ["runtime"], ""),
        AIStackRole("control-plane-ui", "Control plane UI", 4, "0-n", "Agent manager / IDE surface", "", ["shell", "ide"], ""),
        AIStackRole("human-shell", "Human ops shell", 5, "1", "Always-on env-aware terminal on the env host",
            "devcentr-repo-terminal", null, "DevCentr repository browser terminal"),
    ];

    pack.layoutRecipes = [
        AIStackLayoutRecipe("all-local", "all-local", "arr-all-local", "All local",
            "Everyday; UI, tools, and repo on one machine.", "", null, null, null, "local", "local", "local-or-cloud-api", "local-repo-terminal"),
        AIStackLayoutRecipe("inference-remote-session-local", "inference-remote-session-local", "arr-infer-remote",
            "Inference remote, session local",
            "Session on laptop; owned GPU for weights.", "", null, null, null, "local", "local", "network-local", "local-repo-terminal"),
        AIStackLayoutRecipe("remote-env", "remote-env", "arr-remote-env", "Remote environment host",
            "Theo/T3-style: tools on a dedicated ops machine.", "", null, null, null, "local-or-thin", "remote", "cloud-or-with-env", "env-host-terminal"),
        AIStackLayoutRecipe("three-tier", "three-tier", "arr-three-tier", "Three-tier travel",
            "Travel laptop → env machine → DGX Spark inference.", "", null, null, null, "travel-laptop", "remote", "network-local", "env-host-terminal"),
    ];

    pack.products = [
        AIStackCatalogProduct("this-machine", "This machine", "env-host", "", "", "active", "Local env / ops host", null),
        AIStackCatalogProduct("remote-env-box", "Remote environment machine", "env-host", "", "", "active",
            "Dedicated ops host (Linux box, etc.)", null),
        AIStackCatalogProduct("cloud-api", "Vendor cloud API", "inference", "", "", "active", "Frontier hosted models", null),
        AIStackCatalogProduct("lm-studio", "LM Studio", "inference", "https://lmstudio.ai/", "", "active", "", null),
        AIStackCatalogProduct("ollama", "Ollama", "inference", "https://ollama.com/", "ollama", "active", "", null),
        AIStackCatalogProduct("llmster", "llmster (headless LM Studio)", "inference", "", "", "active", "DGX Spark / server", null),
        AIStackCatalogProduct("lm-link", "LM Link", "interconnect", "https://lmstudio.ai/link", "", "active", "", null),
        AIStackCatalogProduct("claude-code", "Claude Code", "runtime", "", "claude", "active", "", null),
        AIStackCatalogProduct("openai-codex", "OpenAI Codex", "runtime", "", "codex", "active", "", null),
        AIStackCatalogProduct("opencode", "OpenCode", "runtime", "https://opencode.ai", "opencode", "active", "", null),
        AIStackCatalogProduct("t3-code", "T3 Code", "shell", "https://github.com/pingdotgg/t3code", "", "active", "", null),
        AIStackCatalogProduct("hermes-desktop", "Hermes Desktop", "shell", "", "hermes", "active", "", null),
        AIStackCatalogProduct("lm-studio-bionic", "LM Studio Bionic", "shell", "https://lmstudio.ai/docs/bionic", "", "active", "", null),
        AIStackCatalogProduct("cursor", "Cursor", "ide", "https://cursor.com", "cursor", "active", "", null),
        AIStackCatalogProduct("devcentr-repo-terminal", "DevCentr repository terminal", "human-shell", "", "", "active",
            "Env-aware human ops shell", null),
    ];
    return pack;
}

AIStackDomainPack loadAIStackDomainPack()
{
    auto pack = builtinFallbackPack();
    auto packPath = resolveServicesSdlPath("ai_stack_domain_pack.sdl");
    auto root = parseSdlFile(packPath);
    if (root is null)
        return enrichFromRegistry(pack);

    Tag domain = root.getTag("domainPack");
    if (domain is null)
        domain = root;

    auto id = tagStr(domain, "id");
    if (id.length > 0)
        pack.id = id;
    auto title = tagStr(domain, "title");
    if (title.length > 0)
        pack.title = title;
    auto ver = tagStr(domain, "version");
    if (ver.length > 0)
        pack.version_ = ver;
    auto charter = tagStr(domain, "charter");
    if (charter.length > 0)
        pack.charter = charter;
    auto guided = tagStr(domain, "guidedAddLabel");
    if (guided.length > 0)
        pack.guidedAddLabel = guided;
    auto canvas = tagStr(domain, "canvasLabel");
    if (canvas.length > 0)
        pack.canvasLabel = canvas;
    auto human = tagStr(domain, "humanShellProduct");
    if (human.length > 0)
        pack.humanShellProduct = human;

    AIStackRole[] roles;
    AIStackEdgeKind[] edges;
    AIStackLayoutRecipe[] recipes;
    foreach (child; domain.tags)
    {
        if (child.name == "role")
            roles ~= parseRole(child);
        else if (child.name == "edgeKind")
            edges ~= parseEdgeKind(child);
        else if (child.name == "layoutRecipe")
            recipes ~= parseLayoutRecipeRef(child);
    }
    if (roles.length > 0)
        pack.roles = roles.sort!((a, b) => a.spineOrder < b.spineOrder).array;
    if (edges.length > 0)
        pack.edgeKinds = edges;
    if (recipes.length > 0)
        pack.layoutRecipes = recipes;

    return enrichFromRegistry(pack);
}

private AIStackDomainPack enrichFromRegistry(AIStackDomainPack pack)
{
    auto regPath = resolveServicesSdlPath("agent_shell_registry.sdl");
    auto root = parseSdlFile(regPath);
    if (root is null)
        return pack;

    Tag reg = root.getTag("registry");
    if (reg is null)
        reg = root;

    // Map arrangement id -> tag
    Tag[string] arrangements;
    foreach (child; reg.tags)
    {
        if (child.name != "arrangement")
            continue;
        auto aid = tagStr(child, "id");
        if (aid.length > 0)
            arrangements[aid] = child;
    }

    foreach (ref recipe; pack.layoutRecipes)
    {
        auto key = recipe.arrangementRef.length ? recipe.arrangementRef : recipe.id;
        if (key in arrangements)
            enrichLayoutFromArrangement(recipe, arrangements[key]);
        if (recipe.title.length == 0)
            recipe.title = recipe.id;
    }

    // Also add any arrangement not already listed as a recipe
    foreach (aid, tag; arrangements)
    {
        bool known = false;
        foreach (r; pack.layoutRecipes)
            if (r.id == aid || r.arrangementRef == aid)
            {
                known = true;
                break;
            }
        if (known)
            continue;
        AIStackLayoutRecipe extra;
        extra.id = aid;
        extra.arrangementRef = aid;
        enrichLayoutFromArrangement(extra, tag);
        if (extra.title.length == 0)
            extra.title = aid;
        pack.layoutRecipes ~= extra;
    }

    string[string] categoryByTagName = [
        "shell": "shell",
        "runtime": "runtime",
        "ide": "ide",
        "inference": "inference",
        "interconnect": "interconnect",
    ];

    bool hasProduct(string id)
    {
        foreach (p; pack.products)
            if (p.id == id)
                return true;
        return false;
    }

    foreach (child; reg.tags)
    {
        if (child.name !in categoryByTagName)
            continue;
        auto p = parseProduct(child, categoryByTagName[child.name]);
        if (p.id.length == 0 || hasProduct(p.id))
            continue;
        if (p.status == "archived")
            continue;
        pack.products ~= p;
    }

    // Ensure synthetic env hosts exist
    if (!hasProduct("this-machine"))
        pack.products ~= AIStackCatalogProduct("this-machine", "This machine", "env-host", "", "", "active",
            "Local env / ops host", null);
    if (!hasProduct("remote-env-box"))
        pack.products ~= AIStackCatalogProduct("remote-env-box", "Remote environment machine", "env-host", "", "",
            "active", "Dedicated ops host", null);
    if (!hasProduct("cloud-api"))
        pack.products ~= AIStackCatalogProduct("cloud-api", "Vendor cloud API", "inference", "", "", "active",
            "Frontier hosted models", null);
    if (!hasProduct("devcentr-repo-terminal"))
        pack.products ~= AIStackCatalogProduct("devcentr-repo-terminal", "DevCentr repository terminal",
            "human-shell", "", "", "active", "Env-aware human ops shell", null);

    return pack;
}
