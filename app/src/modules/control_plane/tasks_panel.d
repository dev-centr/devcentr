module modules.control_plane.tasks_panel;

import dlangui;
import sdlang;
import std.conv : to;
import std.datetime.systime : SysTime;
import std.file : exists, readText, timeLastModified;
import std.path : buildPath;
import std.process : environment;

/++
Live task list for the `devcentr` dropin session.

Agents write `tasks.sdl`. This panel reloads when the file's modification
time changes. The path matches `dropin.session.tasksPath("devcentr")`.
+/
class TasksPanel : VerticalLayout
{
    StringListAdapter adapter;
    ListWidget list;
    TextWidget pathLabel;
    TextWidget detail;
    string path;
    SysTime seen;
    bool loaded;
    ulong timerId;
    TaskRow[] rows;

    this()
    {
        super("tasksPanel");
        layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        path = devcentrTasksPath();

        pathLabel = new TextWidget(null, to!dstring(path));
        pathLabel.textColor = 0xAAAAAA;
        pathLabel.fontSize = 10;
        addChild(pathLabel);

        auto note = new TextWidget(null,
            "Agents write this file. The list reloads when the file changes."d);
        note.textColor = 0xAAAAAA;
        addChild(note);

        list = new ListWidget("tasksList");
        list.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        adapter = new StringListAdapter();
        list.adapter = adapter;
        list.itemClick = delegate(Widget source, int itemIndex)
        {
            showDetail(itemIndex);
            return true;
        };
        addChild(list);

        detail = new TextWidget(null, ""d);
        detail.layoutWidth(FILL_PARENT);
        addChild(detail);
    }

    void start()
    {
        reload();
        if (!timerId)
            timerId = setTimer(400);
    }

    override bool onTimer(ulong id)
    {
        if (id != timerId)
            return super.onTimer(id);
        reload();
        return true;
    }

    void reload()
    {
        pathLabel.text = to!dstring(path);
        if (!exists(path))
        {
            if (loaded && rows.length == 0 && seen == SysTime.init)
                return;
            rows = [];
            seen = SysTime.init;
            loaded = true;
            fill(["No tasks yet"d]);
            detail.text = "Write a tasks { } document to this path. dropin tasks write sends it."d;
            return;
        }

        SysTime stamp;
        try
            stamp = timeLastModified(path);
        catch (Exception)
            return;
        if (loaded && stamp == seen)
            return;
        seen = stamp;
        loaded = true;

        string error;
        TaskRow[] parsed;
        try
            parsed = readTaskFile(path);
        catch (Exception e)
            error = e.msg;

        if (error.length)
        {
            fill(["Could not read the task list"d]);
            detail.text = to!dstring(error);
            rows = [];
            return;
        }

        rows = parsed;
        dstring[] labels;
        if (rows.length == 0)
            labels ~= "No tasks yet"d;
        foreach (row; rows)
        {
            auto title = row.title.length ? row.title : row.id;
            auto status = row.status.length ? row.status : "open";
            labels ~= to!dstring(status ~ "  " ~ title);
        }
        auto keep = list.selectedItemIndex;
        fill(labels);
        if (keep >= 0 && keep < cast(int) rows.length)
            list.selectedItemIndex = keep;
        showDetail(list.selectedItemIndex);
    }

    private void fill(dstring[] labels)
    {
        adapter.clear();
        foreach (label; labels)
            adapter.add(label);
    }

    private void showDetail(int index)
    {
        if (index < 0 || index >= cast(int) rows.length)
        {
            if (rows.length == 0)
                detail.text = "The file is empty."d;
            return;
        }
        auto row = rows[index];
        auto text = row.title;
        if (row.id.length)
            text ~= "\n" ~ row.id;
        if (row.owner.length)
            text ~= "\n" ~ row.owner;
        if (row.detail.length)
            text ~= "\n" ~ row.detail;
        detail.text = to!dstring(text);
    }
}

private struct TaskRow
{
    string id;
    string title;
    string status;
    string owner;
    string detail;
}

string devcentrTasksPath()
{
    auto home = environment.get("DROPIN_HOME");
    if (home.length == 0)
    {
        home = environment.get("USERPROFILE");
        if (home.length == 0)
            home = environment.get("HOME");
        if (home.length == 0)
            home = ".";
        home = buildPath(home, ".dropin");
    }
    return buildPath(home, "sessions", "devcentr", "tasks.sdl");
}

private TaskRow[] readTaskFile(string path)
{
    auto text = readText(path);
    if (text.length && text[0] == '\uFEFF')
        text = text[1 .. $];
    auto root = parseSource(text, path);
    auto bucket = root.getTag("tasks");
    TaskRow[] rows;
    if (bucket is null)
        return rows;
    foreach (child; bucket.tags)
    {
        if (child.name != "task")
            continue;
        TaskRow row;
        if (child.values.length)
            row.id = child.values[0].get!string;
        row.title = childText(child, "title");
        row.status = childText(child, "status");
        row.owner = childText(child, "owner");
        row.detail = childText(child, "detail");
        rows ~= row;
    }
    return rows;
}

private string childText(Tag parent, string name)
{
    auto tag = parent.getTag(name);
    if (tag is null || tag.values.length == 0)
        return "";
    return tag.values[0].get!string;
}
