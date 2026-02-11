# AI Framework: Tiered Workflow & Persona Architecture

**Date:** 2026-02-09
**Status:** Analysis / proposal
**Source:** [Claude conversation](https://claude.ai/share/9687a1b7-dc9f-4e35-af46-7ffe980f555f) + Copilot review session

---

## Problem Statement

The framework currently enforces a single-track lifecycle:

```
epic-refine → epic-start → milestone-draft → milestone-start →
red-green-refactor → code-review → milestone-wrap → epic-wrap → release
```

Every agent and skill assumes this full chain exists. This creates two adoption barriers:

1. **Persona mismatch** — A devops engineer fixing a ticket doesn't need epic planning. A PM doesn't need TDD. Different roles in the organization need different subsets.
2. **All-or-nothing onboarding** — Adopters must accept the full ceremony or nothing. There's no lightweight entry point.

BMAD-METHOD solves this with installable modules and workflow tiers. The conversation explored how to bring similar flexibility to our framework.

---

## Proposed Solution: Workflow Modes + Skill Tiers

### Three Workflow Modes

| Mode | Who uses it | Handoffs | Tracking docs | Entry point |
|---|---|---|---|---|
| **full** | Solo devs running entire lifecycle, small teams | All required (architect → planner → documenter → implementer → tester → documenter → architect) | Required (epic, milestone spec, tracking doc) | session-start → full menu |
| **guided** | Developers with milestone specs, feature teams | Implementation chain only (implementer → tester → code-review) | Milestone spec expected, epic optional | session-start → reduced menu |
| **ad-hoc** | Devops, ticket workers, bug fixers | None. Each skill is self-contained. | None required | session-start → quick-fix |

**Key principle:** TDD and core guardrails (ALWAYS_DO.md) apply in ALL modes. Only the inter-agent handoff ceremony changes.

### Mode Detection

1. **Explicit:** User states mode, or `.ai-profile` file declares it
2. **Inferred:** Epic context exists → full; milestone exists → guided; otherwise → ad-hoc
3. **Override:** User can always say "use ad-hoc mode" mid-session

---

## Skill Tier Organization

Reorganize `.ai/skills/` from flat to tiered:

```
.ai/skills/
├── core/                   # Always available, no workflow dependency
│   ├── red-green-refactor.md
│   ├── code-review.md
│   ├── branching.md
│   ├── gap-triage.md
│   ├── context-refresh.md
│   └── quick-fix.md        # NEW — ad-hoc entry point
├── planning/               # Epic/milestone planning
│   ├── epic-refine.md
│   ├── epic-start.md
│   ├── milestone-plan.md
│   ├── milestone-draft.md
│   ├── roadmap.md
│   └── session-start.md
├── lifecycle/              # Full lifecycle management
│   ├── milestone-start.md
│   ├── milestone-wrap.md
│   ├── epic-wrap.md
│   └── release.md
└── meta/                   # Framework maintenance
    ├── framework-review.md
    └── post-mortem.md
```

Agents declare which tiers they use:

| Agent | Tiers |
|---|---|
| architect | planning, core |
| planner | planning, core |
| implementer | core (all modes), lifecycle (full/guided) |
| tester | core |
| documenter | planning, lifecycle |
| deployer | core |
| maintainer | meta, core |

---

## Conditional Handoffs in Skills

Currently, every skill has hardcoded handoff expectations:

- `red-green-refactor.md`: "Next skill: code-review"
- `milestone-start.md`: "Hands off to: milestone-wrap, code-review, red-green-refactor"

**Proposed:** Make handoffs mode-aware. Two implementation options:

### Option A: Conditional sections in skill markdown

```markdown
## Completion

### Full / Guided mode
Hand off to [code-review](code-review.md) — this is required.
Then proceed to [milestone-wrap](milestone-wrap.md).

### Ad-hoc mode
Run tests, commit with conventional commit message, done.
Code review is optional — invoke with "review my changes" if desired.
```

### Option B: Sync script strips handoff sections

The sync script reads the workflow mode from `.ai-profile` and strips the irrelevant `## Completion` sub-sections when generating `.github/skills/`. One source file, mode-specific output.

**Recommendation:** Option A is simpler and more transparent. The skill itself documents all paths, and the agent follows the one matching the current mode.

---

## ALWAYS_DO.md Changes

The current `ALWAYS_DO.md` mandates a fixed handoff chain (lines 73-85). This would change to:

```markdown
## Workflow Modes

This framework supports three workflow modes. Mode is set at session start
or in `.ai-profile`.

### Full mode (default for epic work)
- All handoff artifacts required
- Tracking docs, milestone specs, and epic context must exist

### Guided mode (default for milestone-only work)
- Implementation handoffs required (implementer → tester → code-review)
- Planning chain optional
- Milestone spec should exist, epic context optional

### Ad-hoc mode (default for tickets/bugs)
- No handoffs required. Each skill is self-contained.
- No tracking docs needed
- TDD is still expected

### Mode detection
1. Explicit: user states mode or `.ai-profile` declares it
2. Inferred: epic context → full; milestone → guided; otherwise → ad-hoc
3. Override: user can always change mode mid-session
```

---

## session-start.md as Lightweight Router

Add a mode-detection step before the current menu:

```markdown
### Step 1.5: Determine Workflow Mode

"What kind of work are you doing today?"

a) Quick fix / bug / ticket         → ad-hoc mode → quick-fix skill
b) Feature with a milestone plan    → guided mode → reduced menu
c) Full epic lifecycle              → full mode   → current full menu
d) Just exploring / researching     → ad-hoc mode → explorer/researcher
```

Menu adapts based on mode:

| Mode | Available choices |
|---|---|
| ad-hoc | Quick fix, write tests, review code, something else |
| guided | Implement milestone, write tests, review, wrap milestone |
| full | All current options (plan epic, draft milestone, etc.) |

---

## VS Code Skill Subdirectory Compatibility

**Confirmed compatible.** VS Code's Agent Skills spec (as of Feb 2026) requires:

- Skills stored in `.github/skills/<skill-name>/SKILL.md`
- Each skill in its own subdirectory
- Discovery via `name` and `description` in YAML frontmatter

The source tier organization (`core/`, `planning/`, `lifecycle/`, `meta/`) lives in `.ai/skills/` only. The sync script flattens them into `.github/skills/<skill-name>/SKILL.md` as today. VS Code never sees the tier structure — it's an internal organizational concern.

The `copilot-instructions.md` skill listing and the sync script handle the mapping:

```
.ai/skills/core/quick-fix.md  →  .github/skills/quick-fix/SKILL.md
.ai/skills/lifecycle/release.md  →  .github/skills/release/SKILL.md
```

---

## quick-fix Skill (New)

The ad-hoc entry point. Self-contained, no lifecycle dependency:

```markdown
# Skill: quick-fix

Purpose: Lightweight skill for bug fixes, small features, and ticket work.
No epic or milestone context required.

## Inputs
- Issue/ticket reference (optional)
- Description of what needs to change

## Steps
1. Understand current vs expected behavior
2. Locate relevant code (use @explorer if available)
3. Write a failing test (RED)
4. Implement the fix (GREEN)
5. Refactor if needed (REFACTOR)
6. Run full test suite
7. Commit with conventional commit message

## Completion
Done. No handoff required.
Optional: invoke "review my changes" for a code-review pass.
```

---

## Persona-to-Mode Mapping (Organization Profiles)

Instead of full YAML profile manifests (premature without adopters), use a simple `.ai-profile` file:

```properties
# .ai-profile — project-level workflow configuration
workflow_mode=full          # full | guided | ad-hoc
default_entry=session-start # or quick-fix for ad-hoc teams
```

This is enough for the sync script to:
1. Include/exclude handoff buttons on agents
2. Include/exclude lifecycle skills from `.github/skills/`
3. Set the default entry point in `session-start`

Richer profiles (agent subsets, skill filtering) can be added when the organization demands it.

---

## Implementation Priority

| # | Change | Effort | Impact | Depends on |
|---|---|---|---|---|
| 1 | Add `quick-fix.md` skill | Low | Opens framework to ad-hoc usage | — |
| 2 | Add `research.md` skill (pre-epic brainstorm/PRD) | Low | Opens framework to PM/architect entry | — |
| 3 | Add workflow mode section to ALWAYS_DO.md | Low | Makes handoff chain conditional | — |
| 4 | Update session-start as persona-aware router | Low | Jump-in-anywhere entry for all personas | #3 |
| 5 | Make handoffs conditional in existing skills | Medium | Decouples skills from lifecycle | #3 |
| 6 | Add task decomposition to milestone-plan/start | Medium | Dev-sized work units within milestones | — |
| 7 | Reorganize skills into tier subdirectories | Medium | Better organization, clearer tiers | — |
| 8 | Update sync-agents.sh for tier-aware output | Medium | Mode controls what gets synced | #7 |
| 9 | Add `.ai-profile` support | Low | Persistent mode configuration | #3 |
| 10 | Profile YAML manifests (agent subsets) | High | Full persona customization | #7, #8, #9 |

Items 1-4 can be done incrementally on the current structure. Items 5-8 are the structural reorganization.

---

## Jump-In-Anywhere Model

### Core Principle

Any persona can enter the workflow at any point. Skills are **entry points with declared inputs**, not steps in a fixed chain. If the input already exists (someone else created it), skip everything before it.

```
Current model (sequential):
  epic-refine ──► epic-start ──► milestone-draft ──► milestone-start ──► ...
  (must flow left to right, each step requires the previous)

Proposed model (jump-in):
  Each skill declares its inputs. If inputs exist, start there.

  research:        needs → topic/question
  epic-refine:     needs → idea or research docs
  epic-start:      needs → epic spec (can already exist)
  milestone-plan:  needs → epic spec (just point to it)
  milestone-draft: needs → milestone plan (just point to it)
  milestone-start: needs → milestone spec (just point to it)
  quick-fix:       needs → description of what to change
```

If the input doesn't exist, the skill tells you what's needed and optionally routes you to the skill that creates it — but doesn't *force* the chain.

### Persona Entry Points

| Persona | Enters at | Inputs they bring | What they produce | Skills used |
|---|---|---|---|---|
| **PM / Architect** (research) | Beginning | Idea, problem statement | Research docs, PRD in `docs/research/` or `docs/guides/` | `research` (NEW), `@researcher`, `@explorer` |
| **PM / Architect** (planning) | Epic planning | Research docs or domain knowledge | Epic spec in `work/epics/` | `epic-refine`, `epic-start` |
| **Team lead / Scrum master** | Milestone planning | Epic spec (someone else wrote it) | Milestone plan + specs, task decomposition | `milestone-plan`, `milestone-draft` |
| **Developer** (structured) | Milestone implementation | Milestone spec (someone else wrote it) | Code + tests + tracking doc | `milestone-start`, `red-green-refactor` |
| **Developer** (ad-hoc) | Ticket/bug | Issue description or ticket URL | Code + tests + commit | `quick-fix` |
| **Tester** | Test/review | Code to review (someone else wrote it) | Test results, review feedback | `code-review`, `red-green-refactor` |
| **Documenter** | Wrap-up | Completed milestone/epic | Release notes, changelog, docs | `milestone-wrap`, `epic-wrap` |

### Gaps Identified

**Gap 1: No pre-epic research/brainstorm skill**

The lifecycle starts at `epic-refine` but PMs and architects need to brainstorm, research, and create ground documentation *before* an epic exists. This produces the input to `epic-refine`.

Needed: A `research` or `prd-draft` skill that:
- Structures brainstorming sessions
- Uses `@researcher` for external knowledge, `@explorer` for codebase discovery
- Produces documentation in `docs/research/<topic>/` or `docs/guides/`
- Has no handoff requirement — output is a document, not a workflow step

**Gap 2: No task/issue level below milestone**

Milestones are too coarse for "one dev picks it up." The current structure:

```
Epic (weeks-months)
  └── Milestone (days-weeks)     ← this is the smallest unit today
```

For team adoption, you need:

```
Epic (weeks-months)
  └── Milestone (1-2 weeks)
       └── Task / Issue (hours-days)  ← dev-sized, maps to GitHub issue or DevOps work item
```

Options:
- **A) Milestones become dev-sized** — redefine milestone granularity to ~1-3 days. Simpler but changes the meaning of "milestone."
- **B) Add task decomposition** — `milestone-plan` or `milestone-start` produces a checklist of tasks, each mappable to an issue/ticket. The dev takes one task, not the whole milestone.
- **C) Map to external tracker** — milestones stay coarse, but `milestone-draft` creates GitHub issues for each task within the milestone. Devs work from issues.

**Recommendation:** Option B for now (task checklist within milestone), with Option C as a future enhancement when the org uses a ticket tracker.

### How session-start Routes by Persona

Updated session-start flow with jump-in support:

```
"What kind of work are you doing today?"

a) Research / brainstorm a solution     → research skill (NEW)
b) Plan an epic from existing research  → epic-refine
c) Break an epic into milestones        → milestone-plan
d) Draft a milestone specification      → milestone-draft
e) Implement a milestone                → milestone-start (guided mode)
f) Fix a bug / implement a ticket       → quick-fix (ad-hoc mode)
g) Write or review tests                → red-green-refactor / code-review
h) Wrap up completed work               → milestone-wrap / epic-wrap
i) Something else                       → ask for details
```

Each option is self-sufficient. No option requires a prior option to have been completed in the same session or by the same person.

---

## Team Coordination: Multi-Dev Milestone Work

### The Problem

The current framework assumes one person per milestone. The tracking doc at `work/milestones/tracking/<id>-tracking.md` lives in the repo. If 3 devs work on the same milestone, they all edit the same file → merge conflicts guaranteed.

### Source of Truth Split

For team work, coordination state must live **outside the repo**:

| Concern | Source of truth | Where |
|---|---|---|
| **What to build** (plan) | Milestone spec | Repo: `work/milestones/m-xxx.md` (read-only during impl) |
| **Who's doing what** (assignment) | Issue tracker | GitHub Issues / Azure DevOps work items |
| **Current status** (progress) | Issue tracker + PR status | GitHub / DevOps board |
| **What was built** (code) | Pull requests | Repo: task branch → milestone branch |
| **Was it done right** (quality) | PR reviews + CI | GitHub PR checks |

The repo holds the **plan** and the **code**. The issue tracker holds the **live coordination state**.

### Branch Strategy for Team Milestones

```
main
 └── epic/critical-flow
      ├── work/milestones/m-cfdf-03.md              ← spec (written once, read-only)
      └── milestone/m-cfdf-03                        ← integration branch
           ├── feature/m3/parser-models  → PR #20    ← Dev A
           ├── feature/m3/ingest-svc     → PR #21    ← Dev B
           └── feature/m3/cli-entry      → PR #22    ← Dev C
```

Each dev works on their own branch. PRs merge to the milestone integration branch. No contention.

### Developer Workflow (Concrete)

**Dev A opens VS Code:**

```
Dev:  "Working on issue #12 — Parser models for milestone m-cfdf-03"

Framework detects:
  - Issue reference → looks up context
  - Milestone spec exists → guided mode
  - Creates branch: feature/m3/parser-models off milestone/m-cfdf-03

Dev works:
  - TDD cycle (red → green → refactor) for their task only
  - Commits with: "feat(parser): add response time models (closes #12)"

Dev finishes:
  - Opens PR: feature/m3/parser-models → milestone/m-cfdf-03
  - PR description references: "Implements task #12 from m-cfdf-03"
  - PR contains: code + tests. NOT the milestone spec or tracking doc.
```

**Dev B and C do the same, independently, on their own branches.**

**Team lead wraps the milestone** when all task PRs are merged:
1. All task issues closed
2. Runs `milestone-wrap` on `milestone/m-cfdf-03`
3. Verifies acceptance criteria from the spec
4. Opens PR: `milestone/m-cfdf-03` → `epic/critical-flow` (or main)
5. Updates milestone spec with completion status (single person, no conflict)

### What Happens to the Tracking Doc?

| Mode | Tracking doc role |
|---|---|
| **Solo (full/guided)** | Optional but useful — records TDD cycles, decisions, blockers |
| **Team** | **Replaced by issue tracker + PR descriptions.** Each PR is its own tracking record. The milestone spec captures completion at wrap time. |

The tracking doc can still be created for complex solo milestones, but it's not the coordination mechanism for teams.

### Milestone Spec in PRs?

**No.** The milestone spec is the *plan*, written before implementation. It:
- Lives on the epic branch (or main) before implementation starts
- Is referenced by task PRs ("Implements task X from m-cfdf-03") but not included in them
- Gets a completion summary appended at `milestone-wrap` time (by the person wrapping, not by task devs)

### Task Creation During milestone-plan

The `milestone-plan` skill (or a new `milestone-tasks` skill) would:

1. Read the milestone spec's acceptance criteria and scope
2. Decompose into dev-sized tasks (hours to ~2 days each)
3. Create GitHub Issues (via `gh issue create`) with:
   - Title: task description
   - Labels: milestone ID, epic slug
   - Body: acceptance criteria subset, relevant spec section link
4. Output: list of issue numbers linked to the milestone spec

```bash
# Example output from milestone-plan task decomposition
gh issue create --title "Parser models for response times" \
  --label "m-cfdf-03,epic/critical-flow" \
  --body "Part of milestone m-cfdf-03. See work/milestones/m-cfdf-03.md §Parser"

gh issue create --title "Ingest service for Kusto data" \
  --label "m-cfdf-03,epic/critical-flow" \
  --body "Part of milestone m-cfdf-03. See work/milestones/m-cfdf-03.md §Ingest"
```

The milestone spec would reference the created issues:

```markdown
## Tasks
- [ ] #12 — Parser models for response times (assigned: Dev A)
- [ ] #13 — Ingest service for Kusto data (assigned: Dev B)
- [ ] #14 — CLI entry point (assigned: Dev C)
- [ ] #15 — Error handling (unassigned)
```

This is updated in the issue tracker, not by devs editing the spec.

### Task Dependencies Within a Milestone

Tasks within a milestone are often dependent on each other (e.g., models must exist before the service that uses them). Three mechanisms handle this:

#### 1. Phased task ordering in the milestone spec

The milestone spec groups tasks into phases with explicit dependencies:

```markdown
## Tasks

### Phase 1 (parallel — no dependencies)
- [ ] #12 — Parser models for response times
- [ ] #13 — Ingest service interface (contract/interface only)

### Phase 2 (depends on Phase 1)
- [ ] #14 — Ingest implementation (needs #12 merged)
- [ ] #15 — CLI entry point (needs #13 merged)

### Phase 3 (depends on Phase 2)
- [ ] #16 — Integration tests (needs #14 + #15)
```

Phase 2 issues are created immediately but labeled `blocked` until their dependencies merge. The issue tracker (not the repo) tracks blocked/unblocked status.

#### 2. The milestone branch as sync point

This is the critical mechanism. The milestone integration branch accumulates completed work:

```
milestone/m-cfdf-03  ←── PR #20 (parser models) MERGED
     │
     ├── feature/m3/ingest-impl    ← Dev B rebases from milestone branch
     │                                → parser models now available
     └── feature/m3/cli-entry      ← Dev C rebases too
```

**Flow:**
1. Dev A merges parser models to `milestone/m-cfdf-03`
2. Dev B rebases `feature/m3/ingest-impl` onto updated milestone branch
3. Dev B now has parser models in their working tree — dependency resolved
4. No coordination meeting needed; the branch IS the handoff

Devs rebase from the milestone branch frequently (at least when a dependency merges) to stay current.

#### 3. Tightly coupled tasks — stacked branches

When two tasks are so intertwined that separate branches add overhead:

**Option A: Pair on one branch.** Two devs, one task branch. Works for 2 people.

**Option B: Stack PRs.** Dev B branches off Dev A's branch instead of the milestone branch:

```
milestone/m-cfdf-03
 └── feature/m3/parser-models        ← Dev A works here
      └── feature/m3/ingest-impl     ← Dev B branches off Dev A
```

When Dev A's PR merges to milestone branch → Dev B retargets their PR to the milestone branch and rebases. GitHub supports this natively with PR base branch changes.

#### Summary: dependency resolution

| Dependency type | Mechanism | Who coordinates |
|---|---|---|
| **Loose** (same milestone, no code overlap) | Parallel branches, merge independently | No coordination needed |
| **Sequential** (B needs A's output) | Phases in spec; B rebases from milestone branch after A merges | Issue tracker signals unblock |
| **Tight** (A and B co-evolve) | Stacked branches or pair on one branch | The two devs directly |
| **Cross-milestone** | Milestone ordering in epic spec; milestone branch merges to epic branch | Team lead / planner |

---

## Pipeline Automation: Milestone Status Sync

### Motivation

Humans shouldn't manually update task checklists or unblock dependencies. The CI pipeline becomes the **automated bookkeeper** — when a task PR merges, the pipeline updates the issue tracker and optionally prepares the milestone wrap.

### Trigger

```yaml
# .github/workflows/milestone-sync.yml
name: Milestone Task Sync

on:
  pull_request:
    types: [closed]
    branches:
      - 'milestone/**'

jobs:
  update-milestone:
    if: github.event.pull_request.merged == true
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Extract milestone and task info
        id: meta
        run: |
          # Parse milestone ID from target branch (e.g. milestone/m-cfdf-03)
          MILESTONE_ID=$(echo "${{ github.event.pull_request.base.ref }}" | sed 's|milestone/||')
          echo "milestone_id=$MILESTONE_ID" >> "$GITHUB_OUTPUT"

          # Extract closed issue numbers from PR body ("Closes #12" / "Fixes #13")
          ISSUES=$(echo "${{ github.event.pull_request.body }}" \
            | grep -oiE '(closes|fixes|resolves) #[0-9]+' \
            | grep -oE '[0-9]+' | tr '\n' ' ')
          echo "closed_issues=$ISSUES" >> "$GITHUB_OUTPUT"

      - name: Update milestone tracking issue
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          MILESTONE_ID="${{ steps.meta.outputs.milestone_id }}"

          # Find the milestone tracking issue by label
          TRACKING_ISSUE=$(gh issue list \
            --label "milestone:${MILESTONE_ID}" \
            --label "tracking" \
            --json number --jq '.[0].number')

          if [ -z "$TRACKING_ISSUE" ]; then
            echo "No tracking issue found for ${MILESTONE_ID}"
            exit 0
          fi

          # Check off completed tasks in the tracking issue body
          for ISSUE_NUM in ${{ steps.meta.outputs.closed_issues }}; do
            echo "Checking off #${ISSUE_NUM} in tracking issue #${TRACKING_ISSUE}"
            # GitHub auto-checks task list items when issues close,
            # but we add a comment for visibility
            gh issue comment "$TRACKING_ISSUE" \
              --body "✅ Task #${ISSUE_NUM} completed via PR #${{ github.event.pull_request.number }}"
          done

      - name: Unblock dependent issues
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          for ISSUE_NUM in ${{ steps.meta.outputs.closed_issues }}; do
            # Find issues that reference this one as a blocker
            BLOCKED=$(gh issue list \
              --label "blocked" \
              --search "blocked by #${ISSUE_NUM}" \
              --json number --jq '.[].number')

            for BLOCKED_NUM in $BLOCKED; do
              echo "Unblocking #${BLOCKED_NUM} (was blocked by #${ISSUE_NUM})"
              gh issue edit "$BLOCKED_NUM" --remove-label "blocked"
              gh issue comment "$BLOCKED_NUM" \
                --body "🔓 Unblocked: dependency #${ISSUE_NUM} is now merged."
            done
          done

      - name: Check milestone completion
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          MILESTONE_ID="${{ steps.meta.outputs.milestone_id }}"

          # Count open issues for this milestone
          OPEN=$(gh issue list \
            --label "milestone:${MILESTONE_ID}" \
            --state open \
            --json number --jq 'length')

          TOTAL=$(gh issue list \
            --label "milestone:${MILESTONE_ID}" \
            --state all \
            --label "task" \
            --json number --jq 'length')

          DONE=$((TOTAL - OPEN))

          echo "Milestone ${MILESTONE_ID}: ${DONE}/${TOTAL} tasks complete"

          if [ "$OPEN" -eq 0 ] && [ "$TOTAL" -gt 0 ]; then
            echo "🎉 All tasks complete! Creating wrap notification."

            # Post to tracking issue
            TRACKING_ISSUE=$(gh issue list \
              --label "milestone:${MILESTONE_ID}" \
              --label "tracking" \
              --json number --jq '.[0].number')

            gh issue comment "$TRACKING_ISSUE" \
              --body "## 🎉 All tasks complete

            All ${TOTAL} tasks for **${MILESTONE_ID}** have been merged.

            **Next steps:**
            1. Run full test suite on \`milestone/${MILESTONE_ID}\` branch
            2. Run \`milestone-wrap\` skill to verify acceptance criteria
            3. Create PR to epic/main branch

            cc @team-lead"
          fi
```

### Three Levels of Automation

| Level | What it does | Risk | Recommended for |
|---|---|---|---|
| **1: Status bookkeeping** | Checks off tasks, unblocks dependents, posts progress comments | Low | All teams (start here) |
| **2: Quality gate** | All tasks done → runs test suite on milestone branch → creates draft wrap PR | Medium | Teams with good test coverage |
| **3: Auto-wrap** | Tests pass → auto-generates completion summary from PR descriptions → prepares release notes | Higher | Mature teams with high CI confidence |

**Level 2 addition** (add to the workflow):

```yaml
      - name: Quality gate — create wrap PR
        if: env.ALL_TASKS_COMPLETE == 'true'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          MILESTONE_ID="${{ steps.meta.outputs.milestone_id }}"

          # Determine target branch (epic branch or main)
          # Convention: epic branch is stored in milestone tracking issue body
          TARGET="main"  # default, override from tracking issue metadata

          gh pr create \
            --base "$TARGET" \
            --head "milestone/${MILESTONE_ID}" \
            --title "Milestone ${MILESTONE_ID}: All tasks complete" \
            --body "## Milestone Wrap PR

          All task PRs have been merged and tests are passing.

          ### Merged PRs
          $(gh pr list --base "milestone/${MILESTONE_ID}" --state merged \
            --json number,title --jq '.[] | "- #\(.number) \(.title)"')

          ### Next steps
          - [ ] Run \`milestone-wrap\` skill to verify acceptance criteria
          - [ ] Review and approve this PR
          - [ ] Merge to target branch" \
            --draft
```

### PR Convention for Pipeline Parsing

For the pipeline to work, task PRs need a consistent format:

```markdown
# PR Template (.github/PULL_REQUEST_TEMPLATE/task.md)

## Summary
<!-- What does this PR do? -->

## Task Reference
Closes #<issue_number>
Milestone: m-<id>

## TDD Notes
- RED: <what test was written>
- GREEN: <what was implemented>
- REFACTOR: <what was improved>

## Checklist
- [ ] Tests pass locally
- [ ] Conventional commit messages used
- [ ] No WIP or commented-out code
```

The pipeline parses `Closes #<number>` (GitHub native) and `Milestone: m-<id>` (convention).

### What NOT to Automate

| Concern | Automated? | Why |
|---|---|---|
| Task check-off in tracker | ✅ Yes | Mechanical — PR merge = task done |
| Unblocking dependents | ✅ Yes | Mechanical — remove label, post comment |
| Progress notifications | ✅ Yes | Visibility for the team |
| Test suite on milestone branch | ✅ Yes | CI does this already |
| Creating draft wrap PR | ✅ Yes | Saves time, human still reviews |
| Milestone spec content changes | ❌ No | Semantic — human verifies criteria are *met* |
| Task assignment | ❌ No | Team/lead decision |
| Acceptance criteria sign-off | ❌ No | Human judgment required |
| Merging the wrap PR | ❌ No | Human gate (ALWAYS_DO.md principle) |

---

## References

- [Claude conversation: Framework flexibility analysis](https://claude.ai/share/9687a1b7-dc9f-4e35-af46-7ffe980f555f)
- [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) — installable modules, workflow tiers
- [ai-first-framework](https://github.com/23min/ai-first-framework) — source framework
- [VS Code Agent Skills spec](https://code.visualstudio.com/docs/copilot/customization/agent-skills)
- [Agent Skills open standard](https://agentskills.io/)
