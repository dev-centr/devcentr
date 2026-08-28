/**
 * DevCentr → Open Terminal bridge stubs.
 *
 * Owns: project spawn registration hints + grid highlight API surface.
 * Does NOT own tiling essays (HCI) or session PTY (OpenShellOrg).
 *
 * Specs:
 *   https://github.com/openshellorg/shell-architecture (devcentr-terminal-manager, nested-tiling-zones)
 *   https://github.com/HCI-Nerdz/docs (contained-tiling, highlight-vs-pipe-linking)
 * Demo: https://hci-nerdz.github.io/shell-context-demo/#/manager
 */
module terminal_bridge;

public import terminal_bridge.types;
public import terminal_bridge.highlight;
