#!/usr/bin/env bash
set -euo pipefail

# ###########################################################################
# PURPOSE:
#   This script updates the GitHub Actions workflow file to reflect the
#   current set of Dockerfile options available in the repository.
#   It scans for Dockerfile.* files, extracts their suffixes, and updates
#   the workflow YAML file accordingly.
# ###########################################################################

WORKFLOW_FILE=".github/workflows/build-docker-image.yml"

# Ensure yq is installed
if ! command -v yq >/dev/null 2>&1; then
  echo "Error: yq is not installed. Install it from https://github.com/mikefarah/yq"
  exit 1
fi

# Find Dockerfile suffixes (e.g., 'base' from 'Dockerfile.base')
dockerfile_options=$(find . -maxdepth 1 -name "Dockerfile.*" \
  | sed 's|./Dockerfile\.||' \
  | sort)

if [ -z "$dockerfile_options" ]; then
  echo "No Dockerfile.* files found in current directory."
  exit 0
fi

echo "Updating workflow options with: $dockerfile_options"

# Convert newline list into a JSON array for yq
json_array=$(printf '%s\n' $dockerfile_options | jq -R . | jq -s .)

# Update the workflow YAML file
yq -i ".on.workflow_dispatch.inputs.dockerfile.options = $json_array" "$WORKFLOW_FILE"

echo "Updated $WORKFLOW_FILE with dockerfile options: $dockerfile_options"