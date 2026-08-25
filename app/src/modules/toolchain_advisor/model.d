module modules.toolchain_advisor.model;

import std.json;
import std.file;
import std.path;
import std.algorithm : canFind;
import std.string : toLower;
import std.conv : to;

struct AdvisorTimelineEntry
{
    string period;
    string title;
    string summary;
}

struct AdvisorAlternate
{
    string versus;
    string title;
    string summary;
    string preferWhen;
    string problemsSolved;
}

struct AdvisorOption
{
    string id;
    string label;
    string era;
    string overview;
    AdvisorTimelineEntry[] timeline;
    AdvisorAlternate[] alternates;
}

struct AdvisorStep
{
    string id;
    string title;
    string hint;
    AdvisorOption[] options;
}

struct AdvisorRecommendation
{
    string id;
    string title;
    string summary;
    string[] tooling;
    string[] caveats;
    string docs;
    string[][string] matchRules; /// stepId -> allowed option ids
    int matchScore; /// filled by ranker
}

struct AdvisorCatalog
{
    int version_ = 1;
    AdvisorStep[] steps;
    AdvisorRecommendation[] recommendations;
}

AdvisorOption findOption(AdvisorCatalog catalog, string stepId, string optionId)
{
    foreach (step; catalog.steps)
    {
        if (step.id != stepId)
            continue;
        foreach (opt; step.options)
            if (opt.id == optionId)
                return opt;
    }
    return AdvisorOption.init;
}

AdvisorOption parseOptionJson(JSONValue optVal)
{
    AdvisorOption opt;
    opt.id = optVal["id"].str;
    opt.label = optVal["label"].str;
    opt.era = ("era" in optVal) ? optVal["era"].str : "";
    opt.overview = ("overview" in optVal) ? optVal["overview"].str : "";
    if ("timeline" in optVal)
        foreach (m; optVal["timeline"].array)
        {
            AdvisorTimelineEntry e;
            e.period = ("period" in m) ? m["period"].str : "";
            e.title = ("title" in m) ? m["title"].str : "";
            e.summary = ("summary" in m) ? m["summary"].str : "";
            opt.timeline ~= e;
        }
    if ("alternates" in optVal)
        foreach (a; optVal["alternates"].array)
        {
            AdvisorAlternate alt;
            alt.versus = ("versus" in a) ? a["versus"].str : "";
            alt.title = ("title" in a) ? a["title"].str : "";
            alt.summary = ("summary" in a) ? a["summary"].str : "";
            alt.preferWhen = ("preferWhen" in a) ? a["preferWhen"].str : "";
            alt.problemsSolved = ("problemsSolved" in a) ? a["problemsSolved"].str : "";
            opt.alternates ~= alt;
        }
    return opt;
}

AdvisorCatalog loadAdvisorCatalog(string jsonPath)
{
    auto catalog = AdvisorCatalog();
    if (!exists(jsonPath))
        return catalog;

    auto root = parseJSON(readText(jsonPath));
    if (root.type != JSONType.object)
        return catalog;

    if ("steps" in root)
    {
        foreach (stepVal; root["steps"].array)
        {
            AdvisorStep step;
            step.id = stepVal["id"].str;
            step.title = stepVal["title"].str;
            step.hint = ("hint" in stepVal) ? stepVal["hint"].str : "";
            if ("options" in stepVal)
            {
                foreach (optVal; stepVal["options"].array)
                    step.options ~= parseOptionJson(optVal);
            }
            catalog.steps ~= step;
        }
    }

    if ("recommendations" in root)
    {
        foreach (recVal; root["recommendations"].array)
        {
            AdvisorRecommendation rec;
            rec.id = recVal["id"].str;
            rec.title = recVal["title"].str;
            rec.summary = recVal["summary"].str;
            if ("tooling" in recVal)
                foreach (t; recVal["tooling"].array)
                    rec.tooling ~= t.str;
            if ("caveats" in recVal)
                foreach (c; recVal["caveats"].array)
                    rec.caveats ~= c.str;
            rec.docs = ("docs" in recVal) ? recVal["docs"].str : "";
            if ("match" in recVal)
            {
                foreach (string stepId, ruleVal; recVal["match"].object)
                {
                    string[] allowed;
                    foreach (v; ruleVal.array)
                        allowed ~= v.str;
                    rec.matchRules[stepId] = allowed;
                }
            }
            catalog.recommendations ~= rec;
        }
    }

    return catalog;
}

/// Returns recommendations sorted by specificity (most matching criteria first).
AdvisorRecommendation[] rankRecommendations(AdvisorRecommendation[] recs, string[string] selections)
{
    AdvisorRecommendation[] scored;
    foreach (rec; recs)
    {
        auto copy = rec;
        if (rec.id == "fallback")
        {
            copy.matchScore = 0;
            scored ~= copy;
            continue;
        }

        int score = 0;
        int criteria = 0;
        foreach (stepId, allowed; rec.matchRules)
        {
            if (allowed.length == 0)
                continue;
            criteria++;
            if (stepId !in selections)
                continue;
            string chosen = selections[stepId];
            if (chosen.length == 0)
                continue;
            if (allowed.canFind(chosen) || allowed.canFind("auto"))
                score += 2;
            else
                score -= 4;
        }
        copy.matchScore = (criteria > 0) ? score : 0;
        scored ~= copy;
    }

    import std.algorithm : sort;
    scored.sort!((a, b) => a.matchScore > b.matchScore);
    return scored;
}

AdvisorRecommendation pickBestRecommendation(AdvisorRecommendation[] ranked)
{
    foreach (r; ranked)
    {
        if (r.id == "fallback")
            continue;
        if (r.matchScore > 0)
            return r;
    }
    foreach (r; ranked)
        if (r.id == "fallback")
            return r;
    return ranked.length > 0 ? ranked[0] : AdvisorRecommendation.init;
}

string[] filterOptionLabels(AdvisorOption[] options, string query)
{
    string q = toLower(query);
    string[] labels;
    foreach (opt; options)
    {
        if (q.length == 0 || toLower(opt.label).canFind(q) || toLower(opt.id).canFind(q))
            labels ~= opt.label;
    }
    return labels;
}

int indexOfOptionByLabel(AdvisorOption[] options, string label)
{
    foreach (i, opt; options)
        if (opt.label == label)
            return cast(int)i;
    return -1;
}
