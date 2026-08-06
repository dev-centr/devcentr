module modules.ecosystems.ui;

import dlangui;
import modules.ecosystems.model;
import modules.infra.ui : openUrlInBrowser;
import modules.ui.advisory_banner : AdvisoryBanner;
import std.conv : to;

private enum Style {
    bg = 0x252525,
    muted = 0xAAAAAA,
    accent = 0x007AFF,
    body = 0xCCCCCC,
}

/// Deep management surface for one language ecosystem (advisory + bridge tools).
class EcosystemManagerPanel : VerticalLayout
{
    EcosystemDefinition _def;
    string _docsUrl;
    string _setupHowToUrl;

    this(EcosystemDefinition def, string docsUrl = defaultTcpDocsUrl, string setupHowToUrl = null)
    {
        super("ecosystemManagerPanel");
        layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).padding(8);
        _def = def;
        _docsUrl = docsUrl.length > 0 ? docsUrl : defaultTcpDocsUrl;
        _setupHowToUrl = setupHowToUrl;

        string statusLabel = controlPlaneStatusLabel(def.controlPlane.status);
        auto status = new TextWidget(null, to!dstring("Control plane: " ~ statusLabel));
        status.fontSize(11).fontWeight(700).textColor(Style.accent).margins(Rect(0, 0, 0, 8));
        addChild(status);

        if (def.controlPlane.entrypoint.length > 0)
        {
            auto ep = new TextWidget(null, to!dstring("Official entrypoint: " ~ def.controlPlane.entrypoint));
            ep.fontSize(9).textColor(Style.muted).margins(Rect(0, 0, 0, 6));
            addChild(ep);
        }

        auto actions = new HorizontalLayout();
        actions.layoutWidth(FILL_PARENT).margins(Rect(0, 0, 0, 8));

        auto btnDocs = new Button(null, "Toolchain Management docs"d);
        btnDocs.click = delegate(Widget w) {
            openUrlInBrowser(_docsUrl);
            return true;
        };
        actions.addChild(btnDocs);

        if (_setupHowToUrl.length > 0)
        {
            auto btnSetup = new Button(null, "Setup how-to"d);
            btnSetup.click = delegate(Widget w) {
                openUrlInBrowser(_setupHowToUrl);
                return true;
            };
            actions.addChild(btnSetup);
        }

        addChild(actions);

        if (def.controlPlane.communityTools.length > 0)
        {
            auto box = new VerticalLayout();
            box.layoutWidth(FILL_PARENT).padding(8).backgroundColor(Style.bg);
            box.addChild(new TextWidget(null, "Community bridge tools"d)
                .fontSize(11).fontWeight(700).textColor(Style.accent));
            auto help = new TextWidget(null,
                "Use these until the ecosystem ships an official Toolchain Control Plane in its main entrypoint."d);
            help.fontSize(9).textColor(Style.muted).margins(Rect(0, 0, 0, 6));
            box.addChild(help);

            foreach (tool; def.controlPlane.communityTools)
            {
                auto row = new TextWidget(null, to!dstring("• " ~ tool));
                row.fontSize(10).textColor(Style.body).margins(Rect(0, 0, 0, 2));
                box.addChild(row);
            }
            addChild(box);
        }

        if (def.runtimes.length > 0)
        {
            auto rtBox = new VerticalLayout();
            rtBox.layoutWidth(FILL_PARENT).margins(Rect(0, 12, 0, 0)).padding(8).backgroundColor(Style.bg);
            rtBox.addChild(new TextWidget(null, "Runtimes"d).fontSize(11).fontWeight(700).textColor(Style.accent));
            foreach (rt; def.runtimes)
            {
                string label = rt.name.length > 0 ? rt.name : rt.id;
                rtBox.addChild(new TextWidget(null, to!dstring("• " ~ label))
                    .fontSize(10).textColor(Style.body));
            }
            addChild(rtBox);
        }

        if (def.packageManagers.length > 0)
        {
            auto pmBox = new VerticalLayout();
            pmBox.layoutWidth(FILL_PARENT).margins(Rect(0, 12, 0, 0)).padding(8).backgroundColor(Style.bg);
            pmBox.addChild(new TextWidget(null, "Package managers"d).fontSize(11).fontWeight(700).textColor(Style.accent));
            foreach (pm; def.packageManagers)
            {
                string label = pm.name.length > 0 ? pm.name : pm.id;
                if (pm.status.length)
                    label ~= " [" ~ pm.status ~ "]";
                pmBox.addChild(new TextWidget(null, to!dstring("• " ~ label))
                    .fontSize(10).textColor(Style.body));
                if (pm.notes.length)
                {
                    pmBox.addChild(new TextWidget(null, to!dstring("  " ~ pm.notes))
                        .fontSize(8).textColor(Style.muted).margins(Rect(8, 0, 0, 4)));
                }
            }
            addChild(pmBox);
        }
    }
}

string controlPlaneStatusLabel(ControlPlaneStatus s)
{
    final switch (s)
    {
    case ControlPlaneStatus.missing:
        return "missing (no official plane)";
    case ControlPlaneStatus.community:
        return "community bridges only";
    case ControlPlaneStatus.official:
        return "official";
    }
}

/// Build the page-top advisory widget when the ecosystem definition requires it.
Widget maybeControlPlaneAdvisory(EcosystemDefinition def, string docsUrl = defaultTcpDocsUrl)
{
    if (!def.showAdvisory())
        return null;
    return new AdvisoryBanner(defaultTcpAdvisoryCopy, docsUrl, true);
}
