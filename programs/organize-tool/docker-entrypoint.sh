#!/bin/bash
set -e

# If a crontab file is mounted at /etc/cron.d/organize, install it
if [ -f /etc/cron.d/organize-tool-crontab ]; then
  echo "Installing crontab from /etc/cron.d/organize..."
  # cp /etc/cron.d/organize /etc/cron.d/organize
  chmod 0644 /etc/cron.d/organize-tool-crontab 
  crontab /etc/cron.d/organize-tool-crontab 
fi

# Ensure cron logs go to stdout
touch /var/log/cron.log
tail -f /var/log/cron.log &

# Start cron in foreground
exec cron -f
