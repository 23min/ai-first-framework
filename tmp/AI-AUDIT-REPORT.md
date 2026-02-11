# Audit Report: Copilot Agents, Skills & Framework Configuration

**Date:** 2026-02-09  
**Auditor:** GitHub Copilot (Claude Opus 4.6)  
**Scope:** `.github/` (agents, skills, copilot-instructions), `.ai/` (instructions, agents, skills, scripts), cross-references and handoff chain  
**Branch:** `milestone/m-if-03`

---

## Summary

| Severity | Count | Description |
|----------|-------|-------------|
| **CRITICAL** | 3 | Skills invisible to VS Code, path mismatch in ALWAYS_DO, missing skill in instructions |
| **HIGH** | 4 | Broken path references (29 total), incomplete handoff chain |
| **MODERATE** | 5 | Missing directories, documenter hub limitation, subagent ambiguity, handoff prompt robustness |
| **MINOR** | 3 | Stale references, metadata inconsistency, flowchart inaccuracy |

---

## CRITICAL BUGS (things that are broken right now)

### C1. Skills are **not recognized** by VS Code / Copilot coding agent — wrong file format

**Current structure:**
```
.github/skills/
  session-start.skill.md
  milestone-start.skill.md
  red-green-refactor.skill.md
  ... (17 flat files)
```

**Required structure** (per [GitHub docs: About Agent Skills](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills) and [VS Code docs: Agent Skills](https://code.visualstudio.com/docs/copilot/customization/agent-skills)):
```
.github/skills/
  session-start/
    SKILL.md        ← file MUST be named exactly SKILL.md
  milestone-start/
    SKILL.md
  red-green-refactor/
    SKILL.md
  ...
```

From the GitHub docs:
> Skill files **must be named `SKILL.md`**.
> Each skill should have its own directory (for example, `.github/skills/webapp-testing`).
> Skill directory names should be lowercase, use hyphens for spaces, and typically match the `name` in the `SKILL.md` frontmatter.

Each `SKILL.md` must have YAML frontmatter with `name` (required) and `description` (required):

```yaml
---
name: session-start
description: Interactive session kickoff that guides users to the right role and task
---
```

From the GitHub docs on how skills are loaded:
> When performing tasks, Copilot will decide when to use your skills based on your prompt and the skill's **description**.
> When Copilot chooses to use a skill, the `SKILL.md` file will be injected in the agent's context.

Without the correct directory structure + `SKILL.md` filename + YAML frontmatter, Copilot never discovers or loads any of the 17 skills. They are invisible to the system.

The sync script (`.ai/scripts/sync-agents.sh`) currently generates flat `.skill.md` files — it needs to be updated to produce `directory/SKILL.md` structure.

**Environments affected:**
- **Copilot coding agent** — uses `.github/skills` (confirmed in GitHub docs)
- **GitHub Copilot CLI** — uses `.github/skills` (confirmed)
- **VS Code agent mode** — uses `.github/skills` (VS Code docs confirm; noted as "VS Code Insiders" in GitHub docs, but VS Code stable docs also list it)

**Impact:** All 17 skills are non-functional. They only work if a human or agent manually reads the file content.

**Fix:** Update `sync-agents.sh` to:
1. Create a subdirectory per skill (e.g., `.github/skills/session-start/`)
2. Generate `SKILL.md` (not `.skill.md`) inside each directory
3. Add YAML frontmatter with `name` (from skill heading) and `description` (from Purpose line)
4. Optionally include a `license` field

---

### C2. ALWAYS_DO.md references `docs/gaps.md` but actual file is `work/gaps.md`

**Location:** `.ai/instructions/ALWAYS_DO.md` line ~37

**Current text:**
> Gaps discovered: Add to `docs/gaps.md` and reference from epic/milestone

**PROJECT_PATHS.md defines:** `GAPS_PATH: work/gaps.md`  
**Actual file location:** `work/gaps.md` ✓

Agents following ALWAYS_DO will create or look for a file in the wrong location. Since ALWAYS_DO takes precedence over most other instructions (per its own conflict resolution rules), this mismatch is authoritative and misleading.

**Fix:** Change `docs/gaps.md` → `work/gaps.md` in ALWAYS_DO.md.

---

### C3. `copilot-instructions.md` skill list is missing `epic-wrap`

**Location:** `.github/copilot-instructions.md` line ~50

**Current text:**
> Core workflows available: epic-refine, epic-start, milestone-plan, milestone-draft, milestone-start, milestone-wrap, red-green-refactor, code-review, branching, release, gap-triage, framework-review, post-mortem, session-start, context-refresh, roadmap

Lists 16 skills but omits `epic-wrap`, which is an active skill with its own `.github/skills/epic-wrap.skill.md` file and is a critical part of the epic lifecycle (closing epics, syncing docs, coordinating merge to main).

**Fix:** Add `epic-wrap` to the skill list.

---

## HIGH-IMPACT ISSUES

### H1. 8 references to non-existent `docs/ROADMAP.md` (should be `ROADMAP.md`)

The roadmap file lives at workspace root `ROADMAP.md`, not under `docs/`.

| File | Approximate Line(s) |
|------|---------------------|
| `.ai/skills/epic-refine.md` | ~38 |
| `.ai/skills/roadmap.md` | ~36, ~41, ~49, ~56, ~60 |
| `.ai/skills/milestone-draft.md` | ~51 |
| `.ai/skills/gap-triage.md` | ~35 |

**Fix:** Replace all `docs/ROADMAP.md` references with `ROADMAP.md`.

---

### H2. 12 references to non-existent `docs/development/` directory

10 files across `.ai/` reference `docs/development/` paths such as:
- `docs/development/branching-strategy.md`
- `docs/development/milestone-documentation-guide.md`

| File | Line(s) |
|------|---------|
| `.ai/GAPS.md` | ~209 |
| `.ai/README.md` | ~69 |
| `.ai/docs/rationale.md` | ~394 |
| `.ai/docs/learning-guide.md` | ~79 |
| `.ai/instructions/ALWAYS_DO.md` | ~20 |
| `.ai/skills/branching.md` | ~8 |
| `.ai/skills/epic-start.md` | ~39, ~58 |
| `.ai/skills/milestone-draft.md` | ~37, ~38 |
| `.ai/skills/inactive/README.md` | ~21 |
| `.ai/skills/inactive/deployment.md` | ~8 |

Some of these are **prescriptive** ("Create `docs/development/branching-strategy.md`"), but others (like the ALWAYS_DO.md reference) assume the directory exists. The directory itself does not exist.

**Fix:** Either create `docs/development/` with the referenced files, or update all references to point to actual locations (e.g., `.ai/docs/branching-strategy.md` for framework docs, `docs/guides/` for project-specific guides).

---

### H3. 8 references to non-existent `work/epics/active/` directory

6 files reference `work/epics/active/` as an expected directory. Epics actually live directly under `work/epics/<epic-slug>/` without an `active/` subdirectory.

| File | Line(s) |
|------|---------|
| `.ai/docs/learning-guide.md` | ~58, ~262 |
| `.ai/skills/epic-start.md` | ~31, ~35 |
| `.ai/skills/context-refresh.md` | ~44 |
| `.ai/instructions/GETTING_STARTED.md` | ~25 |
| `.ai/skills/epic-wrap.md` | ~80 (also references `work/epics/completed/`) |
| `.ai/README.md` | ~61 (also references `work/epics/completed/`) |

**Note:** Some may be prescriptive (telling the agent to create the directory when needed), but the `epic-start` skill actively looks for epics in `work/epics/active/`, meaning it will fail to find existing epics.

**Fix:** Decide on convention — either create `active/`/`completed/` subdirectories and move epic folders, or update all references to match the flat `work/epics/<epic-slug>/` structure.

---

### H4. Agent handoff chain is **broken after tester** — missing 3 handoffs

The sync script (`sync-agents.sh` lines ~75–99) defines handoffs for only 4 of 7 agents:

```
architect → planner  ("Create Milestone Plan")
planner  → documenter ("Draft Milestone Specs")
documenter → implementer ("Start Implementation")
implementer → tester    ("Review Code")
tester     → ???        (NO handoff defined)
deployer   → ???        (NO handoff defined)
maintainer → ???        (NO handoff defined)
```

Per the flowchart (`.ai/docs/flowchart.md`), the intended flow after code review is:

```
CodeReview ──|Approved|──► Documenter ──► milestone-wrap ──► Last Milestone?
                                                              ├─ Yes ──► epic-wrap ──► Deployer ──► release
                                                              └─ No  ──► milestone-draft (next milestone)
```

**Missing handoffs:**

| From | To | Suggested Label | Purpose |
|------|----|-----------------|---------|
| **tester** | **documenter** | "Wrap Milestone" | After code review passes → milestone-wrap |
| **documenter** (wrap) | **deployer** | "Release Epic" | After epic-wrap → release ceremony |
| **deployer** | **maintainer** | "Framework Review" | After release → post-mortem (optional) |

The **tester → documenter** gap is the most critical because it breaks the main development loop.

**Fix:** Add three `case` entries in `sync-agents.sh` and re-run sync.

---

### H5. ~~All handoffs use `send: false` — no context transfer~~ **CORRECTED**

**Original finding was overstated.** After verifying against [VS Code Custom Agents docs](https://code.visualstudio.com/docs/copilot/customization/custom-agents#_handoffs):

> "Handoffs enable you to create guided sequential workflows that transition between agents **with relevant context** and a pre-filled prompt."

Handoffs happen **within the same chat session**, so conversation history IS visible to the new agent. The `send: false` flag only controls whether the prompt auto-submits or waits for the user to press Enter.

The example in the docs uses `prompt: Now implement the plan outlined above.` — confirming that "above" refers to the current conversation, which carries over.

**What `send: false` actually means:**
- The handoff button switches to the target agent
- The prompt text is placed in the chat input (pre-filled)
- The user must press Enter to submit (gives them a chance to review/edit)
- Conversation context **is preserved**

**Remaining concern (downgraded to MODERATE):** The handoff prompts are generic (e.g., "Create a milestone plan based on the epic design above"). Since conversation context is preserved, these work correctly within a single session. However, if the user starts a **new chat session** instead of using the handoff button, context is lost. Consider enhancing handoff prompts to also reference file-based state (tracking docs) as a fallback.

**Status:** Not a bug. The `send: false` design is intentional and correct — it gives users human-gated control, which aligns with the ALWAYS_DO principle of never acting without approval.

---

## MODERATE ISSUES

### M1. `work/releases/` directory doesn't exist

PROJECT_PATHS.md defines `MILESTONE_RELEASES_PATH: work/releases/` and the `milestone-wrap` skill references archiving completed milestone docs to this directory. It doesn't exist yet.

**Fix:** Create `work/releases/` with a `.gitkeep` or README explaining its purpose.

---

### M2. `docs/architecture/` is empty

The directory exists but contains no files, despite being implied by the project structure in `copilot-instructions.md`. Not necessarily broken, but could confuse agents that look here for architecture documentation.

**Fix:** Either add content or remove the empty directory and note that architecture docs live in `work/epics/` or `docs/research/`.

---

### M3. Documenter agent has only one handoff direction (forward), but is a workflow hub

The flowchart shows documenter appearing in **two distinct phases**:
- **Forward path:** milestone-draft → implementer (currently wired ✓)
- **Wrap path:** milestone-wrap → deployer or next milestone-draft (NOT wired ✗)

A single handoff button ("Start Implementation" → implementer) can't represent this branching. When the documenter is in wrap mode, the only handoff available points backward to implementer, which is incorrect.

**Fix:** Add a second handoff to documenter targeting deployer ("Release Epic"). The sync script's `case` for documenter should output two handoff entries.

---

### M4. Implementer references `@plan` subagent ambiguously

The implementer agent definition says:
> **Subagents:** May delegate to @plan for tactical implementation planning (breaking specs into granular TDD steps)

In VS Code, `@plan` is a **built-in feature** (GitHub Copilot's planning mode), not a custom agent. The reference is conceptually correct but could confuse the agent into thinking it needs to invoke a custom agent named "plan" rather than using the built-in planning capability.

**Fix:** Clarify to say "May use GitHub Copilot's built-in planning mode (@plan) for tactical implementation planning."

---

## MINOR / COSMETIC ISSUES

### N1. `copilot-instructions.md` references `.ai/skills/inactive/` for deprecated skills

This path points to the source `.ai/` directory, not the `.github/` output directory. Since the sync script skips subdirectories, inactive skills are never synced to `.github/skills/`. The reference is informational but not actionable for Copilot — it won't find anything there in the `.github/` context.

---

### N2. Some skills lack metadata consistency

`milestone-start` and `context-refresh` are missing **Maturity**, **Version**, and **Last Updated** fields that all other skills include. Minor inconsistency that could affect framework-review audits.

---

### N3. Flowchart shows `Deploy → inactive/deployment skill`

The flowchart (`.ai/docs/flowchart.md`) still routes deployer through `inactive/deployment` skill, which was deprecated 2026-02-03. The line:

```
Deployer --> Release[release skill]
Release --> Deploy[inactive/deployment skill]
```

Should terminate at `Release` or note that deployment is handled by project-specific guides.

---

## PRACTICAL WORKFLOW ASSESSMENT

### Does the handoff chain work in practice?

**Partially.** The agent definitions are well-structured and the escalation paths ("Escalate to X when...") are clear. But the technical implementation has two fundamental limitations:

1. **Skills are invisible** to VS Code because they lack the required `directory/SKILL.md` + YAML frontmatter format. Copilot reads agents fine (they have proper `chatagent` frontmatter) but has no awareness that skills exist. Skills only work when a human manually reads them or explicitly tells an agent to read the file.

2. **Handoffs are navigational only** (no context transfer). In practice, every agent switch requires the user to summarize what the previous agent did. This is workable for a single user who maintains mental context, but it adds friction to every transition.

### What works well

- **Agent definitions** are clean, focused, and properly synced with correct YAML frontmatter (note: per [VS Code docs](https://code.visualstudio.com/docs/copilot/customization/custom-agents#_custom-agent-file-structure), the header/frontmatter is actually optional — VS Code detects any `.md` files in `.github/agents/` as custom agents — but having explicit frontmatter with `description`, `tools`, `model`, and `handoffs` is best practice)
- **The sync script** is a good DRY approach (single source of truth in `.ai/`, generated output in `.github/`)
- **`copilot-instructions.md` as a routing file** is solid — it efficiently directs Copilot to the right places
- **The escalation matrix** in ALWAYS_DO.md is comprehensive and well-structured
- **The flowchart documentation** in `.ai/docs/flowchart.md` is excellent and accurately represents the intended workflow
- **Ownership boundaries** are clearly defined per agent (architect owns epics, documenter owns specs, etc.)
- **Conflict resolution precedence** is explicitly documented
- **The framework separation** (`.ai/` = source, `.github/` = output, `work/` = artifacts) is architecturally sound

---

## RECOMMENDED FIXES (priority order)

| # | Fix | Severity | Effort | Impact |
|---|-----|----------|--------|--------|
| 1 | Restructure skills to `directory/SKILL.md` with YAML frontmatter | CRITICAL | Medium | Enables all 17 skills in VS Code |
| 2 | Fix `docs/gaps.md` → `work/gaps.md` in ALWAYS_DO.md | CRITICAL | Trivial | Prevents wrong file location |
| 3 | Add `epic-wrap` to copilot-instructions skill list | CRITICAL | Trivial | Makes epic lifecycle discoverable |
| 4 | Fix `docs/ROADMAP.md` → `ROADMAP.md` in 4 skill files | HIGH | Low | Fixes 8 broken path references |
| 5 | Add missing handoffs (tester→documenter, documenter→deployer) | HIGH | Low | Completes the development loop |
| 6 | Decide on `docs/development/` — create or update 12 references | HIGH | Medium | Resolves 12 broken references |
| 7 | Decide on `work/epics/active/` — create or update 8 references | HIGH | Medium | Resolves 8 broken references |
| 8 | Enhance handoff prompts with tracking doc fallback references | MODERATE | Low | Improves robustness when starting new sessions |
| 9 | Create `work/releases/` directory | MODERATE | Trivial | Prevents first-wrap failure |
| 10 | Add second handoff to documenter (→ deployer) | MODERATE | Low | Supports wrap workflow |
| 11 | Clarify `@plan` reference in implementer | MODERATE | Trivial | Prevents agent confusion |
| 12 | Update flowchart to remove inactive/deployment reference | MINOR | Trivial | Accuracy |
| 13 | Add missing metadata to milestone-start, context-refresh | MINOR | Trivial | Consistency |

---

---

## Sources Verified

This audit was cross-referenced against these official documentation pages:

| Source | Used to verify |
|--------|----------------|
| [GitHub: About Agent Skills](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills) | C1 — skill directory structure, `SKILL.md` naming, YAML frontmatter requirements |
| [VS Code: Agent Skills](https://code.visualstudio.com/docs/copilot/customization/agent-skills) | C1 — skill discovery, progressive loading, `name`/`description` fields |
| [VS Code: Custom Agents](https://code.visualstudio.com/docs/copilot/customization/custom-agents) | Agent format, handoff semantics, `send: false` behavior, context preservation |
| [GitHub: Adding Repository Custom Instructions](https://docs.github.com/en/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot) | `copilot-instructions.md` format and scope |
| [VS Code: Customize AI](https://code.visualstudio.com/docs/copilot/copilot-customization) | Overview of customization layers (instructions, skills, agents, prompts) |
| Filesystem analysis | All path reference checks (H1–H3, C2) |
| `.ai/docs/flowchart.md` | Intended handoff chain (H4) |

*Audit performed 2026-02-09 by analyzing all files in `.github/` and `.ai/` directories, cross-referencing path declarations against actual filesystem state, validating against official documentation for agents and skills, and tracing the complete handoff chain from architect through deployer.*
