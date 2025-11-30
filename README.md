# Misc Docker Images

This repository contains Docker images for various miscellaneous tools and applications. Each image is built from a corresponding Dockerfile and can be used for specific purposes like file organization, automation, etc.

## Dockerfiles

### organize-tool

**Source URL:** https://github.com/tfeldmann/organize

**Description:** A containerized version of the organize-tool, a Python-based file organizer that can automatically sort, rename, and manage files based on rules.

**Changes vs. Vanilla Version:**
- Added cron for scheduled execution.
- Included additional dependencies: exiftool (for metadata extraction), poppler-utils (for PDF processing), curl.
- Custom entrypoint script to install crontab and start cron in foreground.
- Pre-configured with example config and crontab for every 15-minute runs.
- Volumes for config, data, and cron files.

#### Files in programs/organize-tool

- **config.yaml**: Configuration file defining rules for organize-tool. Currently contains a simple "Print hello" rule as an example. Customize this file to define your file organization rules.
- **docker-compose.yml**: Docker Compose configuration to run the organize-tool container. Mounts volumes for crontab, config, and data directories. Uses the image `zorbatherainy/misc_images:organize-tool-latest`.
- **docker-entrypoint.sh**: Bash script that serves as the container entrypoint. Checks for and installs the crontab file if present, ensures cron logs are visible, and starts cron in foreground mode.
- **organize-tool-crontab**: Crontab file that schedules organize-tool to run every 15 minutes. Logs output to `/var/log/cron.log`. Modify the schedule as needed for your use case.

## Usage

1. Clone this repository.
2. Choose a Dockerfile (e.g., `Dockerfile.organize-tool`).
3. Build the image using the GitHub Actions workflow or manually: `docker build -f Dockerfile.organize-tool -t your-tag .`
4. Run the container as per the example in `programs/organize-tool/docker-compose.yml`.

