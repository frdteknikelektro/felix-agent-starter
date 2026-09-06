#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

empty_env="$(mktemp)"
override_env="$(mktemp)"
default_config="$(mktemp)"
override_config="$(mktemp)"

cleanup() {
  rm -f -- "$empty_env" "$override_env" "$default_config" "$override_config"
}
trap cleanup EXIT

printf 'FELIX_IMAGE=contract/image:override\n' > "$override_env"

env -u FELIX_IMAGE -u FELIX_PORT -u FELIX_SETUP_PORT UID=4242 GID=4343 docker compose \
  --env-file "$empty_env" \
  --profile setup \
  config --format json > "$default_config"

env -u FELIX_IMAGE -u FELIX_PORT -u FELIX_SETUP_PORT UID=4242 GID=4343 docker compose \
  --env-file "$override_env" \
  --profile setup \
  config --format json > "$override_config"

python3 - "$default_config" "$override_config" <<'PY'
import json
import sys

default = json.load(open(sys.argv[1], encoding="utf-8"))
override = json.load(open(sys.argv[2], encoding="utf-8"))

services = default["services"]
override_services = override["services"]
expected_services = {"setup", "setup-ui", "felix"}

def fail(message):
    raise SystemExit(f"compose contract failed: {message}")

def environment_map(service):
    environment = service.get("environment") or {}
    if isinstance(environment, dict):
        return environment
    return dict(item.split("=", 1) for item in environment)

if set(services) != expected_services:
    fail(f"expected services {sorted(expected_services)}, found {sorted(services)}")

default_images = {name: service.get("image") for name, service in services.items()}
if set(default_images.values()) != {"frdinawan/felix-agent:0.3.2"}:
    fail(f"unexpected default images: {default_images}")

override_images = {name: service.get("image") for name, service in override_services.items()}
if set(override_images.values()) != {"contract/image:override"}:
    fail(f"FELIX_IMAGE override is not shared by every service: {override_images}")

expected_commands = {
    "setup": ["node", "dist/setup/terminal-main.js"],
    "setup-ui": ["node", "dist/setup/index.js"],
}
for name, command in expected_commands.items():
    if services[name].get("command") != command:
        fail(f"{name} command is {services[name].get('command')!r}, expected {command!r}")

for name in ("setup", "setup-ui"):
    environment = environment_map(services[name])
    if environment.get("UID") != "4242" or environment.get("GID") != "4343":
        fail(f"{name} must receive the launch UID/GID: {environment!r}")

for name, service in services.items():
    if "container_name" in service:
        fail(f"{name} sets container_name")
    if service.get("cap_drop") != ["ALL"]:
        fail(f"{name} must drop all capabilities")
    if service.get("read_only") is not True:
        fail(f"{name} must use a read-only filesystem")
    if "no-new-privileges:true" not in service.get("security_opt", []):
        fail(f"{name} must enable no-new-privileges")

def require_loopback_port(service_name, target, published):
    ports = services[service_name].get("ports", [])
    matches = [port for port in ports if port.get("target") == target]
    if len(matches) != 1:
        fail(f"{service_name} must expose exactly one port targeting {target}")
    port = matches[0]
    if port.get("host_ip") != "127.0.0.1" or str(port.get("published")) != str(published):
        fail(f"{service_name} port is not loopback-only with published value {published!r}: {port}")

require_loopback_port("setup-ui", 53317, 0)
require_loopback_port("felix", 3000, 0)

healthcheck = services["setup-ui"].get("healthcheck", {})
healthcheck_text = " ".join(str(item) for item in healthcheck.get("test", []))
if "http://127.0.0.1:53317/healthz" not in healthcheck_text:
    fail("setup-ui healthcheck must probe http://127.0.0.1:53317/healthz")

network = default.get("networks", {}).get("felix-net", {})
if network.get("driver") != "bridge" or network.get("enable_ipv6"):
    fail("felix-net must use the standard Docker bridge network")

print("compose contract passed")
PY

if rg -n '0\.2\.3|0\.3\.1' README.md; then
  echo "compose contract failed: README contains stale release references" >&2
  exit 1
fi

if ! rg -n 'frdinawan/felix-agent:0\.3\.2' README.md >/dev/null; then
  echo "compose contract failed: README does not document the 0.3.2 image" >&2
  exit 1
fi
