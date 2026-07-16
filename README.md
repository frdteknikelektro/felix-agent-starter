# 🦊 Felix Agent Starter

> 🚀 Run [Felix Agent](https://github.com/frdteknikelektro/felix-agent) from a
> tagged Docker image with a simple, persistent Docker Compose setup.

The Felix image already contains the application, setup wizard, bundled skills,
and runtime tools. This starter provides only the deployment config and the two
host-mounted locations Felix needs: `.env` for configuration and `workspace/`
for persistent state.

## ✨ What’s included

- 🐳 Pre-built Felix image — no Node.js or local build required
- 🧙 Interactive first-run setup wizard
- 💾 Persistent workspace for sessions, skills, credentials, and attachments
- 🔒 Loopback-only owner console with hardened container defaults
- 🌐 IPv6-enabled Docker network and host Chrome access for `felix-browser`

## 🚀 Quick start

Prerequisite: 🧰 Docker Desktop or Docker Engine with Docker Compose v2.

```bash
# 1️⃣ Get the starter
git clone https://github.com/frdteknikelektro/felix-agent-starter.git
cd felix-agent-starter
mkdir -p workspace

# 2️⃣ First-time setup
# macOS/Linux/WSL: keep generated files owned by your host user.
env UID="$(id -u)" GID="$(id -g)" docker compose --profile setup run --rm setup

# Windows Docker Desktop: omit UID/GID.
# docker compose --profile setup run --rm setup

# 3️⃣ Start Felix and wait for its health check
docker compose up -d --wait

# 4️⃣ Verify it is running
curl http://localhost:53318/healthz
```

The setup wizard creates `.env` interactively. Configure at least one 🧠 LLM
harness and one 💬 message source, then open the owner console at
<http://localhost:53318/> and sign in with `OWNER_UI_SECRET`.

### 🖥️ Owner console

The console is bound to loopback (`127.0.0.1`) by default. Exposing it beyond the local host
requires a customer-managed HTTPS reverse proxy and appropriate firewall rules.

The Compose file intentionally keeps Felix’s IPv6-enabled network for dual-stack
container networking. It also maps `host.docker.internal` for the optional
`felix-browser` skill, which connects to Chrome running on the host.

## 🛠️ Common commands

```bash
docker compose logs -f         # 📜 follow Felix logs
docker compose ps              # 🔎 show container status
docker compose restart felix  # 🔁 restart the agent
docker compose down            # 🛑 stop and remove the container

# 🧙 Re-run the interactive setup wizard
docker compose --profile setup run --rm setup
```

## 📌 Pinning and upgrades

The setup service uses the image selected by `FELIX_IMAGE`, so setup and runtime
always use the same release. To select a different tag or an immutable digest:

```bash
export FELIX_IMAGE=frdinawan/felix-agent:0.1.1
# Or: export FELIX_IMAGE=frdinawan/felix-agent@sha256:<verified-digest>
docker compose pull
docker compose --profile setup run --rm setup
docker compose up -d --wait
```

For upgrades, back up `.env` and the complete `workspace/` directory first,
then change `FELIX_IMAGE`, run `docker compose pull`, and restart with
`docker compose up -d --wait`.

## 💾 Persistent data and secrets

- 🔐 `.env` is generated locally by setup and is ignored by Git.
- 📂 `workspace/` contains sessions, skills, credentials, attachments, and other
  Felix state; it is ignored by Git and must be backed up securely.
- 🚫 Never commit `.env`, workspace data, API keys, OAuth credentials, or raw logs.

The default image is the versioned `0.1.1` release rather than `latest`. 📍 Pin a
verified digest for production deployments.
