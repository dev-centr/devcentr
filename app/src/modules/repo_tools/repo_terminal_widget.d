module modules.repo_tools.repo_terminal_widget;

import dlangui;
import modules.appearance.fonts : applyCodeFont;
import modules.appearance.settings : AppearanceSettings, appearanceDataRoot, loadAppearanceSettings,
    saveAppearanceSettings;
import modules.infra.logging : logInfo, logError;
import modules.repo_tools.env_refresh;
import modules.repo_tools.registry;
import std.conv : to;
import std.datetime : Clock;
import std.process : pipeProcess, Redirect, Config, wait, spawnProcess;
import std.string : strip;
import core.sync.mutex : Mutex;
import core.thread : Thread;

private class TerminalCommandState
{
    private Mutex _mutex;
    private string _output;
    private bool _completed;
    private int _exitCode = int.min;
    private size_t _version;

    this()
    {
        _mutex = new Mutex();
    }

    void appendLine(string line)
    {
        synchronized (_mutex)
        {
            _output ~= line ~ "\n";
            _version++;
        }
    }

    void markComplete(int exitCode)
    {
        synchronized (_mutex)
        {
            _completed = true;
            _exitCode = exitCode;
            _version++;
        }
    }

    void snapshot(out string output, out bool completed, out int exitCode, out size_t changeVersion)
    {
        synchronized (_mutex)
        {
            output = _output.dup;
            completed = _completed;
            exitCode = _exitCode;
            changeVersion = _version;
        }
    }
}

private class CommandBlockRefs
{
    VerticalLayout container;
    TextWidget header;
    EditBox output;
    TerminalCommandState state;
    string command;
    size_t lastVersion;
    bool completed;
    int exitCode;
}

private class RepoTerminalScrollWidget : ScrollWidget
{
    void jumpToY(int y)
    {
        scrollTo(0, y);
    }
}

class RepoTerminalWidget : VerticalLayout
{
    private string _repoRoot;
    private RepoToolsRegistry _repoTools;

    private StringListAdapter _indexAdapter;
    private ListWidget _indexList;
    private RepoTerminalScrollWidget _scroll;
    private VerticalLayout _blocks;
    private EditLine _commandInput;
    private TextWidget _status;

    private TextWidget _healthDot;
    private TextWidget _envNotice;
    private TextWidget _cmdPreview;
    private CheckBox _autoRunCheck;
    private Button _refreshBtn;

    private CommandBlockRefs[] _entries;
    private ulong _pollTimerId;
    private ulong _envWatchTimerId;

    private string _baselineFingerprint;
    private bool _envDrift;
    private EnvRefreshPlan _plan;

    this(string repoRoot, RepoToolsRegistry repoTools)
    {
        super();
        _repoRoot = repoRoot;
        _repoTools = repoTools;
        layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        buildUI();
        registerSelf();
        refreshPlanAndChrome();
        _baselineFingerprint = osEnvFingerprint();
        _envWatchTimerId = setTimer(3000);
    }

    private AppearanceSettings uiSettings()
    {
        return loadAppearanceSettings(appearanceDataRoot());
    }

    private void registerSelf()
    {
        ToolInstance inst;
        inst.id = "integrated-terminal-" ~ _repoRoot;
        inst.repoRoot = _repoRoot;
        inst.kind = ToolKind.builtinModule;
        inst.label = "Integrated Terminal";
        inst.icon = "terminal";
        inst.pid = 0;
        inst.executable = "";
        inst.startedAt = Clock.currTime;
        inst.lastSeenAliveAt = Clock.currTime;
        _repoTools.registerOrUpdateInstance(inst);
    }

    private void buildUI()
    {
        backgroundColor = 0x000000;
        padding(6);

        auto envChrome = new VerticalLayout();
        envChrome.layoutWidth(FILL_PARENT).padding(8).backgroundColor(0x141414)
            .margins(Rect(0, 0, 0, 6));

        auto statusRow = new HorizontalLayout();
        statusRow.layoutWidth(FILL_PARENT);
        _healthDot = new TextWidget(null, "●"d);
        _healthDot.fontSize(14).margins(Rect(0, 0, 8, 0));
        statusRow.addChild(_healthDot);
        _envNotice = new TextWidget(null, "Env in sync"d);
        _envNotice.layoutWidth(FILL_PARENT).textColor(0xCCCCCC).fontSize(10);
        statusRow.addChild(_envNotice);
        envChrome.addChild(statusRow);

        _cmdPreview = new TextWidget(null, ""d);
        applyCodeFont(_cmdPreview);
        _cmdPreview.layoutWidth(FILL_PARENT).textColor(0x9CCC65).fontSize(9)
            .margins(Rect(0, 6, 0, 4));
        envChrome.addChild(_cmdPreview);

        auto actionRow = new HorizontalLayout();
        actionRow.layoutWidth(FILL_PARENT);
        _refreshBtn = new Button(null, "Refresh Env"d);
        _refreshBtn.click = delegate(Widget w) {
            onRefreshEnvClicked();
            return true;
        };
        actionRow.addChild(_refreshBtn);

        _autoRunCheck = new CheckBox("envRefreshAutoRun", "Auto-run (no Enter)"d);
        _autoRunCheck.checked = uiSettings().envRefreshAutoRun;
        _autoRunCheck.checkChange = delegate(Widget w, bool checked) {
            auto s = uiSettings();
            s.envRefreshAutoRun = checked;
            saveAppearanceSettings(appearanceDataRoot(), s);
            refreshPlanAndChrome();
            return true;
        };
        actionRow.addChild(_autoRunCheck);
        envChrome.addChild(actionRow);

        addChild(envChrome);

        auto mainRow = new HorizontalLayout();
        mainRow.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);

        auto leftCol = new VerticalLayout();
        leftCol.layoutWidth(220).layoutHeight(FILL_PARENT).padding(6).backgroundColor(0x111111);
        leftCol.addChild(new TextWidget(null, "Commands"d).fontWeight(700).margins(Rect(0, 0, 0, 4)));
        _indexAdapter = new StringListAdapter();
        _indexList = new ListWidget("repoTerminalIndex");
        _indexList.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        _indexList.adapter = _indexAdapter;
        _indexList.itemClick = delegate(Widget w, int idx) {
            jumpToBlock(idx);
            return true;
        };
        leftCol.addChild(_indexList);
        mainRow.addChild(leftCol);

        _scroll = new RepoTerminalScrollWidget();
        _scroll.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        _scroll.backgroundColor = 0x1B1B1B;
        _blocks = new VerticalLayout();
        _blocks.layoutWidth(FILL_PARENT).padding(8);
        _scroll.contentWidget = _blocks;
        mainRow.addChild(_scroll);
        addChild(mainRow);

        auto toolbar = new HorizontalLayout();
        toolbar.layoutWidth(FILL_PARENT).padding(6).backgroundColor(0x1A1A1A).margins(Rect(0, 6, 0, 0));
        _commandInput = new EditLine("repoTerminalInput", ""d);
        _commandInput.layoutWidth(FILL_PARENT);
        applyCodeFont(_commandInput);
        toolbar.addChild(_commandInput);

        auto runBtn = new Button(null, "Run"d);
        runBtn.click = delegate(Widget w) { runCurrentCommand(); return true; };
        toolbar.addChild(runBtn);

        auto clearBtn = new Button(null, "Clear Input"d);
        clearBtn.click = delegate(Widget w) {
            _commandInput.text = UIString.fromRaw(""d);
            return true;
        };
        toolbar.addChild(clearBtn);

        auto refreshEnvBtn = new Button(null, "Refresh Env"d);
        refreshEnvBtn.click = delegate(Widget w) {
            onRefreshEnvClicked();
            return true;
        };
        toolbar.addChild(refreshEnvBtn);

        auto openExternalBtn = new Button(null, "Open External Terminal"d);
        openExternalBtn.click = delegate(Widget w) {
            openExternalTerminal();
            return true;
        };
        toolbar.addChild(openExternalBtn);
        addChild(toolbar);

        _status = new TextWidget(null, ""d);
        _status.textColor(0xAAAAAA).fontSize(9).margins(Rect(4, 4, 0, 0));
        addChild(_status);
    }

    private void refreshPlanAndChrome()
    {
        auto s = uiSettings();
        _plan = planEnvRefresh(s.terminalShell);
        if (_autoRunCheck)
            _autoRunCheck.checked = s.envRefreshAutoRun;

        auto mode = s.envRefreshAutoRun ? "inject+run" : "preview";
        auto hostNote = shellHostOnPath() ? "shell-host available" : "built-in external terminal";
        _cmdPreview.text = UIString.fromRaw(to!dstring(
                "[" ~ _plan.shellLabel ~ "] " ~ _plan.command ~ "  (" ~ _plan.sourceNote ~ ", " ~ mode ~ ")"));
        updateEnvNoticeText();
        _status.text = UIString.fromRaw(to!dstring(
                "Session shell: " ~ _plan.shellLabel ~ ". External: " ~ hostNote ~
                ". History is kept across env refresh."));
        if (window)
            window.update(true);
    }

    private void updateEnvNoticeText()
    {
        if (_envDrift)
        {
            _healthDot.textColor = 0xFFA726;
            _envNotice.text = UIString.fromRaw(
                "PATH / system env changed — refresh this session?"d);
            _envNotice.textColor = 0xFFCC80;
        }
        else
        {
            _healthDot.textColor = 0x66BB6A;
            _envNotice.text = UIString.fromRaw("Env in sync with OS store snapshot"d);
            _envNotice.textColor = 0xCCCCCC;
        }
    }

    private void onRefreshEnvClicked()
    {
        refreshPlanAndChrome();
        _commandInput.text = UIString.fromRaw(to!dstring(_plan.command));
        if (uiSettings().envRefreshAutoRun)
            runCurrentCommand();
        // After a successful refresh intent, re-baseline so light can return to green
        // once the user has acted (OS store itself is "current").
        _baselineFingerprint = osEnvFingerprint();
        _envDrift = false;
        updateEnvNoticeText();
        if (window)
            window.update(true);
    }

    private void checkEnvDrift()
    {
        auto fp = osEnvFingerprint();
        if (_baselineFingerprint.length == 0)
        {
            _baselineFingerprint = fp;
            return;
        }
        bool drifted = fp != _baselineFingerprint;
        if (drifted != _envDrift)
        {
            _envDrift = drifted;
            updateEnvNoticeText();
            if (drifted)
                refreshPlanAndChrome();
            else if (window)
                window.update(true);
        }
    }

    override bool onTimer(ulong id)
    {
        if (id == _envWatchTimerId)
        {
            checkEnvDrift();
            return true; // keep watching
        }
        if (id == _pollTimerId)
        {
            bool stillRunning = false;
            foreach (entry; _entries)
            {
                string output;
                bool completed;
                int exitCode;
                size_t changeVersion;
                entry.state.snapshot(output, completed, exitCode, changeVersion);
                if (changeVersion != entry.lastVersion)
                {
                    entry.lastVersion = changeVersion;
                    entry.output.text = UIString.fromRaw(to!dstring(output));
                    entry.header.text = UIString.fromRaw(to!dstring(entry.command ~ commandStatusSuffix(completed, exitCode)));
                    entry.container.backgroundColor = completed
                        ? (exitCode == 0 ? 0x2A2A2A : 0x3A2222)
                        : 0x223344;
                    requestLayout();
                    if (window)
                        window.update(true);
                }
                if (!completed)
                    stillRunning = true;
            }
            if (stillRunning)
                return true;
            _pollTimerId = 0;
            return false;
        }
        return super.onTimer(id);
    }

    private string commandStatusSuffix(bool completed, int exitCode)
    {
        if (!completed)
            return "  [running]";
        return exitCode == 0 ? "  [done]" : "  [failed " ~ to!string(exitCode) ~ "]";
    }

    private void runCurrentCommand()
    {
        string command = to!string(_commandInput.text).strip();
        if (command.length == 0)
            return;
        logInfo("Repo terminal run: " ~ command);
        auto state = new TerminalCommandState();
        auto refs = createCommandBlock(command, state);
        auto entryIndex = _entries.length;
        _entries ~= refs;
        _indexAdapter.add(to!dstring(indexLabelFor(entryIndex, command)));
        _commandInput.text = UIString.fromRaw(""d);

        auto shellCommand = command;
        auto repoRoot = _repoRoot;
        auto threadState = state;
        auto shell = resolveTerminalShell(uiSettings().terminalShell);
        auto args = shellInvokeArgs(shell, shellCommand);

        auto worker = new Thread({
            int exitCode = 1;
            try
            {
                auto pipes = pipeProcess(
                    args,
                    Redirect.stdout | Redirect.stderr, null, Config.none, repoRoot);
                foreach (line; pipes.stdout.byLine())
                    threadState.appendLine(line.idup);
                exitCode = wait(pipes.pid);
            }
            catch (Exception e)
            {
                threadState.appendLine("Error: " ~ e.msg);
                logError("Repo terminal command failed to start: " ~ e.msg);
            }
            threadState.markComplete(exitCode);
        });
        worker.start();

        if (_pollTimerId == 0)
            _pollTimerId = setTimer(250);
    }

    private CommandBlockRefs createCommandBlock(string command, TerminalCommandState state)
    {
        auto block = new VerticalLayout();
        block.layoutWidth(FILL_PARENT).padding(8).margins(Rect(6, 6, 6, 6)).backgroundColor(0x303030);

        auto header = new TextWidget(null, to!dstring(command ~ "  [running]"));
        applyCodeFont(header);
        header.fontWeight(700).margins(Rect(0, 0, 0, 6));
        block.addChild(header);

        auto output = new EditBox(null, ""d);
        output.layoutWidth(FILL_PARENT).layoutHeight(140);
        applyCodeFont(output);
        output.readOnly(true);
        output.backgroundColor = 0x1B1B1B;
        block.addChild(output);

        _blocks.addChild(block);
        requestLayout();
        if (window)
            window.update(true);

        auto refs = new CommandBlockRefs();
        refs.container = block;
        refs.header = header;
        refs.output = output;
        refs.state = state;
        refs.command = command;
        refs.lastVersion = 0;
        refs.completed = false;
        refs.exitCode = int.min;
        return refs;
    }

    private string indexLabelFor(size_t index, string command)
    {
        string label = command;
        if (index > 0)
        {
            string previous = _entries[index - 1].command;
            size_t prefixLen;
            while (prefixLen < previous.length && prefixLen < command.length && previous[prefixLen] == command[prefixLen])
                prefixLen++;
            if (prefixLen >= 6 && prefixLen < command.length)
                label = "..." ~ command[prefixLen .. $];
        }
        if (label.length > 36)
            label = label[0 .. 33] ~ "...";
        return label;
    }

    private void jumpToBlock(int idx)
    {
        if (idx < 0 || idx >= _entries.length)
            return;
        int y = _entries[idx].container.pos.top;
        _scroll.jumpToY(y < 0 ? 0 : y);
        if (window)
            window.update(true);
    }

    private void openExternalTerminal()
    {
        auto args = externalTerminalArgs(_repoRoot, uiSettings().terminalShell);
        try
        {
            spawnProcess(args);
            logInfo("Opened external terminal: " ~ args.to!string);
        }
        catch (Exception e)
        {
            logError("Open external terminal failed: " ~ e.msg);
            _status.text = UIString.fromRaw(to!dstring("Open external terminal failed: " ~ e.msg));
        }
    }
}
