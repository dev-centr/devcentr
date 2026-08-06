module modules.shell_integration.explorer_menu;

import std.array : join;

/// Backend currently providing file-manager integration.
enum FileManagerBackend
{
    none,
    modern, /// Windows 11 IExplorerCommand sparse package
    classic, /// HKCU cascading shell verbs
    linux, /// DES-EMA + per-FM adapters
}

/// Human-readable status for Appearance UI.
string explorerMenuStatusText()
{
    final switch (explorerMenuBackend())
    {
    case FileManagerBackend.modern:
        return "Status: installed (modern Win11 menu)";
    case FileManagerBackend.classic:
        return "Status: installed (classic cascading menu)";
    case FileManagerBackend.linux:
        return "Status: installed (Linux file-manager actions)";
    case FileManagerBackend.none:
        return "Status: not installed";
    }
}

FileManagerBackend explorerMenuBackend()
{
    version (Windows)
    {
        import modules.shell_integration.modern_package : modernPackageRegistered;
        import modules.shell_integration.classic_registry : classicExplorerMenuInstalled;
        if (modernPackageRegistered())
            return FileManagerBackend.modern;
        if (classicExplorerMenuInstalled())
            return FileManagerBackend.classic;
        return FileManagerBackend.none;
    }
    else version (linux)
    {
        import modules.shell_integration.linux_file_managers : linuxFileManagerMenusInstalled;
        return linuxFileManagerMenusInstalled()
            ? FileManagerBackend.linux
            : FileManagerBackend.none;
    }
    else
        return FileManagerBackend.none;
}

bool explorerMenuInstalled()
{
    return explorerMenuBackend() != FileManagerBackend.none;
}

/// Prefer modern Win11 menu; fall back to classic HKCU; on Linux emit FM adapters + DES-EMA.
string installExplorerMenu()
{
    version (Windows)
    {
        import modules.shell_integration.modern_package : installModernExplorerMenu, isWindows11OrNewer,
            modernDllPresent, shellAssetsRoot, modernPackageRegistered;
        import modules.shell_integration.classic_registry : installClassicExplorerMenu;

        string[] notes;
        if (isWindows11OrNewer() && modernDllPresent(shellAssetsRoot()))
        {
            auto modernMsg = installModernExplorerMenu();
            notes ~= modernMsg;
            if (modernPackageRegistered())
                return notes.join("\n");
            notes ~= "Modern registration did not stick; installing classic fallback.";
        }
        else if (isWindows11OrNewer())
        {
            notes ~= "Modern host DLL not built yet (see app/shell/README.adoc); using classic menu.";
        }
        else
        {
            notes ~= "OS is not Windows 11+; using classic cascading menu.";
        }
        notes ~= installClassicExplorerMenu();
        return notes.join("\n");
    }
    else version (linux)
    {
        import modules.shell_integration.linux_file_managers : installLinuxFileManagerMenus;
        return installLinuxFileManagerMenus();
    }
    else
        return "File-manager integration is supported on Windows and Linux only.";
}

string uninstallExplorerMenu()
{
    version (Windows)
    {
        import modules.shell_integration.modern_package : uninstallModernExplorerMenu;
        import modules.shell_integration.classic_registry : uninstallClassicExplorerMenu;
        string[] notes;
        notes ~= uninstallModernExplorerMenu();
        notes ~= uninstallClassicExplorerMenu();
        return notes.join("\n");
    }
    else version (linux)
    {
        import modules.shell_integration.linux_file_managers : uninstallLinuxFileManagerMenus;
        return uninstallLinuxFileManagerMenus();
    }
    else
        return "File-manager integration is supported on Windows and Linux only.";
}
