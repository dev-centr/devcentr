module terminal_bridge.types;

/// Hint sent when DevCentr spawns / focuses an Open Terminal session.
struct SpawnSessionRequest
{
	string projectId;
	string groupId;
	string preferredLayout = "projectGroupedManager";
	string workingDirectory;
	string[] argv;
}

/// Result of a spawn handshake (stub — localhost later).
struct SpawnSessionResult
{
	bool accepted;
	string sessionId;
	string surfaceId;
	string detail;
}
