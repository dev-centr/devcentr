module modules.system_overview.tool_manager;

import modules.cli_tools.model;
import modules.cli_tools.catalog;
import std.array;
import std.algorithm;
import std.path;

struct ToolStatus {
    string name;
    string icon;
    string[] techStacks;
    bool isInstalled;
    string installLocation;
    bool onPath;
    string[] pathVariables;
    string toolId;
    string verifyCommand;
}

struct ToolStackGroup {
    string name;
    ToolStatus[] tools;
}

class ToolManager {
    ToolStatus[] allTools;
    CliToolsCatalog _catalog;

    this() {
        refresh(null);
    }

    void refresh(CliToolsCatalog* catalog) {
        allTools = [];
        _catalog = catalog !is null ? *catalog : CliToolsCatalog.init;

        if (_catalog.tools.length > 0) {
            foreach (t; _catalog.tools) {
                bool installed = isToolInstalled(t.verifyCommand);
                string icon = categoryIcon(t.categories);
                allTools ~= ToolStatus(
                    t.name.length ? t.name : t.id,
                    icon,
                    t.categories.length ? t.categories : ["CLI"],
                    installed,
                    installed ? t.launchCommand : "",
                    installed,
                    installed ? ["PATH"] : [],
                    t.id,
                    t.verifyCommand
                );
            }
            return;
        }

        // Fallback when catalog unavailable
        allTools ~= ToolStatus("GitHub CLI (gh)", "terminal", ["vcs", "devops"], isToolInstalled("gh --version"), "", true, ["PATH"], "gh", "gh --version");
        allTools ~= ToolStatus("Turso CLI", "database", ["database", "backend"], isToolInstalled("turso --version"), "", false, [], "turso", "turso --version");
    }

    private string categoryIcon(string[] categories) {
        foreach (c; categories) {
            if (c == "database") return "database";
            if (c == "deployment" || c == "hosting") return "cloud";
            if (c == "vcs" || c == "git") return "terminal";
            if (c == "containers" || c == "kubernetes") return "cpu";
            if (c == "immutable" || c == "package-manager") return "settings";
        }
        return "terminal";
    }

    ToolStackGroup[] getGroupedTools(bool installedOnly) {
        ToolStackGroup[] groups;
        string[] stacks;
        foreach (tool; allTools) {
            if (tool.isInstalled != installedOnly) continue;
            foreach (s; tool.techStacks) {
                if (!stacks.canFind(s)) stacks ~= s;
            }
        }
        sort(stacks);

        foreach (stack; stacks) {
            ToolStatus[] toolsInStack;
            foreach (tool; allTools) {
                if (tool.isInstalled != installedOnly) continue;
                if (tool.techStacks.canFind(stack))
                    toolsInStack ~= tool;
            }
            if (!toolsInStack.empty)
                groups ~= ToolStackGroup(stack, toolsInStack);
        }
        return groups;
    }
}
