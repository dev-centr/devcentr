module modules.toolchain_advisor.sdl_parser;

import sdlang;
import modules.toolchain_advisor.model;
import std.file : readText, exists;
import std.json;
import std.algorithm : canFind;

private string tagStr(Tag t, string name)
{
    auto x = t.getTag(name);
    if (x is null || x.values.length == 0)
        return "";
    return x.values[0].get!string;
}

private string[] tagStrList(Tag t, string name)
{
    string[] result;
    auto x = t.getTag(name);
    if (x is null)
        return result;
    foreach (v; x.values)
        result ~= v.get!string;
    foreach (child; x.tags)
        if (child.values.length > 0)
            result ~= child.values[0].get!string;
    return result;
}

private AdvisorTimelineEntry[] parseTimeline(Tag optionTag)
{
    AdvisorTimelineEntry[] entries;
    auto tl = optionTag.getTag("timeline");
    if (tl is null)
        return entries;
    foreach (m; tl.tags)
    {
        if (m.name != "milestone")
            continue;
        AdvisorTimelineEntry e;
        e.period = tagStr(m, "period");
        e.title = tagStr(m, "title");
        e.summary = tagStr(m, "summary");
        entries ~= e;
    }
    return entries;
}

private AdvisorAlternate[] parseAlternates(Tag optionTag)
{
    AdvisorAlternate[] alts;
    foreach (altTag; optionTag.tags)
    {
        if (altTag.name != "alternate")
            continue;
        AdvisorAlternate a;
        a.versus = tagStr(altTag, "versus");
        a.title = tagStr(altTag, "title");
        a.summary = tagStr(altTag, "summary");
        a.preferWhen = tagStr(altTag, "preferWhen");
        a.problemsSolved = tagStr(altTag, "problemsSolved");
        alts ~= a;
    }
    return alts;
}

private AdvisorOption parseOption(Tag optionTag)
{
    AdvisorOption opt;
    opt.id = tagStr(optionTag, "id");
    opt.label = tagStr(optionTag, "label");
    opt.era = tagStr(optionTag, "era");
    opt.overview = tagStr(optionTag, "overview");
    opt.timeline = parseTimeline(optionTag);
    opt.alternates = parseAlternates(optionTag);
    return opt;
}

private AdvisorStep parseStep(Tag stepTag)
{
    AdvisorStep step;
    step.id = tagStr(stepTag, "id");
    step.title = tagStr(stepTag, "title");
    step.hint = tagStr(stepTag, "hint");
    auto optionsTag = stepTag.getTag("options");
    if (optionsTag !is null)
    {
        foreach (optTag; optionsTag.tags)
        {
            if (optTag.name == "option")
                step.options ~= parseOption(optTag);
        }
    }
    foreach (optTag; stepTag.tags)
    {
        if (optTag.name == "option")
            step.options ~= parseOption(optTag);
    }
    return step;
}

private string[][string] parseMatch(Tag recTag)
{
    string[][string] rules;
    auto matchTag = recTag.getTag("match");
    if (matchTag is null)
        return rules;
    foreach (dimTag; matchTag.tags)
    {
        string[] allowed;
        foreach (v; dimTag.values)
            allowed ~= v.get!string;
        rules[dimTag.name] = allowed;
    }
    return rules;
}

private AdvisorRecommendation parseRecommendation(Tag recTag)
{
    AdvisorRecommendation rec;
    rec.id = tagStr(recTag, "id");
    rec.title = tagStr(recTag, "title");
    rec.summary = tagStr(recTag, "summary");
    rec.docs = tagStr(recTag, "docs");
    rec.tooling = tagStrList(recTag, "tooling");
    rec.caveats = tagStrList(recTag, "caveats");
    rec.matchRules = parseMatch(recTag);
    return rec;
}

AdvisorCatalog loadAdvisorCatalogFromSdl(string sdlPath)
{
    auto catalog = AdvisorCatalog();
    if (!exists(sdlPath))
        return catalog;

    Tag root;
    try
    {
        root = parseSource(readText(sdlPath), sdlPath);
    }
    catch (Exception)
    {
        return catalog;
    }

    auto ta = root.getTag("toolchainAdvisor");
    if (ta is null)
        ta = root;

    auto versionTag = ta.getTag("version");
    if (versionTag !is null && versionTag.values.length > 0)
        catalog.version_ = cast(int)versionTag.values[0].get!long;

    auto stepsRoot = ta.getTag("steps");
    if (stepsRoot !is null)
    {
        foreach (stepTag; stepsRoot.tags)
        {
            if (stepTag.name == "step")
                catalog.steps ~= parseStep(stepTag);
        }
    }

    auto recRoot = ta.getTag("recommendations");
    if (recRoot !is null)
    {
        foreach (recTag; recRoot.tags)
        {
            if (recTag.name == "recommendation")
                catalog.recommendations ~= parseRecommendation(recTag);
        }
    }

    return catalog;
}

/// Serialize catalog to JSON for web bundle / compile step.
string advisorCatalogToJson(const AdvisorCatalog catalog)
{
    JSONValue root;
    root["version"] = JSONValue(catalog.version_);
    JSONValue steps = JSONValue.emptyArray;
    foreach (step; catalog.steps)
    {
        JSONValue s;
        s["id"] = JSONValue(step.id);
        s["title"] = JSONValue(step.title);
        s["hint"] = JSONValue(step.hint);
        JSONValue opts = JSONValue.emptyArray;
        foreach (opt; step.options)
        {
            JSONValue o;
            o["id"] = JSONValue(opt.id);
            o["label"] = JSONValue(opt.label);
            o["era"] = JSONValue(opt.era);
            o["overview"] = JSONValue(opt.overview);
            JSONValue tl = JSONValue.emptyArray;
            foreach (m; opt.timeline)
            {
                JSONValue me;
                me["period"] = JSONValue(m.period);
                me["title"] = JSONValue(m.title);
                me["summary"] = JSONValue(m.summary);
                tl.array ~= me;
            }
            o["timeline"] = tl;
            JSONValue al = JSONValue.emptyArray;
            foreach (a; opt.alternates)
            {
                JSONValue ae;
                ae["versus"] = JSONValue(a.versus);
                ae["title"] = JSONValue(a.title);
                ae["summary"] = JSONValue(a.summary);
                ae["preferWhen"] = JSONValue(a.preferWhen);
                ae["problemsSolved"] = JSONValue(a.problemsSolved);
                al.array ~= ae;
            }
            o["alternates"] = al;
            opts.array ~= o;
        }
        s["options"] = opts;
        steps.array ~= s;
    }
    root["steps"] = steps;

    JSONValue recs = JSONValue.emptyArray;
    foreach (rec; catalog.recommendations)
    {
        JSONValue r;
        r["id"] = JSONValue(rec.id);
        r["title"] = JSONValue(rec.title);
        r["summary"] = JSONValue(rec.summary);
        r["docs"] = JSONValue(rec.docs);
        JSONValue tooling = JSONValue.emptyArray;
        foreach (t; rec.tooling)
            tooling.array ~= JSONValue(t);
        r["tooling"] = tooling;
        JSONValue caveats = JSONValue.emptyArray;
        foreach (c; rec.caveats)
            caveats.array ~= JSONValue(c);
        r["caveats"] = caveats;
        JSONValue match = JSONValue.emptyObject;
        foreach (stepId, allowed; rec.matchRules)
        {
            JSONValue arr = JSONValue.emptyArray;
            foreach (id; allowed)
                arr.array ~= JSONValue(id);
            match.object[stepId] = arr;
        }
        r["match"] = match;
        recs.array ~= r;
    }
    root["recommendations"] = recs;
    return root.toPrettyString();
}
