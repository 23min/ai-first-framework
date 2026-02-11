# AI Framework Improvements — Change Log

**Branch:** `fix/ai-framework-improvements`  
**Base:** `ee295ed` (main — `fix: Correct .gitignore entry for skills directory`)  
**Head:** `f646f3c`  
**Date range:** 2026-02-09  
**Scope:** 33 files changed, 528 insertions, 437 deletions

---

## Summary

A single-day sprint that audited and hardened the AI-First framework. Work was driven by an audit report (now untracked) that identified broken references, missing files, incomplete agent handoff chains, and documentation drift. The changes fall into four categories:

1. **Bug fixes** — broken paths, missing directories, stale references
2. **Agent system enhancements** — new agents, subagent delegation, visibility controls
3. **Tooling upgrades** — model configuration, sync-agents script overhaul
4. **Documentation consolidation** — merged duplicates, rewrote learning guide

---

## Commits (oldest → newest)

### 1. `7124f60` — fix(C1): Restructure skills to directory/SKILL.md format
Migrated skill files from flat `skills/name.md` to `skills/name/SKILL.md` directory structure, enabling each skill to own supporting assets.

### 2. `564b255` — fix(C2,C3): Fix gaps.md path and add epic-wrap to skill list
- Fixed `GAPS.md` reference to point to `work/gaps.md`
- Added `epic-wrap` to the registered skill list in instructions

### 3. `462b011` — fix(H1): Fix docs/ROADMAP.md → ROADMAP.md in 4 skill files
Corrected stale `docs/ROADMAP.md` references to root `ROADMAP.md` in: `branching`, `epic-refine`, `epic-start`, `roadmap`.

### 4. `7f75102` — fix(H4,M3): Complete agent handoff chain
Added missing handoff definitions so every agent in the workflow chain (architect → planner → documenter → implementer → tester → deployer → maintainer) has explicit handoff labels and prompts. Previously tester, deployer, and documenter→deployer links were missing.

### 5. `904f30c` — fix(H2): Resolve docs/development/ references → .ai/docs/
Updated references that still pointed to the old `docs/development/` path to use `.ai/docs/` after the framework restructure.

### 6. `c8cc7db` — fix(H3): Adopt work/epics/active/ + completed/ convention
- Created `work/epics/active/` and `work/epics/completed/` directories
- Updated skill files (`epic-start`, `milestone-draft`, `roadmap`) to reference the new convention
- Moved the active epic into `work/epics/active/`

### 7. `671f96e` — chore: Remove AI-AUDIT-REPORT.md and AI-FIX-PLAN.md from tracking
Untracked the temporary audit artifacts that drove this work. They remain in the worklog for reference but are no longer version-controlled.

### 8. `8d665b4` — fix(M1,M4): Create work/releases/ and clarify @plan reference
- Created `work/releases/` directory (was referenced but missing)
- Fixed a `@plan` reference in `milestone-draft` to clarify it means the planner agent

### 9. `2c3a816` — fix: Add file-based fallback to remaining handoff prompts
Enhanced all agent handoff prompts with file-path hints (e.g., "Check `work/epics/active/` for the epic spec") so handoffs work even when chat context is lost.

### 10. `894c332` — fix(N3): Remove deprecated inactive/deployment from flowchart
Removed the `deployment.md` node from the framework flowchart since it was moved to `inactive/` and is no longer a standard skill.

### 11. `5edc893` — fix(N2): Add missing metadata to milestone-start and context-refresh
Added `## Metadata` sections (triggers, inputs, outputs, agents) to the two skill files that were missing them.

### 12. `6189ce0` — Enhance AI framework: Add explorer agent, enable subagent delegation, and reorganize config files
**Major change.** Introduced the subagent architecture:
- **New agent: `explorer`** — read-only codebase discovery subagent (search, usages, grep only)
- **New file: `.ai/config/models.conf`** — centralized model assignment per agent tier
- Renamed `PROJECT_PATHS.md` → `config/project-paths.md`
- Updated `sync-agents.sh` to:
  - Read model assignments from `models.conf`
  - Generate `agents:` (subagent delegation) YAML in frontmatter
  - Generate `user-invokable: false` for subagent-only agents
  - Generate `disable-model-invocation: true` for deployer (safety)
  - Use namespaced tool names (`web/fetch`, `github/repo`)
  - Add `agent` tool to agents that can delegate

### 13. `702b2f7` — Add researcher subagent, refine agent visibility controls, untrack generated files
- **New agent: `researcher`** — web research subagent (`web/fetch`, `github/repo` only)
- Added `researcher` as subagent of architect and planner
- Updated `.gitignore` to untrack generated `.github/agents/` and `.github/skills/` files
- Updated `copilot-instructions.md` with researcher description

### 14. `004e032` — Consolidate GETTING_STARTED.md into learning-guide.md
- Deleted `.ai/instructions/GETTING_STARTED.md` (redundant)
- Rewrote `.ai/docs/learning-guide.md` as a comprehensive, practical guide covering:
  - Quick start / agent selection table
  - Subagent explanation
  - Complete workflow walkthrough
  - Skill reference with triggers
  - Model tier documentation
  - Troubleshooting section

### 15. `f646f3c` — Fix deprecated tool names: fetch → web/fetch, githubRepo → github/repo
Updated `researcher.md` constraints section to use the new namespaced VS Code Copilot tool names, matching the sync script.

---

## Key Artifacts Added/Changed

| Artifact | Status | Description |
|----------|--------|-------------|
| `.ai/agents/explorer.md` | **New** | Read-only codebase discovery subagent |
| `.ai/agents/researcher.md` | **New** | Web research subagent |
| `.ai/config/models.conf` | **New** | Centralized model-to-agent tier mapping |
| `.ai/scripts/sync-agents.sh` | **Overhauled** | Now reads models.conf, generates subagent/visibility YAML |
| `.ai/docs/learning-guide.md` | **Rewritten** | Consolidated from 316 → 223 lines, added subagent docs |
| `.ai/instructions/GETTING_STARTED.md` | **Deleted** | Content merged into learning-guide.md |
| `work/epics/active/` | **New dir** | Active epic home |
| `work/epics/completed/` | **New dir** | Completed epic archive |
| `work/releases/` | **New dir** | Release artifacts directory |

## Issue Categories Fixed

| Severity | ID | Issue | Commit |
|----------|----|-------|--------|
| Critical | C1 | Skills not in directory/SKILL.md format | `7124f60` |
| Critical | C2 | gaps.md path broken | `564b255` |
| Critical | C3 | epic-wrap missing from skill list | `564b255` |
| High | H1 | ROADMAP.md path wrong in 4 skills | `462b011` |
| High | H2 | docs/development/ references stale | `904f30c` |
| High | H3 | No active/completed epic convention | `c8cc7db` |
| High | H4 | Incomplete agent handoff chain | `7f75102` |
| Medium | M1 | work/releases/ missing | `8d665b4` |
| Medium | M3 | Handoff prompts lack file-path hints | `2c3a816` |
| Medium | M4 | @plan reference ambiguous | `8d665b4` |
| Nice | N2 | Missing metadata on 2 skills | `5edc893` |
| Nice | N3 | Deprecated deployment in flowchart | `894c332` |
| Enhancement | — | Explorer subagent | `6189ce0` |
| Enhancement | — | Researcher subagent | `702b2f7` |
| Enhancement | — | Model tier configuration | `6189ce0` |
| Enhancement | — | Learning guide consolidation | `004e032` |
| Enhancement | — | Namespaced tool names | `f646f3c` |
