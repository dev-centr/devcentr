// Thin IExplorerCommand host for Windows 11 File Explorer context menus.
// Launches sibling DevCentr / dev-center.exe with --mode=… --path=…
// Build: .\build.ps1 (requires MSVC). CLSID must match sparse-package/AppxManifest.xml.

#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif

#include <windows.h>
#include <shobjidl.h>
#include <shlwapi.h>
#include <strsafe.h>
#include <new>
#include <string>

#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "shlwapi.lib")

// {C0DEC411-7E11-4D00-9A55-001122334455}
static const CLSID CLSID_DevCentrExplorerRoot =
{ 0xc0dec411, 0x7e11, 0x4d00, { 0x9a, 0x55, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55 } };

static LONG g_moduleLocks = 0;
static HINSTANCE g_hInst = nullptr;

static void ModuleAddRef() { InterlockedIncrement(&g_moduleLocks); }
static void ModuleRelease() { InterlockedDecrement(&g_moduleLocks); }

enum class ModeKind { NewFile, NewProject, NewInstaller, EmitCi, InPlacePath, Open };

static std::wstring ModuleDirectory()
{
    wchar_t path[MAX_PATH] = {};
    GetModuleFileNameW(g_hInst, path, MAX_PATH);
    PathRemoveFileSpecW(path);
    return path;
}

static std::wstring FindDevCentrExe()
{
    const auto dir = ModuleDirectory();
    const wchar_t* candidates[] = {
        L"dev-center.exe",
        L"DevCentr.exe",
        L"devcentr.exe",
    };
    for (auto name : candidates)
    {
        std::wstring full = dir + L"\\" + name;
        if (PathFileExistsW(full.c_str()))
            return full;
    }
    // Optional override next to the DLL
    std::wstring ini = dir + L"\\DevCentrShell.ini";
    wchar_t buf[MAX_PATH] = {};
    GetPrivateProfileStringW(L"Shell", L"ExePath", L"", buf, MAX_PATH, ini.c_str());
    if (buf[0] && PathFileExistsW(buf))
        return buf;
    return {};
}

static HRESULT FirstFolderPath(IShellItemArray* items, std::wstring& out)
{
    out.clear();
    if (!items)
        return E_INVALIDARG;
    DWORD count = 0;
    HRESULT hr = items->GetCount(&count);
    if (FAILED(hr) || count == 0)
        return E_FAIL;
    IShellItem* item = nullptr;
    hr = items->GetItemAt(0, &item);
    if (FAILED(hr) || !item)
        return E_FAIL;
    PWSTR path = nullptr;
    hr = item->GetDisplayName(SIGDN_FILESYSPATH, &path);
    item->Release();
    if (FAILED(hr) || !path)
        return E_FAIL;
    out = path;
    CoTaskMemFree(path);
    return S_OK;
}

static HRESULT LaunchMode(ModeKind mode, IShellItemArray* items)
{
    std::wstring folder;
    HRESULT hr = FirstFolderPath(items, folder);
    if (FAILED(hr) || folder.empty())
        return hr;

    std::wstring exe = FindDevCentrExe();
    if (exe.empty())
        return HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND);

    const wchar_t* modeFlag = L"open";
    switch (mode)
    {
    case ModeKind::NewFile: modeFlag = L"new-file"; break;
    case ModeKind::NewProject: modeFlag = L"new-project"; break;
    case ModeKind::NewInstaller: modeFlag = L"new-installer"; break;
    case ModeKind::EmitCi: modeFlag = L"emit-ci"; break;
    case ModeKind::InPlacePath: modeFlag = L"inplace-path"; break;
    case ModeKind::Open: modeFlag = L"open"; break;
    }

    wchar_t cmdline[2048];
    hr = StringCchPrintfW(cmdline, ARRAYSIZE(cmdline),
        L"\"%s\" --mode=%s --path=\"%s\"", exe.c_str(), modeFlag, folder.c_str());
    if (FAILED(hr))
        return hr;

    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi = {};
    BOOL ok = CreateProcessW(
        exe.c_str(),
        cmdline,
        nullptr, nullptr, FALSE,
        0, nullptr, folder.c_str(),
        &si, &pi);
    if (!ok)
        return HRESULT_FROM_WIN32(GetLastError());
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return S_OK;
}

// --- Sub-command (non-creatable; owned by root enum) ---

class SubCommand final : public IExplorerCommand
{
public:
    SubCommand(ModeKind mode, const wchar_t* title)
        : m_ref(1), m_mode(mode), m_title(title)
    {
        ModuleAddRef();
    }

    ~SubCommand() { ModuleRelease(); }

    IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv) override
    {
        if (!ppv) return E_POINTER;
        *ppv = nullptr;
        if (riid == IID_IUnknown || riid == IID_IExplorerCommand)
        {
            *ppv = static_cast<IExplorerCommand*>(this);
            AddRef();
            return S_OK;
        }
        return E_NOINTERFACE;
    }

    IFACEMETHODIMP_(ULONG) AddRef() override { return InterlockedIncrement(&m_ref); }
    IFACEMETHODIMP_(ULONG) Release() override
    {
        LONG c = InterlockedDecrement(&m_ref);
        if (c == 0) delete this;
        return c;
    }

    IFACEMETHODIMP GetTitle(IShellItemArray*, PWSTR* name) override
    {
        return SHStrDupW(m_title, name);
    }

    IFACEMETHODIMP GetIcon(IShellItemArray*, PWSTR* icon) override
    {
        auto exe = FindDevCentrExe();
        if (exe.empty())
        {
            *icon = nullptr;
            return E_NOTIMPL;
        }
        return SHStrDupW(exe.c_str(), icon);
    }

    IFACEMETHODIMP GetToolTip(IShellItemArray*, PWSTR* tip) override
    {
        *tip = nullptr;
        return E_NOTIMPL;
    }

    IFACEMETHODIMP GetCanonicalName(GUID* guid) override
    {
        *guid = GUID_NULL;
        return S_OK;
    }

    IFACEMETHODIMP GetState(IShellItemArray*, BOOL, EXPCMDSTATE* state) override
    {
        *state = ECS_ENABLED;
        return S_OK;
    }

    IFACEMETHODIMP Invoke(IShellItemArray* items, IBindCtx*) override
    {
        return LaunchMode(m_mode, items);
    }

    IFACEMETHODIMP GetFlags(EXPCMDFLAGS* flags) override
    {
        *flags = ECF_DEFAULT;
        return S_OK;
    }

    IFACEMETHODIMP EnumSubCommands(IEnumExplorerCommand** enumCommands) override
    {
        *enumCommands = nullptr;
        return E_NOTIMPL;
    }

private:
    LONG m_ref;
    ModeKind m_mode;
    const wchar_t* m_title;
};

// --- Enum of three children ---

class SubEnum final : public IEnumExplorerCommand
{
public:
    SubEnum() : m_ref(1), m_index(0) { ModuleAddRef(); }
    ~SubEnum() { ModuleRelease(); }

    IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv) override
    {
        if (!ppv) return E_POINTER;
        *ppv = nullptr;
        if (riid == IID_IUnknown || riid == IID_IEnumExplorerCommand)
        {
            *ppv = static_cast<IEnumExplorerCommand*>(this);
            AddRef();
            return S_OK;
        }
        return E_NOINTERFACE;
    }

    IFACEMETHODIMP_(ULONG) AddRef() override { return InterlockedIncrement(&m_ref); }
    IFACEMETHODIMP_(ULONG) Release() override
    {
        LONG c = InterlockedDecrement(&m_ref);
        if (c == 0) delete this;
        return c;
    }

    IFACEMETHODIMP Next(ULONG celt, IExplorerCommand** rgelt, ULONG* fetched) override
    {
        if (!rgelt) return E_POINTER;
        ULONG got = 0;
        while (got < celt && m_index < 6)
        {
            IExplorerCommand* cmd = nullptr;
            switch (m_index)
            {
            case 0: cmd = new (std::nothrow) SubCommand(ModeKind::NewFile, L"New File…"); break;
            case 1: cmd = new (std::nothrow) SubCommand(ModeKind::NewProject, L"New Project…"); break;
            case 2: cmd = new (std::nothrow) SubCommand(ModeKind::NewInstaller, L"New Installer Project…"); break;
            case 3: cmd = new (std::nothrow) SubCommand(ModeKind::EmitCi, L"New Installer CI pipeline…"); break;
            case 4: cmd = new (std::nothrow) SubCommand(ModeKind::InPlacePath, L"Install in-place (add to PATH)"); break;
            case 5: cmd = new (std::nothrow) SubCommand(ModeKind::Open, L"Open folder in DevCentr"); break;
            }
            ++m_index;
            if (!cmd) return E_OUTOFMEMORY;
            rgelt[got++] = cmd;
        }
        if (fetched) *fetched = got;
        return (got == celt) ? S_OK : S_FALSE;
    }

    IFACEMETHODIMP Skip(ULONG celt) override
    {
        m_index = (m_index + celt > 6) ? 6 : m_index + celt;
        return (m_index < 6) ? S_OK : S_FALSE;
    }

    IFACEMETHODIMP Reset() override
    {
        m_index = 0;
        return S_OK;
    }

    IFACEMETHODIMP Clone(IEnumExplorerCommand** ppenum) override
    {
        if (!ppenum) return E_POINTER;
        auto* e = new (std::nothrow) SubEnum();
        if (!e) return E_OUTOFMEMORY;
        e->m_index = m_index;
        *ppenum = e;
        return S_OK;
    }

private:
    LONG m_ref;
    ULONG m_index;
};

// --- Root flyout ---

class RootCommand final : public IExplorerCommand
{
public:
    RootCommand() : m_ref(1) { ModuleAddRef(); }
    ~RootCommand() { ModuleRelease(); }

    IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv) override
    {
        if (!ppv) return E_POINTER;
        *ppv = nullptr;
        if (riid == IID_IUnknown || riid == IID_IExplorerCommand)
        {
            *ppv = static_cast<IExplorerCommand*>(this);
            AddRef();
            return S_OK;
        }
        return E_NOINTERFACE;
    }

    IFACEMETHODIMP_(ULONG) AddRef() override { return InterlockedIncrement(&m_ref); }
    IFACEMETHODIMP_(ULONG) Release() override
    {
        LONG c = InterlockedDecrement(&m_ref);
        if (c == 0) delete this;
        return c;
    }

    IFACEMETHODIMP GetTitle(IShellItemArray*, PWSTR* name) override
    {
        return SHStrDupW(L"DevCentr", name);
    }

    IFACEMETHODIMP GetIcon(IShellItemArray*, PWSTR* icon) override
    {
        auto exe = FindDevCentrExe();
        if (exe.empty())
        {
            *icon = nullptr;
            return E_NOTIMPL;
        }
        return SHStrDupW(exe.c_str(), icon);
    }

    IFACEMETHODIMP GetToolTip(IShellItemArray*, PWSTR* tip) override
    {
        return SHStrDupW(L"Create or open with DevCentr", tip);
    }

    IFACEMETHODIMP GetCanonicalName(GUID* guid) override
    {
        *guid = CLSID_DevCentrExplorerRoot;
        return S_OK;
    }

    IFACEMETHODIMP GetState(IShellItemArray*, BOOL, EXPCMDSTATE* state) override
    {
        *state = ECS_ENABLED;
        return S_OK;
    }

    IFACEMETHODIMP Invoke(IShellItemArray*, IBindCtx*) override
    {
        // Parent is a flyout; children handle Invoke.
        return S_OK;
    }

    IFACEMETHODIMP GetFlags(EXPCMDFLAGS* flags) override
    {
        *flags = ECF_HASSUBCOMMANDS;
        return S_OK;
    }

    IFACEMETHODIMP EnumSubCommands(IEnumExplorerCommand** enumCommands) override
    {
        if (!enumCommands) return E_POINTER;
        *enumCommands = new (std::nothrow) SubEnum();
        return *enumCommands ? S_OK : E_OUTOFMEMORY;
    }

private:
    LONG m_ref;
};

// --- Class factory ---

class ClassFactory final : public IClassFactory
{
public:
    ClassFactory() : m_ref(1) { ModuleAddRef(); }
    ~ClassFactory() { ModuleRelease(); }

    IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv) override
    {
        if (!ppv) return E_POINTER;
        *ppv = nullptr;
        if (riid == IID_IUnknown || riid == IID_IClassFactory)
        {
            *ppv = static_cast<IClassFactory*>(this);
            AddRef();
            return S_OK;
        }
        return E_NOINTERFACE;
    }

    IFACEMETHODIMP_(ULONG) AddRef() override { return InterlockedIncrement(&m_ref); }
    IFACEMETHODIMP_(ULONG) Release() override
    {
        LONG c = InterlockedDecrement(&m_ref);
        if (c == 0) delete this;
        return c;
    }

    IFACEMETHODIMP CreateInstance(IUnknown* outer, REFIID riid, void** ppv) override
    {
        if (outer) return CLASS_E_NOAGGREGATION;
        if (!ppv) return E_POINTER;
        *ppv = nullptr;
        auto* cmd = new (std::nothrow) RootCommand();
        if (!cmd) return E_OUTOFMEMORY;
        HRESULT hr = cmd->QueryInterface(riid, ppv);
        cmd->Release();
        return hr;
    }

    IFACEMETHODIMP LockServer(BOOL lock) override
    {
        if (lock) ModuleAddRef();
        else ModuleRelease();
        return S_OK;
    }

private:
    LONG m_ref;
};

extern "C" BOOL WINAPI DllMain(HINSTANCE hInst, DWORD reason, LPVOID)
{
    if (reason == DLL_PROCESS_ATTACH)
    {
        g_hInst = hInst;
        DisableThreadLibraryCalls(hInst);
    }
    return TRUE;
}

STDAPI DllCanUnloadNow()
{
    return (g_moduleLocks == 0) ? S_OK : S_FALSE;
}

STDAPI DllGetClassObject(REFCLSID clsid, REFIID riid, void** ppv)
{
    if (!ppv) return E_POINTER;
    *ppv = nullptr;
    if (clsid != CLSID_DevCentrExplorerRoot)
        return CLASS_E_CLASSNOTAVAILABLE;
    auto* factory = new (std::nothrow) ClassFactory();
    if (!factory) return E_OUTOFMEMORY;
    HRESULT hr = factory->QueryInterface(riid, ppv);
    factory->Release();
    return hr;
}
