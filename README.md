# Misc Docker Images

This repository contains Docker images for various miscellaneous tools and applications. Each image is built from a corresponding Dockerfile and can be used for specific purposes like file organization, automation, etc.

## Dockerfiles

### caddy

**Source URL:** https://github.com/caddyserver/caddy

**Description:** A containerized version of Caddy, a powerful, enterprise-ready, open source web server with automatic HTTPS written in Go.

**Changes vs. Vanilla Version:**
- Built with additional modules: Layer 4 (TCP/UDP) support, Cloudflare DNS provider, authentication providers, GeoIP2, CrowdSec bouncer, Coraza WAF, and more.
- Conditional build: external (WAN) builds include GeoIP2, CrowdSec, and Coraza modules; internal (LAN) builds exclude them.
- Includes bash shell with custom profile.
- Metadata labels for build information.

#### Files in programs/caddy

- **docker-compose.yml**: Docker Compose configuration to run the Caddy container. Uses host networking, mounts Caddyfile and config volume. Requires environment variables for Cloudflare API token and target domain.

---

### dnsmasq

**Source URL:** https://github.com/jpillora/docker-dnsmasq

**Description:** A containerized version of dnsmasq, a lightweight DHCP and caching DNS server.

**Changes vs. Vanilla Version:**
- Includes webproc for web-based configuration interface.
- Pre-configured with example dnsmasq.conf for Cloudflare DNS servers.
- Supports multiple architectures: amd64, arm64, armv7, armv6.
- Includes bash shell with custom profile.
- Exposes ports for DNS (53), DHCP (67/udp, 68/udp), and webproc (8080).

#### Files in programs/dnsmasq

- **dnsmasq.conf**: Configuration file for dnsmasq. Includes logging, upstream DNS servers (Cloudflare), and example domain-specific server and address mappings.

---

### organize-tool

**Source URL:** https://github.com/tfeldmann/organize

**Description:** A containerized version of the organize-tool, a Python-based file organizer that can automatically sort, rename, and manage files based on rules.

**Changes vs. Vanilla Version:**
- Uses supercronic instead of cron for reliable scheduling.
- amd64 and arm64 only (supercronic does not publish armv7/armv6 binaries).
- PUID/PGID set at runtime via environment variables (LSIO-style); image defaults 911:911.
- Custom entrypoint validates config, maps UID/GID, prints the active crontab, and starts supercronic.
- Scheduled runs go through `run-organize.sh` so `docker logs` shows start/end and organize output.
- Healthcheck via heartbeat file under `/app/state`.

#### Directory Structure

```
programs/organize-tool/
├── config/
│   ├── crontab.default          # Baked-in schedule (copied to /app/crontab.default)
│   └── organize.yaml.example    # Example rules config
├── scripts_global/              # Built-in scripts (shipped with image)
│   ├── generic_webhook_sender.sh
│   └── run-organize.sh          # Logged wrapper for scheduled organize runs
├── scripts_user/                # User-provided scripts (bind-mount)
├── docker-compose.yml           # Run configuration
└── entrypoint.sh                # Container entrypoint
```

#### Path Conventions

- `/watched` — root directory for files to organize. Create subdirectories for categories (e.g., `/watched/downloads`, `/watched/media`).
- `/app/scripts_global` — built-in scripts shipped with the image.
- `/app/scripts_user` — user-provided scripts, bind-mounted from `scripts_user/`.
- `/app/config/organize.yaml` — your rules file (mount a **directory** at `/app/config`).
- `/app/config/crontab` — optional override schedule; if missing, `/app/crontab.default` is used.
- `/app/crontab.default` — built-in schedule (outside `/app/config/` so a config mount cannot hide it).
- `/app/state/heartbeat` — touched after each successful run (healthcheck).

#### Usage

1. Put `organize.yaml` (and optionally `crontab`) in a host config directory.
2. Point compose at that directory: `.../config:/app/config:ro`, plus your `/watched` path and `organize_state` volume.
3. Set `PUID`/`PGID` if needed for host volume ownership; set `WEBHOOK_*` if you use webhooks.
4. Run: `docker compose up -d`
5. Logs: `docker logs -f organize-watcher` (entrypoint dumps the crontab; each run is prefixed `[run-organize]` / `[organize]`).
6. Shell: `docker exec -u appuser -it organize-watcher bash` (use `-it` so `.bashrc` aliases load; image entrypoint runs as root only for UID mapping).
7. Optional: `SUPERCRONIC_DEBUG=1` for extra supercronic schedule logging.

---

## Automated Workflows

### Caddy Version Monitor

The `caddy-monitor.yml` workflow runs weekly (Monday at 2:30 AM UTC) and on manual dispatch. It:

1. Checks the GitHub Releases API for the latest Caddy version.
2. Checks Docker Hub for existing LAN and WAN images.
3. If new: builds and pushes both variants (`caddy-<version>-lan`, `caddy-<version>-wan`).
4. If already up to date: exits cleanly.

## Usage

1. Clone this repository.
2. Choose a Dockerfile (e.g., `Dockerfile.caddy`, `Dockerfile.dnsmasq`, or `Dockerfile.organize-tool`).
3. Build the image using the GitHub/Gitea/Forgejo Actions workflow or manually: `docker build -f Dockerfile.caddy -t your-tag .`
4. Run the container as per the examples in `programs/caddy/docker-compose.yml`, `programs/dnsmasq/`, or `programs/organize-tool/docker-compose.yml`.

