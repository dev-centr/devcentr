module modules.toolchain_advisor.settings;

import std.file : exists, readText, write, mkdirRecurse;
import std.path : buildPath, dirName;
import std.json : JSONValue, parseJSON, JSONType;
import modules.toolchain_advisor.cache : ToolchainAdvisorCache;

struct AdvisorSettings
{
    string definitionsRepoUrl = ToolchainAdvisorCache.defaults.repoUrl;
}

AdvisorSettings loadAdvisorSettings(string dataRoot)
{
    auto path = buildPath(dataRoot, "advisor-settings.json");
    AdvisorSettings s;
    if (!exists(path))
        return s;
    try
    {
        auto j = parseJSON(readText(path));
        if ("definitionsRepoUrl" in j && j["definitionsRepoUrl"].type == JSONType.string)
            s.definitionsRepoUrl = j["definitionsRepoUrl"].str;
    }
    catch (Exception) { }
    return s;
}

void saveAdvisorSettings(string dataRoot, AdvisorSettings s)
{
    auto path = buildPath(dataRoot, "advisor-settings.json");
    auto dir = dirName(path);
    if (!exists(dir))
        mkdirRecurse(dir);
    JSONValue j;
    j["definitionsRepoUrl"] = JSONValue(s.definitionsRepoUrl);
    write(path, j.toPrettyString());
}
