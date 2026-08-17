module modules.project_recognizer.profiles_dir;

import std.file : dirEntries, exists, getcwd, isDir, SpanMode;
import std.path : absolutePath, buildPath, dirName;
import std.process : environment;

/// Locate project-map stack SDL files from the DUB cache, then hive fallbacks.
/// Returns an empty string when nothing exists (caller supplies a generic rule).
string findProjectMapStacksDir()
{
    foreach (c; stackDirCandidates())
    {
        if (c.length && exists(c) && isDir(c))
            return absolutePath(c);
    }
    return "";
}

string[] stackDirCandidates()
{
    string[] out_;
    void add(string p)
    {
        if (p.length)
            out_ ~= p;
    }

    if (auto env = environment.get("PROJECT_MAP_PROFILES"))
    {
        if (env.length)
        {
            auto stacked = buildPath(env, "stacks");
            add(exists(stacked) && isDir(stacked) ? stacked : env);
        }
    }

    foreach (root; dubPackageRoots("project-map"))
        add(buildPath(root, "profiles", "stacks"));

    foreach (hive; codeHiveRoots())
        add(buildPath(hive, "github.com", "openshellorg", "project-map", "profiles", "stacks"));

    add(absolutePath(buildPath(dirName(getcwd()), "..", "..", "openshellorg", "project-map", "profiles", "stacks")));
    add(buildPath(getcwd(), "src", "modules", "project-recognizer", "profiles"));

    return out_;
}

string[] dubPackageRoots(string packageName)
{
    string[] roots;
    foreach (packagesDir; dubPackagesDirs())
    {
        if (!packagesDir.length || !exists(packagesDir) || !isDir(packagesDir))
            continue;

        auto named = buildPath(packagesDir, packageName);
        if (exists(named) && isDir(named))
        {
            try
            {
                foreach (verDir; dirEntries(named, SpanMode.shallow))
                {
                    if (!verDir.isDir)
                        continue;
                    auto nested = buildPath(verDir.name, packageName);
                    roots ~= exists(nested) && isDir(nested) ? nested : verDir.name;
                }
            }
            catch (Exception)
            {
            }
        }

        try
        {
            foreach (entry; dirEntries(packagesDir, SpanMode.shallow))
            {
                if (!entry.isDir)
                    continue;
                import std.algorithm : startsWith;
                auto base = entry.name;
                import std.path : baseName;
                if (baseName(base).startsWith(packageName ~ "-"))
                    roots ~= base;
            }
        }
        catch (Exception)
        {
        }
    }
    return roots;
}

string[] dubPackagesDirs()
{
    string[] dirs;
    version (Windows)
    {
        if (auto local = environment.get("LOCALAPPDATA"))
            dirs ~= buildPath(local, "dub", "packages");
        if (auto home = environment.get("USERPROFILE"))
            dirs ~= buildPath(home, ".dub", "packages");
    }
    else
    {
        if (auto home = environment.get("HOME"))
            dirs ~= buildPath(home, ".dub", "packages");
        if (auto xdg = environment.get("XDG_CACHE_HOME"))
            dirs ~= buildPath(xdg, "dub", "packages");
    }
    return dirs;
}

string[] codeHiveRoots()
{
    string[] hives;
    if (auto env = environment.get("CODE_ROOT"))
        if (env.length)
            hives ~= env;
    if (auto env = environment.get("code"))
        if (env.length)
            hives ~= env;
    version (Windows)
    {
        hives ~= `C:\code`;
        hives ~= `Z:\code`;
    }
    else
    {
        if (auto home = environment.get("HOME"))
            hives ~= buildPath(home, "code");
    }
    return hives;
}
