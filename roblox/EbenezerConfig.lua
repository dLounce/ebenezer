-- EbenezerConfig  (ModuleScript, ServerScriptService)
--
-- Lives in ServerScriptService, never ReplicatedStorage: the shared secret must
-- not be readable by clients. Nothing here is needed on the client.

return {
	-- Your deployed FastAPI backend. No trailing slash.
	BASE = "https://ebenezer-2c4o.onrender.com",

	-- Must match EBENEZER_SECRET in the backend environment.
	--
	-- Deliberately a placeholder in the repo. The real value lives only in the
	-- published place (ServerScriptService is server-only, so clients never see
	-- it) and in the backend's environment variables. Set it in Studio after
	-- pasting this script; never commit it.
	SECRET = "REPLACE_ME",

	-- Free hosting sleeps after 15 min idle and cold-starts in ~50s. The server
	-- warms the backend on boot so the first stone of a session is not the one
	-- that waits.
	WARMUP_TRIES = 8,
	WARMUP_GAP = 8,

	-- Seconds before the same player can leave another stone.
	COOLDOWN = 25,

	-- Moment thresholds.
	LONELY_AFTER = 90,      -- alone in the world this long
	SURVIVED_FOR = 420,     -- no deaths for this long

	VERBOSE = true,
}
