#!/usr/bin/env bash
# Writes the artifacthub.io/changes annotation of a chart as GitHub release notes.
# Usage: release-notes.sh <chart-dir>   (needs yq, gh, GH_REPO and GITHUB_SHA)
set -euo pipefail

chart_dir="${1:?usage: release-notes.sh <chart-dir>}"
chart_file="${chart_dir}/Chart.yaml"

name="$(yq -r '.name' "${chart_file}")"
version="$(yq -r '.version' "${chart_file}")"
tag="${name}-${version}"

changes="$(yq -r '.annotations["artifacthub.io/changes"] // ""' "${chart_file}")"
if [[ -z "${changes}" ]]; then
  echo "${tag}: no artifacthub.io/changes annotation, leaving release notes untouched"
  exit 0
fi

if ! gh release view "${tag}" >/dev/null 2>&1; then
  echo "${tag}: release does not exist, skipping"
  exit 0
fi

entries="$(printf '%s\n' "${changes}" | yq -r '.[] | "- **" + .kind + "**: " + .description')"

pull_requests="$(gh api "repos/${GH_REPO}/commits/${GITHUB_SHA}/pulls" \
  --jq '.[] | "- #" + (.number | tostring) + " " + .title' 2>/dev/null || true)"

notes="## Changes"$'\n\n'"${entries}"
if [[ -n "${pull_requests}" ]]; then
  notes+=$'\n\n'"## Pull requests"$'\n\n'"${pull_requests}"
fi

gh release edit "${tag}" --notes "${notes}"
echo "${tag}: release notes updated"
