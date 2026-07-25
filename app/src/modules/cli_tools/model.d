module modules.cli_tools.model;

struct CliToolInstallMethod {
    string context;
    string command;
    bool interactive = true;
    bool mutableInstall = true;
    bool fallback;
    string auditNote;
}

struct CliToolContext {
    string id;
    string label;
    string family;
    string packageManager;
    bool mutableInstall = true;
    string detect;
    string inherits;
}

struct CliToolEntry {
    string id;
    string name;
    string description;
    string[] categories;
    string homepage;
    string docs;
    string verifyCommand;
    string launchCommand;
    CliToolInstallMethod[] install;
}

struct CliToolsCatalog {
    int version_;
    CliToolContext[] contexts;
    CliToolEntry[] tools;
}
