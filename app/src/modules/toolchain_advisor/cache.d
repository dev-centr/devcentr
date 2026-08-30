module modules.toolchain_advisor.cache;

import std.file : exists, mkdirRecurse, readText, write;
import std.path : buildPath, dirName, absolutePath;
import std.datetime : SysTime, Clock, hours;
import modules.util.proc : execute = executeRetry;
import std.json : JSONValue, parseJSON;

/// Git-backed cache for toolchain-advisor definitions (shared with devcentr.org).
class ToolchainAdvisorCache
{
    private string cacheRoot;
    private string definitionsRepoUrl;

    enum defaults {
        repoUrl = "https://github.com/dev-centr/toolchain-advisor.git",
        catalogSdlPath = "catalog/advisor.sdl",
        catalogJsonPath = "catalog/advisor.json",
    }

    this(string cacheRoot, string definitionsRepoUrl = defaults.repoUrl)
    {
        this.cacheRoot = absolutePath(cacheRoot);
        this.definitionsRepoUrl = definitionsRepoUrl;
    }

    @property string cacheRootPath() const { return cacheRoot; }

    @property string repoPath() const
    {
        return buildPath(cacheRoot, "repo");
    }

    @property string cachedCatalogSdlPath() const
    {
        return buildPath(repoPath, defaults.catalogSdlPath);
    }

    @property string cachedCatalogJsonPath() const
    {
        return buildPath(repoPath, defaults.catalogJsonPath);
    }

    /// Ensures clone/pull; returns true if catalog file exists after sync attempt.
    bool updateCache(bool forceful = false)
    {
        auto metadataPath = buildPath(cacheRoot, "metadata.json");
        bool needsUpdate = forceful;

        if (!needsUpdate && exists(metadataPath))
        {
            try
            {
                auto json = parseJSON(readText(metadataPath));
                auto lastStr = json["lastUpdated"].str;
                auto last = SysTime.fromISOExtString(lastStr);
                if (Clock.currTime() - last > hours(24))
                    needsUpdate = true;
            }
            catch (Exception)
            {
                needsUpdate = true;
            }
        }
        else if (!exists(metadataPath))
        {
            needsUpdate = true;
        }

        if (needsUpdate)
            performSync();

        return exists(cachedCatalogSdlPath) || exists(cachedCatalogJsonPath);
    }

    private bool performSync()
    {
        auto path = repoPath;
        if (!exists(path))
        {
            mkdirRecurse(cacheRoot);
            auto result = execute(["git", "clone", "--depth", "1", definitionsRepoUrl, path]);
            if (result.status != 0)
                return false;
        }
        else
        {
            auto result = execute(["git", "-C", path, "pull", "--ff-only"]);
            if (result.status != 0)
            {
                // Shallow clone may need reset; try fetch + reset
                execute(["git", "-C", path, "fetch", "origin"]);
                execute(["git", "-C", path, "reset", "--hard", "origin/main"]);
            }
        }

        JSONValue metadata;
        metadata["lastUpdated"] = JSONValue(Clock.currTime().toISOExtString());
        metadata["remoteUrl"] = JSONValue(definitionsRepoUrl);
        write(buildPath(cacheRoot, "metadata.json"), metadata.toString());
        return exists(cachedCatalogSdlPath) || exists(cachedCatalogJsonPath);
    }

    /// Prefer SDL from git; else compiled JSON in repo; else bundled fallback SDL/JSON.
    string resolveCatalogSdlPath(string fallbackSdlPath)
    {
        if (exists(cachedCatalogSdlPath))
            return cachedCatalogSdlPath;
        if (exists(fallbackSdlPath))
            return fallbackSdlPath;
        return cachedCatalogSdlPath;
    }

    string resolveCatalogJsonPath(string fallbackJsonPath)
    {
        if (exists(cachedCatalogJsonPath))
            return cachedCatalogJsonPath;
        return fallbackJsonPath;
    }

    @property string remoteUrl() const { return definitionsRepoUrl; }
}
