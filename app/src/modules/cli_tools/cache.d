module modules.cli_tools.cache;

import std.file : exists, mkdirRecurse, readText, write;
import std.path : buildPath, absolutePath;
import std.datetime : SysTime, Clock, hours;
import std.process : execute;
import std.json : JSONValue, parseJSON;

class CliToolsCatalogCache {
    private string cacheRoot;
    private string definitionsRepoUrl;

    enum defaults {
        repoUrl = "https://github.com/dev-centr/equivalence-rules-cli.git",
        catalogSdlPath = "catalog/tools.sdl",
        catalogJsonPath = "catalog/tools.json",
    }

    this(string cacheRoot, string definitionsRepoUrl = defaults.repoUrl) {
        this.cacheRoot = absolutePath(cacheRoot);
        this.definitionsRepoUrl = definitionsRepoUrl;
    }

    @property string repoPath() const {
        return buildPath(cacheRoot, "repo");
    }

    @property string cachedCatalogJsonPath() const {
        return buildPath(repoPath, defaults.catalogJsonPath);
    }

    @property string cachedCatalogSdlPath() const {
        return buildPath(repoPath, defaults.catalogSdlPath);
    }

    bool updateCache(bool forceful = false) {
        auto metadataPath = buildPath(cacheRoot, "metadata.json");
        bool needsUpdate = forceful;

        if (!needsUpdate && exists(metadataPath)) {
            try {
                auto json = parseJSON(readText(metadataPath));
                auto last = SysTime.fromISOExtString(json["lastUpdated"].str);
                if (Clock.currTime() - last > hours(24))
                    needsUpdate = true;
            } catch (Exception) {
                needsUpdate = true;
            }
        } else if (!exists(metadataPath)) {
            needsUpdate = true;
        }

        if (needsUpdate)
            performSync();

        return exists(cachedCatalogJsonPath) || exists(cachedCatalogSdlPath);
    }

    private bool performSync() {
        auto path = repoPath;
        if (!exists(path)) {
            mkdirRecurse(cacheRoot);
            auto result = execute(["git", "clone", "--depth", "1", definitionsRepoUrl, path]);
            if (result.status != 0)
                return false;
        } else {
            auto result = execute(["git", "-C", path, "pull", "--ff-only"]);
            if (result.status != 0) {
                execute(["git", "-C", path, "fetch", "origin"]);
                execute(["git", "-C", path, "reset", "--hard", "origin/main"]);
            }
        }

        JSONValue metadata;
        metadata["lastUpdated"] = JSONValue(Clock.currTime().toISOExtString());
        metadata["remoteUrl"] = JSONValue(definitionsRepoUrl);
        write(buildPath(cacheRoot, "metadata.json"), metadata.toString());
        return exists(cachedCatalogJsonPath);
    }

    string resolveCatalogJsonPath(string fallbackJsonPath) {
        if (exists(cachedCatalogJsonPath))
            return cachedCatalogJsonPath;
        return fallbackJsonPath;
    }
}
