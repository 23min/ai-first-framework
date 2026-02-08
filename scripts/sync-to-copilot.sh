#!/bin/bash
# Sync .ai/agents/*.md to .github/agents/*.agent.md with YAML frontmatter
# Sync .ai/skills/*.md to .github/skills/*.skill.md
#
# Source: .ai/ (canonical)
# Target: .github/agents/, .github/skills/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
SKILLS_DIR="${SCRIPT_DIR}/../skills"
AGENTS_OUTPUT="${SCRIPT_DIR}/../../.github/agents"
SKILLS_OUTPUT="${SCRIPT_DIR}/../../.github/skills"

echo "Syncing agents and skills..."
echo ""

# ============================================================================
# SYNC AGENTS
# ============================================================================

echo "Syncing agents from ${AGENTS_DIR} to ${AGENTS_OUTPUT}..."

# Create output directory
mkdir -p "${AGENTS_OUTPUT}"

# Track synced files
synced=0

for file in "${AGENTS_DIR}"/*.md; do
  [ -f "$file" ] || continue
  
  basename=$(basename "$file" .md)
  output="${AGENTS_OUTPUT}/${basename}.agent.md"
  
  # Extract metadata
  name=$(grep "^# Agent:" "$file" | sed 's/# Agent: //' | xargs)
  description=$(grep "^Focus:" "$file" | sed 's/Focus: //' | xargs)
  
  # Determine tools by agent role
  case "$basename" in
    planner|architect)
      tools="['search', 'fetch', 'usages', 'githubRepo']"
      ;;
    implementer)
      tools="['*']"
      ;;
    tester)
      tools="['search', 'fetch', 'usages', 'terminal', 'grep']"
      ;;
    documenter)
      tools="['search', 'fetch', 'usages', 'edit']"
      ;;
    deployer)
      tools="['terminal', 'docker', 'fetch', 'edit']"
      ;;
    maintainer)
      tools="['search', 'fetch', 'usages', 'grep', 'edit']"
      ;;
    *)
      tools="['search', 'fetch']"
      ;;
  esac
  
  # Determine handoffs
  handoffs=""
  case "$basename" in
    architect)
      handoffs="handoffs:
  - label: Create Milestone Plan
    agent: planner
    prompt: Create a milestone plan based on the epic design above.
    send: false"
      ;;
    planner)
      handoffs="handoffs:
  - label: Draft Milestone Specs
    agent: documenter
    prompt: Create milestone specifications based on the plan above.
    send: false"
      ;;
    documenter)
      handoffs="handoffs:
  - label: Create Test Plan
    agent: tester
    prompt: Create a test plan with RED/GREEN/REFACTOR steps for this milestone spec.
    send: false"
      ;;
    tester)
      handoffs="handoffs:
  - label: Start Implementation
    agent: implementer
    prompt: Implement against the test plan above using TDD cycles.
    send: false"
      ;;
    implementer)
      handoffs="handoffs:
  - label: Verify Implementation
    agent: tester
    prompt: Verify the implementation passes all tests and meets acceptance criteria.
    send: false"
      ;;
  esac
  
  # Generate .agent.md file
  cat > "$output" <<EOF
---
description: ${description}
name: ${name}
tools: ${tools}
model: Claude Sonnet 4
${handoffs}
---

$(cat "$file")

---

**Source:** This agent is automatically synced from [\`.ai/agents/${basename}.md\`](../../.ai/agents/${basename}.md)

To update this agent, edit the source file and run:
\`\`\`bash
.ai/scripts/sync-to-copilot.sh
\`\`\`
EOF

  echo "  ✓ ${basename}.agent.md"
  synced=$((synced + 1))
done

echo "✓ Synced ${synced} agents to .github/agents/"
echo ""

# ============================================================================
# SYNC SKILLS
# ============================================================================

echo "Syncing skills from ${SKILLS_DIR} to ${SKILLS_OUTPUT}..."

# Create output directory
mkdir -p "${SKILLS_OUTPUT}"

# Track synced files
synced_skills=0

for file in "${SKILLS_DIR}"/*.md; do
  [ -f "$file" ] || continue
  
  # Skip README files
  basename=$(basename "$file")
  if [[ "$basename" == "README.md" ]]; then
    continue
  fi
  
  basename=$(basename "$file" .md)
  output="${SKILLS_OUTPUT}/${basename}.skill.md"
  
  # Skills don't need frontmatter processing, just copy with footer
  cat > "$output" <<EOF
$(cat "$file")

---

**Source:** This skill is automatically synced from [\`.ai/skills/${basename}.md\`](../../.ai/skills/${basename}.md)

To update this skill, edit the source file, and run:
\`\`\`bash
.ai/scripts/sync-to-copilot.sh
\`\`\`
EOF

  echo "  ✓ ${basename}.skill.md"
  synced_skills=$((synced_skills + 1))
done

echo "✓ Synced ${synced_skills} skills to .github/skills/"
echo ""

# ============================================================================
# GENERATE copilot-instructions.md
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

# Build skill list
skill_list=""
for file in "${SKILLS_DIR}"/*.md; do
  [ -f "$file" ] || continue
  basename=$(basename "$file")
  [[ "$basename" == "README.md" ]] && continue
  name=$(basename "$file" .md)
  desc=$(grep '^\*\*Purpose:\*\*' "$file" | sed 's/\*\*Purpose:\*\* //' | head -1)
  if [ -z "$desc" ]; then
    desc=$(grep "^Focus:" "$file" | sed 's/Focus: //' | head -1)
  fi
  skill_list="${skill_list}
- **${name}** (\`.github/skills/${name}.skill.md\`) — ${desc}"
done

# Build the framework section
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

## Available Agents
${agent_list}

## Available Skills
${skill_list}

## Context Refresh Protocol

If the user says \"refresh context\" or \"reload instructions\":
1. Re-read the active agent file from \`.github/agents/\`
2. Check \`ROADMAP.md\` for current state
3. Check \`work/epics/\` and \`work/milestones/tracking/\` for current work
4. Summarize current state and confirm understanding

## Always-On Rules

See \`.ai/instructions/ALWAYS_DO.md\` for critical guardrails that apply to every session.

${END_MARKER}"

if [ -f "$COPILOT_INSTRUCTIONS" ] && grep -q "$BEGIN_MARKER" "$COPILOT_INSTRUCTIONS"; then
  # Replace existing framework section, preserve user content
  # Extract content before BEGIN marker
  before=$(sed -n "1,/^${BEGIN_MARKER}$/{ /^${BEGIN_MARKER}$/d; p; }" "$COPILOT_INSTRUCTIONS")
  # Extract content after END marker
  after=$(sed -n "/^${END_MARKER}$/,\${ /^${END_MARKER}$/d; p; }" "$COPILOT_INSTRUCTIONS")
  {
    echo "$before"
    echo "$framework_section"
    echo "$after"
  } > "$COPILOT_INSTRUCTIONS"
  echo "  ✓ copilot-instructions.md (framework section updated, user content preserved)"
elif [ -f "$COPILOT_INSTRUCTIONS" ]; then
  # File exists but no markers — back up and create with markers
  cp "$COPILOT_INSTRUCTIONS" "${COPILOT_INSTRUCTIONS}.old"
  echo "  Backed up existing to copilot-instructions.md.old"
  cat > "$COPILOT_INSTRUCTIONS" <<INSTRUCTIONS
# Copilot Instructions

${framework_section}

<!-- Project-specific instructions below this line are preserved across syncs -->
INSTRUCTIONS
  echo "  ✓ copilot-instructions.md (generated with markers, old version in .old)"
else
  # No file exists — create fresh
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
echo "  Reload VS Code window to see updates in chat"
