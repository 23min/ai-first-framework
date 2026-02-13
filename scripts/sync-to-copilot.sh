#!/bin/bash
# Sync .ai/agents/*.md to .github/agents/*.agent.md with YAML frontmatter
# Sync .ai/skills/*.md to .github/skills/<name>/SKILL.md with YAML frontmatter
# Reads model assignments from .ai/config/models.conf
#
# Source: .ai/ (canonical)
# Target: .github/agents/, .github/skills/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
SKILLS_DIR="${SCRIPT_DIR}/../skills"
CONFIG_DIR="${SCRIPT_DIR}/../config"
AGENTS_OUTPUT="${SCRIPT_DIR}/../../.github/agents"
SKILLS_OUTPUT="${SCRIPT_DIR}/../../.github/skills"
MODEL_CONFIG="${CONFIG_DIR}/models.conf"

echo "Syncing to .github/ for GitHub Copilot..."
echo ""

# ============================================================================
# LOAD MODEL CONFIGURATION
# ============================================================================

declare -A MODELS
DEFAULT_MODEL="Claude Sonnet 4.5"

if [ -f "${MODEL_CONFIG}" ]; then
  echo "Loading model config from ${MODEL_CONFIG}..."
  while IFS='=' read -r key value; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    if [ "$key" = "DEFAULT" ]; then
      DEFAULT_MODEL="$value"
    else
      MODELS["$key"]="$value"
    fi
  done < "${MODEL_CONFIG}"
  echo "  Loaded ${#MODELS[@]} model assignments (default: ${DEFAULT_MODEL})"
  echo ""
else
  echo "  ⚠ No model config found at ${MODEL_CONFIG} — using default: ${DEFAULT_MODEL}"
  echo ""
fi

get_model() {
  local agent_name="$1"
  echo "${MODELS[$agent_name]:-$DEFAULT_MODEL}"
}

# ============================================================================
# SYNC AGENTS
# ============================================================================

echo "Syncing agents from ${AGENTS_DIR} to ${AGENTS_OUTPUT}..."

mkdir -p "${AGENTS_OUTPUT}"

synced=0

for file in "${AGENTS_DIR}"/*.md; do
  [ -f "$file" ] || continue

  basename=$(basename "$file" .md)
  output="${AGENTS_OUTPUT}/${basename}.agent.md"

  # Extract metadata
  name=$(grep "^# Agent:" "$file" | sed 's/# Agent: //' | xargs)
  description=$(grep "^Focus:" "$file" | sed 's/Focus: //' | xargs)

  # Get model from config
  model=$(get_model "$basename")

  # Determine tools by agent role
  case "$basename" in
    planner|architect)
      tools="['agent', 'search', 'web/fetch', 'search/usages', 'web/githubRepo']"
      ;;
    implementer)
      tools="['agent', '*']"
      ;;
    tester)
      tools="['agent', 'search', 'web/fetch', 'search/usages', 'execute/runInTerminal', 'search/textSearch']"
      ;;
    documenter)
      tools="['search', 'web/fetch', 'search/usages', 'edit']"
      ;;
    deployer)
      tools="['execute/runInTerminal', 'web/fetch', 'edit']"
      ;;
    maintainer)
      tools="['agent', 'search', 'web/fetch', 'search/usages', 'search/textSearch', 'edit']"
      ;;
    explorer)
      tools="['search', 'search/usages', 'search/textSearch']"
      ;;
    researcher)
      tools="['web/fetch', 'web/githubRepo']"
      ;;
    *)
      tools="['search', 'web/fetch']"
      ;;
  esac

  # Determine subagent delegation
  subagents=""
  case "$basename" in
    architect|planner)
      subagents="agents: ['explorer', 'researcher']"
      ;;
    implementer|tester|maintainer)
      subagents="agents: ['explorer']"
      ;;
    explorer|researcher|deployer)
      subagents="agents: []"
      ;;
  esac

  # Determine visibility
  visibility=""
  case "$basename" in
    explorer|researcher)
      visibility="user-invokable: false"
      ;;
    deployer)
      visibility="disable-model-invocation: true"
      ;;
  esac

  # Determine handoffs (complete chain)
  handoffs=""
  case "$basename" in
    architect)
      handoffs="handoffs:
  - label: Create Milestone Plan
    agent: planner
    prompt: Create a milestone plan based on the epic design above. Check work/epics/ for the epic spec.
    send: false"
      ;;
    planner)
      handoffs="handoffs:
  - label: Draft Milestone Specs
    agent: documenter
    prompt: Create milestone specifications based on the plan above. Check work/epics/ for the epic spec and milestone outline.
    send: false"
      ;;
    documenter)
      handoffs="handoffs:
  - label: Start Implementation
    agent: implementer
    prompt: Begin implementing the first milestone. Check work/milestones/ for the current milestone spec.
    send: false
  - label: Release Epic
    agent: deployer
    prompt: The epic is wrapped. Run the release ceremony. Check work/epics/ for the epic status.
    send: false"
      ;;
    implementer)
      handoffs="handoffs:
  - label: Review Code
    agent: tester
    prompt: Review and test the implementation above.
    send: false"
      ;;
    tester)
      handoffs="handoffs:
  - label: Wrap Milestone
    agent: documenter
    prompt: Code review passed. Wrap the current milestone. Check work/milestones/ for the tracking doc.
    send: false"
      ;;
    deployer)
      handoffs="handoffs:
  - label: Framework Review
    agent: maintainer
    prompt: Release complete. Run a post-mortem or framework review if needed.
    send: false"
      ;;
  esac

  # Build optional YAML fields
  optional_yaml=""
  [ -n "$subagents" ] && optional_yaml="${optional_yaml}
${subagents}"
  [ -n "$visibility" ] && optional_yaml="${optional_yaml}
${visibility}"
  [ -n "$handoffs" ] && optional_yaml="${optional_yaml}
${handoffs}"

  # Generate .agent.md file
  cat > "$output" <<EOF
---
description: ${description}
name: ${name}
tools: ${tools}
model: ${model}${optional_yaml}
---

$(cat "$file")

---

**Source:** This agent is automatically synced from [\`.ai/agents/${basename}.md\`](../../.ai/agents/${basename}.md)
**Model:** ${model} (configured in \`.ai/config/models.conf\`)

To update this agent, edit the source file and run:
\`\`\`bash
bash .ai/scripts/sync-all.sh
\`\`\`
EOF

  echo "  ✓ ${basename}.agent.md (${model})"
  synced=$((synced + 1))
done

echo "✓ Synced ${synced} agents to .github/agents/"
echo ""

# ============================================================================
# SYNC SKILLS
# ============================================================================

echo "Syncing skills from ${SKILLS_DIR} to ${SKILLS_OUTPUT}..."

# Clean old flat .skill.md files (migration from old format)
find "${SKILLS_OUTPUT}" -maxdepth 1 -name "*.skill.md" -delete 2>/dev/null || true

mkdir -p "${SKILLS_OUTPUT}"

synced_skills=0

for file in "${SKILLS_DIR}"/*.md; do
  [ -f "$file" ] || continue

  basename_full=$(basename "$file")
  [[ "$basename_full" == "README.md" ]] && continue

  skill_name=$(basename "$file" .md)
  skill_dir="${SKILLS_OUTPUT}/${skill_name}"
  output="${skill_dir}/SKILL.md"

  mkdir -p "${skill_dir}"

  # Extract description from **Purpose:** line
  description=$(grep '^\*\*Purpose:\*\*' "$file" | sed 's/\*\*Purpose:\*\* //' | head -1 | xargs)

  if [ -z "$description" ]; then
    description="Skill: ${skill_name}"
  fi

  # Generate SKILL.md with YAML frontmatter
  cat > "$output" <<EOF
---
name: ${skill_name}
description: "${description}"
---

$(cat "$file")

---

**Source:** This skill is automatically synced from [\`.ai/skills/${skill_name}.md\`](../../../.ai/skills/${skill_name}.md)

To update this skill, edit the source file and run:
\`\`\`bash
bash .ai/scripts/sync-all.sh
\`\`\`
EOF

  echo "  ✓ ${skill_name}/SKILL.md"
  synced_skills=$((synced_skills + 1))
done

echo "✓ Synced ${synced_skills} skills to .github/skills/"
echo ""

# ============================================================================
# GENERATE copilot-instructions.md (framework section)
# ============================================================================

COPILOT_INSTRUCTIONS="${SCRIPT_DIR}/../../.github/copilot-instructions.md"
PROJECT_ROOT="${SCRIPT_DIR}/../../"

echo "Updating .github/copilot-instructions.md (framework section)..."

BEGIN_MARKER="<!-- BEGIN AI-FRAMEWORK (auto-generated, do not edit) -->"
END_MARKER="<!-- END AI-FRAMEWORK -->"

# Read project paths if available
project_paths=""
if [ -f "${PROJECT_ROOT}/PROJECT_PATHS.md" ]; then
  project_paths=$(grep '^\- \*\*' "${PROJECT_ROOT}/PROJECT_PATHS.md" | sed 's/\*\*//g; s/^ *- /- /')
fi

# Build agent list
agent_list=""
for file in "${AGENTS_DIR}"/*.md; do
  [ -f "$file" ] || continue
  name=$(basename "$file" .md)
  desc=$(grep "^Focus:" "$file" | sed 's/Focus: //' | xargs)
  agent_list="${agent_list}
- **${name}** (\`.github/agents/${name}.agent.md\`) — ${desc}"
done

# Build skill list (names only, comma-separated)
skill_names=""
for file in "${SKILLS_DIR}"/*.md; do
  [ -f "$file" ] || continue
  bn=$(basename "$file")
  [[ "$bn" == "README.md" ]] && continue
  name=$(basename "$file" .md)
  if [ -z "$skill_names" ]; then
    skill_names="$name"
  else
    skill_names="${skill_names}, ${name}"
  fi
done

framework_section="${BEGIN_MARKER}

## Core Principles

1. **AI-First:** Use AI by default; manual intervention is the exception
2. **Human-gated:** Never commit without explicit approval
3. **Traceable:** Document decisions in PROVENANCE.md (ad-hoc) or epic trackers (formal)
4. **Test-driven:** Write tests first, implement, then refactor

## Project Paths
${project_paths:-No PROJECT_PATHS.md found in project root. Create one from .ai/instructions/PROJECT_PATHS.md.example}

## Framework Paths

- \`.ai/agents/\` — Agent definitions (canonical source)
- \`.ai/skills/\` — Skill definitions (canonical source)
- \`.ai/instructions/\` — Framework instructions
- \`.ai/docs/\` — Framework documentation
- \`.ai/config/\` — Model assignments and project path config

## Available Agents
${agent_list}

## Available Skills

Core workflows available: ${skill_names}

See \`.ai/skills/\` directory for full list and \`.ai/skills/inactive/\` for deprecated skills.

## Context Refresh Protocol

If the user says \"refresh context\" or \"reload instructions\":
1. Re-read \`.ai/instructions/ALWAYS_DO.md\`
2. Re-read the active agent file from \`.ai/agents/\` (if in specific role)
3. Check \`work/epics/\` and \`work/milestones/tracking/\` for current work
4. Review \`PROJECT_PATHS.md\` for project-specific path configurations
5. Summarize current state and confirm understanding

## Always-On Rules

See \`.ai/instructions/ALWAYS_DO.md\` for critical guardrails that apply to every session.

${END_MARKER}"

if [ -f "$COPILOT_INSTRUCTIONS" ] && grep -q "$BEGIN_MARKER" "$COPILOT_INSTRUCTIONS"; then
  before=$(sed -n "1,/^${BEGIN_MARKER}$/{ /^${BEGIN_MARKER}$/d; p; }" "$COPILOT_INSTRUCTIONS")
  after=$(sed -n "/^${END_MARKER}$/,\${ /^${END_MARKER}$/d; p; }" "$COPILOT_INSTRUCTIONS")
  {
    echo "$before"
    echo "$framework_section"
    echo "$after"
  } > "$COPILOT_INSTRUCTIONS"
  echo "  ✓ copilot-instructions.md (framework section updated, user content preserved)"
elif [ -f "$COPILOT_INSTRUCTIONS" ]; then
  cp "$COPILOT_INSTRUCTIONS" "${COPILOT_INSTRUCTIONS}.old"
  echo "  Backed up existing to copilot-instructions.md.old"
  cat > "$COPILOT_INSTRUCTIONS" <<INSTRUCTIONS
# Copilot Instructions

${framework_section}

<!-- Project-specific instructions below this line are preserved across syncs -->

INSTRUCTIONS
  echo "  ✓ copilot-instructions.md (generated with markers, old version in .old)"
else
  cat > "$COPILOT_INSTRUCTIONS" <<INSTRUCTIONS
# Copilot Instructions

${framework_section}

<!-- Project-specific instructions below this line are preserved across syncs -->

INSTRUCTIONS
  echo "  ✓ copilot-instructions.md (created)"
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "✓ Synced ${synced} agents, ${synced_skills} skills, and copilot-instructions.md"
echo ""
echo "Model assignments:"
for agent_name in "${!MODELS[@]}"; do
  echo "  ${agent_name} → ${MODELS[$agent_name]}"
done | sort
echo "  (default) → ${DEFAULT_MODEL}"
echo ""
echo "  Reload VS Code window to see updates in chat"
