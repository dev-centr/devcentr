module modules.shell_integration.actions;

/// Canonical file-manager actions shared by Windows and Linux emitters.
struct FmAction
{
    string id; /// Stable id (e.g. new-file)
    string label; /// Menu label
    string mode; /// CLI --mode= value
    string desemaProfile; /// DES-EMA profile name
}

immutable FmAction[] fmActions = [
    FmAction("new-file", "New File…", "new-file", "on_folder"),
    FmAction("new-project", "New Project…", "new-project", "on_folder"),
    FmAction("new-installer", "New Installer Project…", "new-installer", "on_folder"),
    FmAction("inplace-path", "Install in-place (add to PATH)", "inplace-path", "on_folder"),
    FmAction("open", "Open folder in DevCentr", "open", "on_folder"),
];
