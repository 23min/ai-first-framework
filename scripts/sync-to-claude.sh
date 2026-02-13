#!/bin/bash
# Sync .ai/skills/*.md to .claude/skills/<name>/SKILL.md with YAML frontmatter
# Sync .ai/agents/*.md to .claude/agents/<name>.md with YAML frontmatter
# Sync .ai/instructions/*.md to .claude/rules/
# Reads model assignments from .ai/config/models.conf
#
# Source: .ai/ (canonical)
# Target: .claude/skills/, .claude/agents/, .claude/rules/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${SCRIPT_DIR}/../skills"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
INSTRUCTIONS_DIR="${SCRIPT_DIR}/../instructions"
CONFIG_DIR="${SCRIPT_DIR}/../config"
CLAUDE_SKILLS_OUTPUT="${SCRIPT_DIR}/../../.claude/skills"
CLAUDE_AGENTS_OUTPUT="${SCRIPT_DIR}/../../.claude/agents"
CLAUDE_RULES_OUTPUT="${SCRIPT_DIR}/../../.claude/rules"
MODEL_CONFIG="${CONFIG_DIR}/models.conf"

echo "Syncing to .claude/ for Claude Code..."
echo ""

# ============================================================================
# LOAD MODEL CONFIGURATION
# ============================================================================

declare -A MODELS
DEFAULT_MODEL="claude-sonnet-4-20250514"

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
  echo "  ⚠ No model config found — using default: ${DEFAULT_MODEL}"
  echo ""
fi

get_model() {
  local agent_name="$1"
  echo "${MODELS[$agent_name]:-$DEFAULT_MODEL}"
}

# ============================================================================
# SYNC SKILLS
# ============================================================================

echo "Syncing skills from ${SKILLS_DIR} to ${CLAUDE_SKILLS_OUTPUT}..."

synced_skills=0

for file in "${SKILLS_DIR}"/*.md; do
  [ -f "$file" ] || continue

  basename=$(basename "$file")
  [[ "$basename" == "README.md" ]] && continue

  skill_name=$(basename "$file" .md)
  output_dir="${CLAUDE_SKILLS_OUTPUT}/${skill_name}"
  output="${output_dir}/SKILL.md"

  mkdir -p "${output_dir}"

  # Extract metadata from .ai/ skill format
  description=$(grep "^\*\*Purpose:\*\*" "$file" | sed 's/\*\*Purpose:\*\* //' | head -1)
  if [ -z "$description" ]; then
    description=$(grep "^Focus:" "$file" | sed 's/Focus: //' | head -1)
  fi
  [ -z "$description" ] && description="Skill: ${skill_name}"

  # Generate SKILL.md with YAML frontmatter
  cat > "$output" <<EOF
---
name: ${skill_name}
description: "${description}"
---

$(cat "$file")

---

**Source:** This skill is automatically synced from \`.ai/skills/${skill_name}.md\`

To update, edit the source file and run:
\`\`\`bash
bash .ai/scripts/sync-all.sh
\`\`\`
EOF

  echo "  ✓ ${skill_name}/SKILL.md"
  synced_skills=$((synced_skills + 1))
done

echo "✓ Synced ${synced_skills} skills to .claude/skills/"
echo ""

# ============================================================================
# SYNC AGENTS
# ============================================================================

echo "Syncing agents from ${AGENTS_DIR} to ${CLAUDE_AGENTS_OUTPUT}..."

mkdir -p "${CLAUDE_AGENTS_OUTPUT}"

synced_agents=0

for file in "${AGENTS_DIR}"/*.md; do
  [ -f "$file" ] || continue

  basename=$(basename "$file")
  [[ "$basename" == "README.md" ]] && continue

  agent_name=$(basename "$file" .md)
  output="${CLAUDE_AGENTS_OUTPUT}/${agent_name}.md"

  # Get model from config
  model=$(get_model "$agent_name")

  # Claude Code description: directive telling Claude WHEN to delegate
  case "$agent_name" in
    architect)
      description="Architectural design and epic scoping specialist. Use when planning features, creating epics, making design tradeoffs, or defining system boundaries."
      ;;
    planner)
      description="Milestone planning specialist. Use when breaking epics into milestones, sequencing work, or analyzing dependencies."
      ;;
    documenter)
      description="Documentation and specification specialist. Use when drafting milestone specs, writing release notes, updating roadmaps, or creating tracking docs."
      ;;
    implementer)
      description="Coding specialist for precise, minimal-risk changes. Use when implementing milestone requirements, writing code, or following TDD cycles."
      ;;
    tester)
      description="Test planning and TDD specialist. Use when defining test plans, creating RED/GREEN/REFACTOR steps, or validating test coverage."
      ;;
    deployer)
      description="Infrastructure and release specialist. Use when deploying changes, managing environments, or executing release procedures."
      ;;
    maintainer)
      description="AI framework maintenance specialist. Use when updating .ai/ framework files, reviewing skills/agents, or improving development workflows."
      ;;
    explorer)
      description="Read-only codebase discovery subagent. Delegated to by architect, planner, implementer, tester, and maintainer for searching code, finding definitions, and mapping file structures."
      ;;
    researcher)
      description="Web research subagent. Delegated to by architect and planner for researching external APIs, libraries, best practices, and competitor analysis."
      ;;
    *)
      description=$(grep "^Focus:" "$file" | sed 's/Focus: //' | head -1)
      ;;
  esac

  # Extract skills from **Key Skills:** line
  skills_line=$(grep "^\*\*Key Skills:\*\*" "$file" | sed 's/\*\*Key Skills:\*\* //' | head -1)
  skills_yaml=""
  if [ -n "$skills_line" ]; then
    skills_yaml="skills:"
    IFS=',' read -ra SKILL_ARRAY <<< "$skills_line"
    for skill in "${SKILL_ARRAY[@]}"; do
      skill=$(echo "$skill" | xargs)
      skills_yaml="${skills_yaml}
  - ${skill}"
    done
  fi

  # Determine tools by agent role
  case "$agent_name" in
    architect|planner)
      tools="Read, Glob, Grep, WebFetch, WebSearch"
      ;;
    implementer)
      tools="Read, Edit, Write, Bash, Glob, Grep"
      ;;
    tester)
      tools="Read, Edit, Write, Bash, Glob, Grep"
      ;;
    documenter)
      tools="Read, Edit, Write, Glob, Grep"
      ;;
    deployer)
      tools="Read, Edit, Write, Bash, Glob, Grep"
      ;;
    maintainer)
      tools="Read, Edit, Write, Glob, Grep"
      ;;
    explorer)
      tools="Read, Glob, Grep"
      ;;
    researcher)
      tools="WebFetch, WebSearch, Read"
      ;;
    *)
      tools="Read, Glob, Grep"
      ;;
  esac

  # Build optional YAML fields
  optional_yaml=""
  [ -n "$skills_yaml" ] && optional_yaml="${optional_yaml}
${skills_yaml}"

  # Generate agent file with YAML frontmatter
  cat > "$output" <<EOF
---
name: ${agent_name}
description: "${description}"
tools: ${tools}
model: ${model}${optional_yaml}
---

$(cat "$file")

---

**Source:** This agent is automatically synced from \`.ai/agents/${agent_name}.md\`
**Model:** ${model} (configured in \`.ai/config/models.conf\`)

To update, edit the source file and run:
\`\`\`bash
bash .ai/scripts/sync-all.sh
\`\`\`
EOF

  echo "  ✓ ${agent_name}.md (${model})"
  synced_agents=$((synced_agents + 1))
done

echo "✓ Synced ${synced_agents} agents to .claude/agents/"
echo ""

# ============================================================================
# SYNC RULES (instructions → .claude/rules/)
# ============================================================================

echo "Syncing instructions from ${INSTRUCTIONS_DIR} to ${CLAUDE_RULES_OUTPUT}..."

mkdir -p "${CLAUDE_RULES_OUTPUT}"

synced_rules=0

for file in "${INSTRUCTIONS_DIR}"/*.md; do
  [ -f "$file" ] || continue

  basename=$(basename "$file")
  [[ "$basename" == "README.md" ]] && continue

  output="${CLAUDE_RULES_OUTPUT}/${basename}"

  # Copy instruction file, append Claude-specific override if it exists
  override="${INSTRUCTIONS_DIR}/claude/${basename}"

  {
    cat "$file"
    if [ -f "$override" ]; then
      echo ""
      echo "---"
      echo ""
      cat "$override"
    fi
    cat <<FOOTER

---

**Source:** This rule is automatically synced from \`.ai/instructions/${basename}\`

To update, edit the source file and run:
\`\`\`bash
bash .ai/scripts/sync-all.sh
\`\`\`
FOOTER
  } > "$output"

  echo "  ✓ ${basename}"
  synced_rules=$((synced_rules + 1))
done

echo "✓ Synced ${synced_rules} rules to .claude/rules/"
echo ""

# ============================================================================
# SYNC PROJECT_PATHS.md (root → .claude/rules/)
# ============================================================================

PROJECT_PATHS="${SCRIPT_DIR}/../../PROJECT_PATHS.md"
if [ -f "$PROJECT_PATHS" ]; then
  output="${CLAUDE_RULES_OUTPUT}/PROJECT_PATHS.md"
  {
    cat "$PROJECT_PATHS"
    cat <<FOOTER

---

**Source:** This rule is synced from the project root \`PROJECT_PATHS.md\`

To update, edit \`PROJECT_PATHS.md\` in the project root and run:
\`\`\`bash
bash .ai/scripts/sync-all.sh
\`\`\`
FOOTER
  } > "$output"
  echo "  ✓ PROJECT_PATHS.md (from project root)"
  synced_rules=$((synced_rules + 1))
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "✓ Synced ${synced_skills} skills, ${synced_agents} agents, and ${synced_rules} rules to .claude/"
echo ""
echo "Model assignments:"
for agent_name in "${!MODELS[@]}"; do
  echo "  ${agent_name} → ${MODELS[$agent_name]}"
done | sort
echo "  (default) → ${DEFAULT_MODEL}"
