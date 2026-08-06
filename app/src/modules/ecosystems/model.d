module modules.ecosystems.model;

/// Official vs community vs missing Toolchain Control Plane for a software ecosystem.
enum ControlPlaneStatus
{
    missing,
    community,
    official,
}

struct UnifiedControlPlane
{
    ControlPlaneStatus status = ControlPlaneStatus.missing;
    string entrypoint;
    string[] communityTools;
    bool advisory = true;
}

struct EcosystemRuntime
{
    string id;
    string name;
}

struct EcosystemPackageManager
{
    string id;
    string name;
    string status;   /// preferred | active | bundled | closed-aspirational | …
    string notes;
    string homepage;
}

struct EcosystemFramework
{
    string id;
    string name;
}

/// Parsed language ecosystem definition (`languages/<id>.sdl`).
struct EcosystemDefinition
{
    string id;
    string displayName;
    UnifiedControlPlane controlPlane;
    EcosystemRuntime[] runtimes;
    EcosystemPackageManager[] packageManagers;
    EcosystemFramework[] frameworks;

    /// True when the management UI should show the Toolchain Management gap advisory.
    bool showAdvisory() const
    {
        if (controlPlane.status == ControlPlaneStatus.official && !controlPlane.advisory)
            return false;
        return controlPlane.advisory || controlPlane.status != ControlPlaneStatus.official;
    }
}

enum defaultTcpDocsUrl =
    "https://docs.devcentr.org/general-knowledge/latest/explanation/infrastructure/toolchain-management.html";

enum defaultTcpAdvisoryCopy =
    "This ecosystem has no official Toolchain Control Plane yet (Toolchain Management Pattern). " ~
    "Version pinning and environment repair should live in the main entrypoint—not only in community tools. " ~
    "Community version managers are a stopgap.";
