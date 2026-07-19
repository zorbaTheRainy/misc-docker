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
- PUID/PGID set at runtime via environment variables (LSIO-style), defaults to 911:911.
- Custom entrypoint validates config, maps UID/GID, and starts supercronic.
- Healthcheck via heartbeat file.

#### Directory Structure

```
programs/organize-tool/
├── config/
│   └── organize.yaml.example    # Example rules config
├── scripts_global/              # Built-in scripts (shipped with image)
│   └── send-webhook.sh
├── scripts_user/                # User-provided scripts (bind-mount)
├── docker-compose.yml           # Run configuration
├── entrypoint.sh                # Container entrypoint
└── .env.example                 # Environment variables template
```

#### Path Conventions

- `/watched` — root directory for files to organize. Create subdirectories for categories (e.g., `/watched/downloads`, `/watched/media`).
- `/app/scripts_global` — built-in scripts shipped with the image.
- `/app/scripts_user` — user-provided scripts, bind-mounted from `scripts_user/`.
- `/app/config/organize.yaml` — your rules file.
- `/app/crontab.default` — built-in schedule (shipped with image, outside `/app/config/` so it won't be shadowed by a mount).

#### Usage

1. Copy `.env.example` to `.env` and set `PUID`, `PGID`, and `WATCHED_DIR`.
2. Copy `config/organize.yaml.example` to `config/organize.yaml` and define your rules.
3. Run: `docker compose up -d`

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

