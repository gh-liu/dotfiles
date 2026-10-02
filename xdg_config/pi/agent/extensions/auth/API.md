# Codex credential import (Pi 1.0.0)

The extension retains the built-in `openai-codex` provider and Pi's normal
request-time OAuth refresh. It does not register a replacement provider, poll,
refresh tokens itself, or open a second credential store.

## Public API boundary

Reviewed the installed Pi 1.0.0 `docs/providers.md`, `docs/extensions.md`,
`docs/sdk.md`, authentication-related `docs/configuration.md`, `docs/models.md`,
`docs/custom-provider.md`, and the SDK credentials and custom-provider examples.
The shipped declarations establish the exact boundary:

- `core/extensions/types.d.ts`: the context exposes `modelRegistry`, not a
  mutable credential store or `ModelRuntime`.
- `core/model-registry.d.ts`: resolved auth/status/provider access and public
  `refresh()` are available, but no OAuth import or stored-credential mutation.
- `core/model-runtime.d.ts`: `login`, `logout`, runtime API-key overrides and
  credential metadata are public. None imports an existing OAuth credential;
  `credentials` is private. The SDK can supply a `CredentialStore` at creation,
  but an already-loaded extension cannot replace that store.
- `pi-ai/dist/auth/types.d.ts`: public `CredentialStore.modify()` is the locked
  read-modify-write contract used by Pi's OAuth rotation.
- coding-agent's root export exposes `readStoredCredential`, not `AuthStorage`.
  Reading the default auth file would not identify SDK custom storage anyway.

Therefore one isolated, feature-checked `modelRegistry.runtime.credentials`
bridge remains necessary for automatic import into the *actual* runtime store.
It now uses the public `CredentialStore` type rather than an invented mutation
signature. Remove the bridge when Pi exposes store access or an atomic OAuth
import operation on the extension context. Registering a custom provider just
for importing credentials would alter built-in login/auth behavior and is not
an equivalent minimal replacement.

## Synchronization policy

- No credential access during extension discovery. Read Codex at `session_start`
  so a later session can see a new source; overlapping starts share one sync.
- Preserve keychain-first lookup, canonical CODEX_HOME hashing and file fallback.
  Bound the macOS security command to two seconds. Missing/bad sources are quiet.
- Compare inside the runtime store's lock. Import when no credential exists
  (including an expired source, allowing Pi's own refresh to bootstrap).
- For existing auth, update only same-account OAuth with strictly later expiry
  and a still-valid source. Keep API keys, different accounts, equal/newer tokens,
  and unknown-age current credentials. Expiry is a conservative ordering proxy,
  not proof of refresh-token validity; deliberate account switching uses Pi login
  or logout followed by a new session. No forced override command is added.
- Preserve existing provider metadata; refresh the public model snapshot offline
  only after a write. If refresh fails after persistence, retry only refresh on
  the next session start. Errors never echo storage/provider error payloads.

## Validation

From `xdg_config/pi/agent/extensions`, after dependency installation finishes:

```sh
npm run typecheck:auth
npx vitest run auth/codex-auth.test.ts auth/index.test.ts
```

The typecheck includes the entry point and regression tests. Tests use injected
readers and mocked source/store/registry: no actual auth files, keychain calls,
provider requests or credentials are needed. Live keychain compatibility and the
private store bridge must still be checked by a consenting user after upgrades.
