# Codex credential import

At session start, Pi looks for Codex OAuth credentials in macOS Keychain, then
in `$CODEX_HOME/auth.json`. `CODEX_HOME` defaults to `~/.codex`. After import,
Pi’s built-in `openai-codex` provider handles request-time refresh.

If credentials fail to sync, check Keychain access, the OAuth fields, and JWT
expiry. When Pi already holds credentials, the extension only replaces OAuth
credentials for the same account with a still-valid source that expires later.
To switch accounts, use Pi login, or log out and start a new session to import
the current Codex account.

See the [synchronization policy and SDK integration details](API.md).
