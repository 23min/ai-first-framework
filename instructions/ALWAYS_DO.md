# ALWAYS_DO

Purpose: global guardrails that apply to every session, regardless of role.

## CRITICAL: Never Commit Without Approval

**NEVER run `git commit` without explicit human approval.**

Always:
1. Stage changes with `git add`
2. Show what will be committed
3. Wait for human approval
4. Only then commit when explicitly instructed

---

## Core Guardrails

- Follow the project's AI/dev instructions (`ROADMAP.md` for current state, `docs/` for design) and relevant development docs under `work/`.
- No time or effort estimates in docs or plans.
- Search efficiently (prefer fast tools like `rg`/`fd` when available).
- Avoid history-rewriting / destructive git operations unless explicitly instructed.
- Keep docs/schemas/templates aligned when touching contracts.
- Tests must be deterministic; avoid external network calls.
- Use Mermaid for diagrams; avoid ASCII art boxes.
- Prefer minimal, precise edits; avoid broad refactors without context.

## Security & Privacy

- Do not paste secrets/tokens into prompts, docs, issues, or logs.
- Avoid including customer/PII data in examples; use sanitized fixtures.
- **Dependency gating:** All new dependencies must be approved by user before installation; flag packages < 1 year old or with < 100 stars for review.

## Decision & Gap Logging

- Architectural decisions: Create ADR in `work/epics/<epic-slug>/adrs/XXX-decision-title.md`
- Epic progress/scope changes: Add note to epic spec's Progress Notes section
- Milestone work: Use tracking doc's Implementation Log section
- **Project gaps:** Add to `work/GAPS.md` and reference from epic/milestone
- **Framework gaps:** Create issue via `gh issue create -R 23min/ai-first-framework` with appropriate labels
- Ad-hoc work: Log in `PROVENANCE.md` (see `.ai/docs/provenance-format.md`)
- Gaps are out-of-scope by default; review with architect/planner before placement
- One-off work requires explicit user approval and must be logged in PROVENANCE.md

## Conflict Resolution

When instructions conflict, precedence is:
1. Explicit user directive in current session
2. Project-specific docs (CLAUDE.md, ROADMAP.md, project config)
3. ALWAYS_DO.md (this file)
4. Skill-specific guidance
5. Agent role defaults

When in doubt: ask the user.

## Efficiency

- Read only what you need (use grep/search before full file reads)
- Summarize long documents; don't paste full contents into responses
- Use incremental workflows (don't rewrite entire files)
- Keep tracking docs concise (link to details rather than embedding)
- Archive completed milestone docs to reduce context pollution
- **Prefer subagents for handoffs (when available):**
  - VSCode Copilot: Use `runSubagent` tool to spawn fresh context
  - Other environments: Provide concise context summary (max 500 tokens)
  - Avoid full state transfer; focus handoff on next-action requirements
- **Multi-agent handoffs:** For complex workflows (architect → implementer → tester → documenter), use subagents with focused context summaries rather than full state transfer

## Ownership & Handoffs

- Follow agent ownership boundaries defined in agent specs (`.ai/agents/`)
- Follow skill-defined handoff procedures
- See `.ai/docs/handoff-guide.md` for the full handoff chain

## Session Hygiene

- Confirm epic context before milestone execution; if missing, run `epic-refine`/`epic-start`.
- Use TDD: RED -> GREEN -> REFACTOR; list tests first in tracking docs.
- Keep milestone specs stable; use tracking docs for progress updates.
- Build and test before handoff when asked to implement changes.

## When to Update PROVENANCE.md

Update `PROVENANCE.md` for **ad-hoc work only**, such as:
- Quick bug fixes from manual prompts
- Exploratory changes and experiments
- Documentation improvements
- Unplanned refactoring
- Any work NOT part of a formal agent task/milestone

**Do NOT update PROVENANCE.md** for formal agent tasks that have their own tracker files or epic tracking documents.

### Format
```markdown
### YYYY-MM-DD [HH:MM] - Brief Description
**By:** Author + AI Tool | **Commit:** `hash` (if available)

Description of changes made.

**Files:** file1.ts, file2.md
```

## Commit Messages

- Use Conventional Commits format (see `.ai/docs/commit-format.md`)
- Keep subject line under 72 characters, imperative mood
- Add `Co-authored-by: GitHub Copilot` (or appropriate AI tool) for AI-assisted work

## Language

**Repository language:** English — all code, comments, documentation, commit messages, and AI instructions.

## Long Session Protocol

**For conversations >20 exchanges or when context seems stale:**

1. **Proactively suggest context refresh** when:
   - User asks about something covered earlier
   - You notice potential context drift
   - Before starting new major work (epic/milestone)
   - Session has been going for extended period

2. **Refresh by using context-refresh skill:**
   - Re-read `.ai/instructions/ALWAYS_DO.md`
   - Re-read active agent definition
   - Check active epic/milestone docs
   - Confirm current state with user

3. **User can trigger refresh anytime** by saying:
   - "Refresh context"
   - "Reload instructions"
   - "What's my current state?"

See `.ai/skills/context-refresh.md` for full procedure.

## General

- Prefer creating working code over theoretical discussions
- Document decisions and rationale
- Update relevant documentation when making changes
- Follow the AI-First methodology: use AI by default, manual intervention is the exception
- **Never commit without human approval** — always stage changes and wait
