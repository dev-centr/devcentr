module terminal_bridge.highlight;

/// Grid cell highlight API stub (highlight + dull; no pipe geometry).
interface GridHighlightApi
{
	/// Emphasize `projectId`; dull siblings.
	void highlightProject(string projectId);

	/// Clear highlight state.
	void clearHighlight();
}

/// In-process stub for UI wiring.
final class InProcessGridHighlight : GridHighlightApi
{
	string activeProjectId;
	string[] log;

	override void highlightProject(string projectId)
	{
		activeProjectId = projectId;
		log ~= "highlight " ~ projectId;
	}

	override void clearHighlight()
	{
		activeProjectId = null;
		log ~= "clear";
	}
}

/// Fake spawn registrar — records intent for Open Terminal association.
final class SpawnRegistrar
{
	import terminal_bridge.types;

	SpawnSessionRequest[] pending;
	SpawnSessionResult[] results;

	SpawnSessionResult registerSpawn(SpawnSessionRequest req)
	{
		pending ~= req;
		auto r = SpawnSessionResult(true, "sess-" ~ req.projectId, "hwnd:" ~ req.projectId, "stub accepted");
		results ~= r;
		return r;
	}
}
