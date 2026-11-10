# Jali ingress and deployment preflight

Issue: `../issues/11-verify-jali-ingress.md` · Checked 2026-11-10, approximately 06:49 UTC.

## Answer

`https://jali-agent.jala.tech` currently reaches `54.254.9.119`, not db (`139.162.22.68`). Both this name and a randomized sibling return the same validated wildcard certificate and byte-identical nginx 404. This is strong evidence of wildcard/default ingress behavior, not an identifiable Jali application. Public DNS alone cannot distinguish a dedicated record from a wildcard answer. The parent researcher additionally verified the authoritative Route53 record inventory using local AWS profile `jala-tech`: public zone `/hostedzone/Z3UDFHBXN534SE` contains the wildcard A record and **no exact `jali-agent.jala.tech` record**. Together, these establish that the present resolution comes from the wildcard. AWS read API access is available; DNS write permission was not tested.

The proposed independent Jali installation can use `/home/farid/felix-agent-jali`, UID/GID `1002:1002`, a distinct Compose project, and loopback port `3111`. These are unoccupied in this snapshot. Public ingress requires an explicit DNS A record to db and a new nginx virtual host/certificate. This report makes no live changes. A stock Felix deployment does not deliver the user-requested per-user execution isolation; that remains a code prerequisite.

## Read-only observations and primary evidence

All host observations came from the already authorized `ssh root@db.jala.tech`, with Docker/Git checks under `farid`; no SSH connection to the wildcard target was made. No `.env`, credentials, workspace content, raw logs, cookies, or authentication headers were read or recorded. Nginx route inspection printed only selected routing directives; existing owner-guard values were not printed.

| Check | Observation |
| --- | --- |
| Public DNS A | `jali-agent.jala.tech` → `54.254.9.119`, TTL 60; `db.jala.tech` → `139.162.22.68`, TTL 60 |
| Random sibling | `ingress-preflight-20261110-f7d39.jala.tech` → `54.254.9.119`, TTL 60 |
| Authoritative cross-check | Queries to `ns-493.awsdns-61.com` return the same A values for Jali and the random sibling |
| CNAME / AAAA | No CNAME answer for Jali or random sibling; no AAAA answer for Jali |
| Authoritative zone inventory (parent researcher) | Read-only Route53 `listHostedZones` / `listResourceRecordSets` via local AWS profile `jala-tech`: public `jala.tech` zone `/hostedzone/Z3UDFHBXN534SE`; wildcard A `54.254.9.119` TTL60, db and Notakuy A `139.162.22.68` TTL60, zero exact Jali record. Write permission was not tested |
| HTTPS | Both names validate successfully, return HTTP 404, title `404 Not Found`, and show nginx; Python fetches yield identical 162-byte body SHA-256 `340c8464c2007ce3f80682e15dfafa4180b641d53c14201b929906b7b0284d87` |
| Public TLS | CN `*.jala.tech`, SAN includes `*.jala.tech`, issuer Let's Encrypt YR2, expires 2026-12-14 09:25:27 GMT; both names receive the same certificate metadata |
| db installation | `/home/farid/felix-agent-jali` absent; no enabled nginx site references `jali-agent.jala.tech`; no Jali container seen |
| Ports | nginx listens on public 80/443; Notakuy binds `127.0.0.1:3110`; no listener on 3111 |
| Existing Notakuy | `felix-agent-notakuy-jala-felix-1`, image `frdinawan/felix-agent:0.6.1`; loopback `/healthz` returns 200 |
| Existing nginx pattern | Separate Notakuy server name and hostname-specific Let's Encrypt certificate; proxies selected API routes to 3110 and contains owner-guard logic. Do not copy its secret or broaden its routes |
| Tools | Docker Compose v2.35.1; Git 2.34.1; `nginx -t` succeeds; certbot executable present |
| Capacity | 6 CPUs; load 1.01/0.69/0.85; RAM ~15 GiB total, ~4.4 GiB available; swap 4 GiB fully used; root disk 315 GiB, 48 GiB available, 85% used |
| Memory sample | Existing Notakuy ~122 MiB; other Felix instances ~82 MiB–1.03 GiB; Metabase ~3.92 GiB. These idle samples do not predict concurrent harness execution peaks |

Capacity permits considering another small service, but is not a production-load acceptance test. Fully occupied swap and multiple existing workloads mean concurrency, process limits, disk retention and worker memory need explicit implementation decisions and measurement. Do not infer that a 122 MiB idle agent bounds Jali workload memory.

Sources for observations: `dig +noall +answer` (recursive and authoritative queries), unauthenticated `curl`/Python TLS+HTTPS requests, `id farid`, `ss -lntp`, `free -h`, `df -h /`, `nproc`, `uptime`, filtered Docker ps/stats and nginx files, and loopback health request. The parent researcher supplied the additional authoritative Route53 inventory above; no AWS mutations were made. Results are point-in-time evidence.

## Current supported starter and setup

The local checkout and remote `main` were both `037e30933d7178e0dfb494ff8fe6451bad156d65`. The [pinned Compose source](https://github.com/frdteknikelektro/felix-agent-starter/blob/037e30933d7178e0dfb494ff8fe6451bad156d65/docker-compose.yml) defaults setup/runtime to `frdinawan/felix-agent:0.6.1`, with loopback-only configurable ports, separate Compose names/networks, workspace persistence and hardening. [Pinned setup instructions](https://github.com/frdteknikelektro/felix-agent-starter/blob/037e30933d7178e0dfb494ff8fe6451bad156d65/README.md) require Docker Compose, an interactive setup, at least one harness and message source, followed by `docker compose up -d --wait` and a loopback health check.

Follow the installed Felix setup skill at `/Users/frdinawan/.codex/plugins/cache/jala-agent-plugins/felix-agent/0.1.0/skills/felix-agent-setup/SKILL.md` and its `references/setup.md`: run setup as the owning host user, enter secrets privately, and keep Setup Console loopback-only. Its one-time URL must not enter research assets or chat. On a remote machine, reach Setup via an SSH tunnel. The user must finish the interactive secret-entry step before starting runtime. Do not invent a headless `.env`.

Configure Jali's chosen 9Router gateway and `openai/gpt-6-luna` privately through supported setup. This check did not exercise gateway credentials, inference, or channel support. No MCP integration is requested. The Next backend proxy and per-user filesystem/process execution isolation require their own implementation and validation; a separate service/network alone does not establish user isolation.

## Minimal proposed change sequence — not executed

1. Recheck the authoritative zone for drift immediately before applying the change. The verified inventory permits a Route53 **CREATE**, not UPSERT, in hosted zone `/hostedzone/Z3UDFHBXN534SE`: `{"Changes":[{"Action":"CREATE","ResourceRecordSet":{"Name":"jali-agent.jala.tech.","Type":"A","TTL":60,"ResourceRecords":[{"Value":"139.162.22.68"}]}}]}`. Use the authorized DNS workflow and confirm write capability there; only read access was exercised here. CREATE will fail safely if a conflicting record appeared. Leave wildcard and all other hostnames untouched; confirm no new exact AAAA/CNAME appeared. The wildcard still serves other names.
2. Before publishing application routes, create a separate installation as `farid`, retaining UID/GID `1002:1002`, workspace ownership, unique Compose project `felix-agent-jali`, and persistent loopback `FELIX_PORT=3111`. Recheck port/path availability first. Pin a verified release or the reviewed isolation-capable derivative; stock 0.6.1 is the current starter baseline, not proof of final feature readiness. Use the supported interactive setup, then verify `127.0.0.1:3111/healthz` and Compose health locally.
3. Prepare `/etc/nginx/sites-available/jali-agent.jala.tech` and a matching enabled link. The initial port-80 server must match only `jali-agent.jala.tech`, serve `/.well-known/acme-challenge/` from `/var/www/letsencrypt`, and return 404 elsewhere. Create the challenge directory if absent. Run `nginx -t`, then reload. Do not edit Notakuy or the db default site.
4. Once authoritative/public DNS reaches db, issue the dedicated certificate with Certbot webroot: `certbot certonly --webroot -w /var/www/letsencrypt -d jali-agent.jala.tech` (account/email/terms handled by the authorized operator). Existing wildcard key access is neither assumed nor needed. Verify the certificate names and automated renewal; do not print private-key material.
5. Add a dedicated 443 server using `/etc/letsencrypt/live/jali-agent.jala.tech/fullchain.pem` and `privkey.pem`. Proxy only the selected Jali API route contract to `http://127.0.0.1:3111`, preserving URI and forwarded host/proto/IP. For a Felix `/v1/` contract, keep `/v1/` prefix intact with `proxy_pass http://127.0.0.1:3111;`; allow streaming (`proxy_buffering off`) and set a reviewed streaming timeout. Return 404 for `/` and management routes; Owner Console and Setup stay loopback/SSH-only. Preserve Jali's own authentication and use a separate owner guard if the audited backend requires one; never reuse Notakuy values. Do not publicly expose broad `/api/` or carry over its unrelated admission routes.
6. Next's server-side proxy owns the Jali credential and derives authenticated end-user identity on the server. The browser must not receive the owner/API secret. Complete and test per-user execution isolation and proxy authorization before opening production access. The precise route/guard implementation depends on the code/API research and is not established by this network preflight.
7. After `nginx -t` and reload, verify public DNS, the hostname's validated dedicated certificate, authenticated API/streaming flow through Next, rejected unauthenticated calls, denied management routes, and Notakuy's unchanged health. Check certificate renewal with the operator's existing renewal convention. Recheck memory/disk during a bounded workload. Retain a DNS/site rollback record before cutover.

## Remaining uncertainty

DNS write authorization, the wildcard target's server configuration/owner, future Jali route guard, final isolation-capable image, Next deployment location, execution resource limits, and real provider inference remain unverified. The authoritative inventory proves no current exact Jali DNS record; it does not audit the wildcard target's internal application configuration. No deployment success is claimed. DNS/nginx/TLS edits, installation/setup, certificate issuance and runtime startup remain future changes requiring the owning workflow's authorization.
