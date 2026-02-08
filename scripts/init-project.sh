#!/bin/bash
# Initialize project directory structure for the AI-First Development Framework
#
# Creates the required directories and starter files referenced by PROJECT_PATHS.md.
# Safe to run multiple times — skips anything that already exists.
#
# For new projects:  Run this script to scaffold the full structure.
# For existing projects: Skip this script. Copy PROJECT_PATHS.md.template
#   and configure paths to point to your existing directories.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/../../"

echo ""
echo "  AI-First Framework - Project Init"
echo "  =================================="
echo ""

errors=0

ok()   { echo "  OK   $1"; }
skip() { echo "  SKIP $1 — $2"; }
fail() { echo "  FAIL $1 — $2"; errors=$((errors + 1)); }

# --- PROJECT_PATHS.md (project root) ---

paths_file="${PROJECT_ROOT}/PROJECT_PATHS.md"
if [ -f "$paths_file" ]; then
  skip "PROJECT_PATHS.md" "already exists in project root"
else
  example="${SCRIPT_DIR}/../instructions/PROJECT_PATHS.md.example"
  template="${SCRIPT_DIR}/../instructions/PROJECT_PATHS.md.template"
  if [ -f "$example" ]; then
    cp "$example" "$paths_file"
    ok "PROJECT_PATHS.md (from .example with defaults)"
  elif [ -f "$template" ]; then
    cp "$template" "$paths_file"
    ok "PROJECT_PATHS.md (from .template — edit paths before use)"
  else
    fail "PROJECT_PATHS.md" "no .example or .template found"
  fi
fi

# --- Directories ---

dirs=(
  "work/epics"
  "work/milestones"
  "work/milestones/tracking"
  "work/milestones/releases"
  "work/specs"
)

for dir in "${dirs[@]}"; do
  target="${PROJECT_ROOT}/${dir}"
  if [ -d "$target" ]; then
    skip "${dir}/" "already exists"
  else
    if mkdir -p "$target" 2>/dev/null; then
      ok "${dir}/"
    else
      fail "${dir}/" "could not create directory"
    fi
  fi
done

# --- Starter files ---

create_file() {
  local filepath="$1"
  local content="$2"
  local target="${PROJECT_ROOT}/${filepath}"

  if [ -f "$target" ]; then
    skip "$filepath" "already exists (keeping your version)"
  else
    if echo -e "$content" > "$target" 2>/dev/null; then
      ok "$filepath"
    else
      fail "$filepath" "could not create file"
    fi
  fi
}

create_file "ROADMAP.md" \
  "# Roadmap\n\nProject epics and their status.\n\n---\n\n*Add epics here using the epic-start skill.*"

create_file "work/epics/epic-roadmap.md" \
  "# Epic Roadmap\n\nDetailed technical view of all epics.\n\n---\n\n*Updated by epic skills.*"

create_file "work/GAPS.md" \
  "# Project Gaps\n\nDiscovered gaps and improvement opportunities.\n\n---\n\n*Add gaps here using the gap-triage skill.*"

create_file "PROVENANCE.md" \
  "# Provenance\n\nAd-hoc change log for work outside formal milestones.\n\nSee .ai/docs/provenance-format.md for entry format.\n\n---"

# --- Summary ---

echo ""
if [ $errors -eq 0 ]; then
  echo "  Done. Next steps:"
  echo "    1. Review PROJECT_PATHS.md in project root — adjust paths if needed"
  echo "    2. Run: bash .ai/scripts/sync-all.sh"
else
  echo "  Done with $errors error(s). Review FAIL lines above."
fi
echo ""
