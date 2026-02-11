# AI Skills & Agents Improvement — Model Differentiation for Token Optimization

**Date:** 2025-02-09
**Based on:** Analysis of [bigguy345/Github-Copilot-Atlas](https://github.com/bigguy345/Github-Copilot-Atlas)
**Scope:** Model assignment strategy, context conservation, agent architecture improvements

---

## 1. Atlas Model Assignment Strategy

The Atlas project uses a **conductor–delegate** pattern where a main orchestrator (Atlas) delegates to specialized subagents. Each agent is assigned a model based on the cognitive demands of its role:

| Agent | Role | Model | Rationale |
|---|---|---|---|
| **Atlas** | Orchestrator | Claude Sonnet 4.5 | Needs to understand plans, delegate, track state |
| **Prometheus** | Planner | GPT-5.2 (high reasoning) | Complex analysis, plan synthesis — most demanding |
| **Oracle** | Researcher | GPT-5.2 | Deep subsystem analysis, structured findings |
| **Sisyphus** | Implementer | Claude Sonnet 4.5 | Code generation, TDD — needs strong code output |
| **Explorer** | Scout | **Gemini 3 Flash** | Read-only file discovery — cheapest model, speed-optimized |
| **Frontend-Engineer** | UI/UX | Gemini 3 Pro | Component/styling — mid-tier, domain-specialized |
| **Code-Review** | Reviewer | GPT-5.2 | Critical reasoning about correctness |

**Key principle:** Match model capability to task complexity. Read-only exploration uses the cheapest/fastest model. Reasoning-heavy work (planning, review) uses premium reasoning models. Code generation uses strong-but-not-maximal models.

---

## 2. Our Current Setup (Treehouse)

| Agent | Role | Model | Tools |
|---|---|---|---|
| **architect** | Design decisions, system boundaries | Claude Sonnet 4 | search, fetch, usages, githubRepo |
| **planner** | Milestone sequencing | Claude Sonnet 4 | search, fetch, usages, githubRepo |
| **implementer** | Code implementation | Claude Sonnet 4 | `*` (all tools) |
| **tester** | Test planning, validation | Claude Sonnet 4 | search, fetch, usages, terminal, grep |
| **documenter** | Documentation, specs | Claude Sonnet 4 | search, fetch, usages, edit |
| **deployer** | Infrastructure, releases | Claude Sonnet 4 | terminal, docker, fetch, edit |
| **maintainer** | Framework & repo maintenance | Claude Sonnet 4 | search, fetch, usages, grep, edit |

**Problem:** All 7 agents use the same model regardless of task complexity. A documentation update consumes the same token budget and model cost as complex architectural reasoning.

---

## 3. Comparison & Gaps

| Dimension | Atlas | Treehouse | Gap |
|---|---|---|---|
| Model differentiation | 4 different models across 7 agents | 1 model for all 7 | **High** |
| Cheap exploration agent | Gemini Flash for read-only discovery | None | **High** |
| Context conservation | Explicit strategy (delegate to preserve window) | Implicit (scoped tools only) | **Medium** |
| Subagent delegation | Conductor invokes subagents via `runSubagent` | Sequential handoffs with human gates | **Low** (different pattern, both valid) |
| Parallel execution | Up to 10 subagents in parallel | Sequential pipeline | **Low** (our pattern is human-gated by design) |
| Tool scoping | Per-agent tool restrictions | Per-agent tool restrictions | **Already aligned** |

---

## 4. Model Tier Recommendations

Based on the Atlas patterns and available VS Code Copilot models, here is a proposed model assignment for Treehouse agents:

### Tier 1 — Premium Reasoning (complex analysis, planning)
> Best models for multi-step reasoning, architecture decisions, risk assessment

| Agent | Current | Recommended | Why |
|---|---|---|---|
| **architect** | Claude Sonnet 4 | **Claude Sonnet 4** (keep) or **GPT-5.2** | Design decisions need strong reasoning. Already appropriate tier. |
| **planner** | Claude Sonnet 4 | **Claude Sonnet 4** (keep) or **GPT-5.2** | Milestone sequencing requires careful analysis. |

### Tier 2 — Strong Code Generation (implementation, testing)
> Good code output, TDD discipline, needs to read and write code well

| Agent | Current | Recommended | Why |
|---|---|---|---|
| **implementer** | Claude Sonnet 4 | **Claude Sonnet 4** (keep) | Already well-matched. Code generation is Claude's strength. |
| **tester** | Claude Sonnet 4 | **Claude Sonnet 4** (keep) | Test reasoning needs similar capability to implementation. |

### Tier 3 — Mid-Tier (documentation, releases, maintenance)
> Primarily text generation, config editing, structured output. Doesn't need top-tier reasoning.

| Agent | Current | Recommended | Why |
|---|---|---|---|
| **documenter** | Claude Sonnet 4 | **GPT-4.1** or **Claude Haiku** | Documentation is well-structured text work. Cheaper model suffices. |
| **deployer** | Claude Sonnet 4 | **GPT-4.1** or **Claude Haiku** | Release scripts, config generation — templated work. |
| **maintainer** | Claude Sonnet 4 | **GPT-4.1** or **Claude Haiku** | Framework maintenance, repo hygiene — lower complexity. |

### Potential New Agent — Explorer (Tier 4, cheapest)
> Read-only codebase discovery. No edits, no terminal. Fastest/cheapest model.

| Agent | Model | Tools | Purpose |
|---|---|---|---|
| **explorer** (new) | **Gemini Flash** | search, usages, grep | Rapid file discovery before deeper analysis. Preserves context for other agents. |

---

## 5. Implementation Options

### Option A: Model Differentiation Only (Low Effort, High Impact)
Update `sync-agents.sh` to assign different models per agent role. No structural changes.

**Changes required:**
1. Add a model lookup to the `case` statement in `sync-agents.sh` (alongside the existing tools lookup)
2. Re-run sync

**Estimated savings:** 30–50% token reduction on documentation, deployment, and maintenance tasks.

**Example change to `sync-agents.sh`:**
```bash
# Determine model by agent role
case "$basename" in
  architect|planner)
    model="Claude Sonnet 4"
    ;;
  implementer|tester)
    model="Claude Sonnet 4"
    ;;
  documenter|deployer|maintainer)
    model="GPT-4.1"
    ;;
  explorer)
    model="Gemini Flash"
    ;;
  *)
    model="Claude Sonnet 4"
    ;;
esac
```

### Option B: Add Explorer Agent (Medium Effort, Medium Impact)
Create a new lightweight `explorer` agent for read-only codebase discovery.

**Changes required:**
1. Create `.ai/agents/explorer.md` with read-only exploration instructions
2. Update `sync-agents.sh` to handle explorer's minimal tool set
3. Add explorer to handoff options (architect, planner can delegate to explorer)

**Benefit:** Other agents can say "Ask @explorer to find…" before diving in themselves, preserving their context windows for actual work.

### Option C: Full Conductor Pattern (High Effort, High Impact)
Adopt Atlas-style conductor pattern where one orchestrator agent delegates to subagents via `runSubagent`.

**Not recommended yet.** Our human-gated sequential pipeline is intentional and appropriate for our team size and workflow maturity. The conductor pattern trades human control for automation speed — a different design philosophy.

---

## 6. Model Availability Note

Available models in VS Code Copilot (as of early 2025, varies by subscription):
- **Claude Sonnet 4 / 4.5** — Strong all-around, excellent code generation
- **GPT-4o / GPT-4.1** — Good reasoning, cost-effective for text tasks
- **GPT-5.2** — Premium reasoning (may require Copilot Pro+)
- **Gemini Flash / Pro** — Fast and cheap, good for exploration
- **Claude Haiku** — Cheapest Claude, good for simple structured tasks

Check your VS Code Copilot model picker for actual availability. Model names in agent frontmatter must match exactly what VS Code offers.

---

## 7. Skills — Model Assignment

VS Code skills (`.github/skills/*/SKILL.md`) do **not** support a `model` field in their YAML frontmatter — only `name` and `description`. Skills are prompt snippets loaded into whichever agent/chat invokes them.

However, skills can **document a recommended model** in their body text:
```markdown
> **Recommended model:** Use with @documenter (GPT-4.1) for best cost/quality balance.
```

This is advisory, not enforced. The real token savings come from agent model assignment, not skills.

---

## 8. Recommended Action Plan

| # | Action | Effort | Impact | Priority |
|---|---|---|---|---|
| 1 | Add model lookup to `sync-agents.sh` | 15 min | High | **Do first** |
| 2 | Assign cheaper models to documenter, deployer, maintainer | 5 min | High | **Do first** |
| 3 | Keep premium models for architect, planner, implementer, tester | 0 min | Baseline | Already done |
| 4 | Create explorer agent (read-only, Gemini Flash) | 30 min | Medium | **Consider** |
| 5 | Add "recommended model" hints to skill docs | 15 min | Low | Optional |
| 6 | Evaluate conductor pattern (Atlas-style) | Research | Future | Defer |

---

## 9. Context Conservation Principle (from Atlas)

> *"Before reading files yourself, ask: Would a subagent summarize this better? If a task requires >1000 tokens of context, strongly consider delegation. Prefer delegation when in doubt — subagents are cheaper and focused."*

Even without the full conductor pattern, we can apply this principle:
- **Scoped tool access** (already done — only implementer has `*`)
- **Model tiering** (proposed above — match model cost to task complexity)
- **Explorer delegation** (proposed — cheap model handles file discovery)
- **Tight skill prompts** (already have good structure — skills are focused and concise)

---

*This analysis is for internal reference and is not tracked in git.*
