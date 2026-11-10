# Widget REST authentication and Jali credential boundary

Verified from local source on 2026-11-10. No private API calls, credentials, environment files or production changes were used. This report describes source behavior, not verified deployment parity.

## Answer

`cache_key` directly authenticates REST requests by looking up cached user credentials (`{id: user_id}`). It does **not** resolve, exchange or validate an existing OAuth access token. Its guard performs no OAuth expiry/revocation check. OAuth access tokens independently authenticate through the Passport API guard when sent as `Authorization: Bearer <access token>`. When `cache_key` is present, the application authentication middleware chooses that guard ahead of API/Bearer authentication, including when both credentials are supplied. [B1–B4]

The located widget repository is `/Users/frdinawan/WebstormProjects/jala-app-widgets-next`; narrow directory inventory found no `jala-widget-app` checkout and `/Users/frdinawan/WebStorm` does not exist. Its actual JALA integration uses `cache_key` from the widget URL, forwards it to `/api/profile` and other REST routes, and derives profile identity from the backend response. There is no `access_token` query-state or OAuth exchange implementation in this checkout. A generic Bearer helper exists, but its inspected call sites in `services/event/index.ts` are Airtable operations; that helper does not establish JALA OAuth selection or precedence in the widget. The backend's separate Passport support establishes the OAuth REST path. [W1–W4, B4–B6]

## Existing request flow

1. The Laravel BYOP host POSTs `/api/request_access`, receives `data.cache_key`, and places it in the iframe URL. The access endpoint requires `auth:api`; absent an email override it stores the currently authenticated user's ID under a random key. Supplying `email` can select a different user under existing admin/investor-admin/self checks. Jali must not use that impersonation option. [B1, B7]
2. Widget `CacheKeyProvider` reads URL query state `cache_key`. Its Axios client GETs `/api/profile?cache_key=…`; profile writes also include the key as a query parameter. Other legacy profile service code sends it in the request body for PUT. This is credential transport, not an exchange endpoint. [W1, W2]
3. `Authenticate::handle` checks `request->has('cache_key')` first and authenticates only the cache-key guard for that branch. An invalid present cache key does not fall back to a valid Bearer token. `Localization` also switches the selected guard when the parameter exists. [B2]
4. `CacheKeyGuard` inherits Laravel `TokenGuard` extraction: query `cache_key`, input `cache_key`, Bearer fallback, then Basic password. However, the application middleware's guard choice still depends on the `cache_key` parameter being present. A bare cache key in a Bearer header normally selects Passport on `auth:api`, not the cache-key guard. `Cache-Key` is not a recognized input in this guard. A proxy helper emits that header while also forwarding the query; do not infer header-only auth support from it. [B2, B3, B8]
5. The cache guard fetches the cached credentials and calls the configured users provider. Passport independently verifies JWT signature/time validity/revocation, loads the token's subject user and token record, and rejects revoked clients. The API profile action reads `request()->user()` and authorizes viewing that user. Farm REST actions retain their controller policy checks. Credential possession identifies a user; it does not replace downstream operation/record authorization. [B3–B6, B9]

## Expiry, revocation and exposure

- The access endpoint writes `cache()->put(random_key, {id}, 120)`. The installed and locked Laravel version is **5.5.49**, whose numeric cache TTL is **minutes**, so the intended lifetime here is **120 minutes (two hours), not 120 seconds**. Cache eviction/deletion can end access earlier. No refresh or one-time consumption occurs in the inspected cache guard; the middleware's forget block is commented out. [B1–B3, B10]
- The cache entry contains only user identity, with no source session/token identifier. Therefore revoking the OAuth token used to obtain a cache key does not revoke that cache key through this code; the cache lookup has nothing to check against that revocation. The inspected browser logout only logs out the session and invalidates it; it does not delete cache keys or revoke Passport tokens. These are source-local conclusions, not a claim about every production hook. The middleware still rejects deactivated users. [B1–B3, B11]
- Passport application configuration sets access-token expiry to three months and refresh-token expiry to six months; issuance varies by grant (the social-login controller creates a personal access token and returns `expires_at`, not a refresh token). These settings do not justify assuming every token lasts three months or every access token can refresh. Use the actual issued expiry and supported grant contract. Passport token revocation is checked on subsequent Bearer calls; the installed token controller can revoke only a token found for the current user. [B5, B6, B12]
- Widget cache keys are deliberately browser-visible in iframe/navigation URLs, query-state and browser-issued API requests. They are reusable bearer-equivalent capabilities during their cache lifetime. URL/history/referrer/proxy-log exposure is consequently a design risk; this research did not inspect or assert actual log retention or leakage. The existing widget flow is not server-only secret custody. [W1, W2, B7]

## Recommended Jali approach — proposal, not existing implementation

Use **server-held, user-bound Passport REST credentials** behind the authenticated Next.js backend and trusted REST broker described in `connection-design.md`. Resolve the JALA user from authenticated backend identity and a verified profile response; bind that ID to the Felix contact and broker execution identity. Keep Felix keys, JALA access/refresh credentials and owner credentials outside browser URLs, model context, prompts and worker files. The model may request an operation and resource IDs; it must not choose a user, credential, cache key, Authorization header, arbitrary API origin or endpoint. The broker selects the credential from trusted identity, invokes supported existing REST routes with **only** `Authorization: Bearer …`, and preserves the JALA API's current authorization checks. Strip/reject tool-supplied `cache_key` so it cannot override Bearer identity. No MCP endpoint, MCP scope or MCP consent flow is needed for this REST design.

This requires a concrete server-side token issuance/storage lifecycle; the widget checkout does not provide one for Jali. Decide whether existing authenticated JALA backend code issues a per-user integration token or a supported OAuth grant provides one; do not invent an endpoint or assume existing login exposes a reusable token to Next.js. If renewable access is required, use a grant that actually issues refresh tokens and store them server-side; otherwise expiry must cause reauthentication. Handle 401/expired/revoked tokens without substituting another user's credentials; revoke/delete the user's integration credential on disconnect and define logout behavior explicitly. Server-side JALA session authorization must gate every chat request, reconnect and artifact read. Per-user worker/files/execution isolation remains required in Felix; a token broker alone does not implement it.

A cache key can be used as an explicitly bounded compatibility handoff if needed, but it should not become Jali's durable credential: its direct cache capability has a short cache-dependent lifetime, browser exposure and no source-token revocation linkage. If used, validate via `/api/profile`, bind the returned identity to the authenticated user, keep it outside model control, fail closed on expiry, and require a newly authenticated handoff rather than claiming it refreshes itself. Do not mix it with OAuth Bearer on the same request.

## Outstanding validation before implementation acceptance

Confirm production checkout/dependency parity and actual token issuance grant; test expiry and revocation of the issued credential; test invalid cache key plus valid Bearer precedence; and verify two concurrent users cannot select each other's contacts, tokens, files or REST resources. Check cache-key invalidation/logout behavior separately if retaining that compatibility path. This research establishes the authentication mechanism; it does not certify all REST routes or deploy Jali.

## Primary-source references

Paths and lines below refer to the inspected local checkouts. Source anchors are available without live private API access. Working trees were read only; jala-web had no tracked changes at inspection.

Backend root: `/Users/frdinawan/PhpstormProjects/jala-web`, HEAD `ab4757ea189f1847c7ffacd44bcd3c3b4c071ffc`.
Widget root: `/Users/frdinawan/WebstormProjects/jala-app-widgets-next`, HEAD `a2a42dd92d558cab4168d9e5dfbfea0ff9aed34e`.
Installed vendor source below is corroborated by `composer.lock` (Laravel 5.5.49, Passport 4.0.3, league/oauth2-server 6.1.1); vendor code is not necessarily tracked by Git.

| ID | Source relative to the indicated root | Evidence |
| --- | --- | --- |
| B1 | Backend `routes/api.php:36`; `app/Http/Controllers/Api/RequestAccessController.php:22–57` | Access endpoint, auth, optional target override, cached ID, TTL |
| B2 | Backend `app/Http/Middleware/Authenticate.php:30–78`; `app/Http/Middleware/Localization.php:20` | Guard precedence, deactivation, no active consumption |
| B3 | Backend `app/Guards/CacheKeyGuard.php:19–49`; `vendor/laravel/framework/src/Illuminate/Auth/TokenGuard.php:81–97` | Cache identity lookup; query/input/header extraction order |
| B4 | Backend `config/auth.php:39–53`; `app/Providers/AuthServiceProvider.php:148–150` | Passport API and independent cache guard |
| B5 | Backend `vendor/laravel/passport/src/Guards/TokenGuard.php:87–139` | Bearer and Passport-cookie paths; subject/token/client resolution |
| B6 | Backend `vendor/league/oauth2-server/src/AuthorizationValidators/BearerTokenValidator.php:56–90`; `vendor/laravel/passport/src/Bridge/AccessTokenRepository.php:85–87`; `vendor/laravel/passport/src/TokenRepository.php:88–106` | JWT signature/time checks and persisted revocation |
| B7 | Backend `resources/assets/js/components/byop/Host.vue:63–72`; `resources/assets/js/components/byop/bridge.js:22–40` | Host grant acquisition and iframe URL |
| B8 | Backend `app/Helpers/ProxyRequest.php:59–69` | Proxy forwards query and emits Cache-Key header |
| B9 | Backend `app/Http/Controllers/Api/ProfileController.php:195–198,241–248`; `app/Http/Controllers/Api/FarmController.php:425,438,586,602,746` | Authenticated profile and operation policies |
| B10 | Backend `composer.lock:4796–4797,4934–4935,5612–5613`; `vendor/laravel/framework/src/Illuminate/Cache/Repository.php:178–202,540–554` | Dependency versions and numeric minute semantics |
| B11 | Backend `app/Http/Controllers/Auth/LoginController.php:231–240` | Inspected browser logout implementation |
| B12 | Backend `app/Providers/AuthServiceProvider.php:135–146`; `app/Http/Controllers/Api/AuthController.php:73–86`; `vendor/laravel/passport/src/Http/Controllers/AuthorizedAccessTokenController.php:52–62` | Lifetime configuration, issuance payload, user-bound revocation |
| W1 | Widget `context/cache-key-context.tsx:48–60,77–92,133–155` | URL credential, profile query transport and error handling |
| W2 | Widget `services/profile/index.ts:4–25`; `context/farm-context.tsx:50–57` | Body/query cache-key forwarding |
| W3 | Widget `services/index.ts:13–19`; `services/event/index.ts:84–101` | Generic Bearer helper and Airtable usage |
| W4 | Widget source search for literal `access_token` (no matches), and `cache_key` call-site inspection | No demonstrated widget OAuth selection/exchange; bounded absence finding |

Related local planning: [connection design](../connection-design.md), [execution isolation research](per-user-tools-and-credentials.md), [ticket 10](../issues/10-verify-widget-rest-auth.md). These files record requirements/proposals; source references above own the behavior claims.
