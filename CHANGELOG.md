# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-02-07

### Added
- Multi-target sync system (`sync-to-claude.sh`, `sync-to-copilot.sh`, `sync-all.sh`)
- Claude Code agent support with YAML frontmatter (`name`, `description`, `tools`, `model`)
- Per-target instruction overrides (`instructions/claude/`, `instructions/copilot/`)
- Handoff guide with Mermaid flowchart and escalation table
- Getting Started guide for new users

### Changed
- Sync scripts now support multiple AI tool targets from single canonical source
- Agent escalation routes corrected (Tester escalates to Architect, not Implementer)
- All project-specific references removed for framework portability
- README "Standard Paths" section replaced with pointer to `PROJECT_PATHS.md`

### Removed
- Learning guide (content merged into Getting Started)

## [1.1.0] - 2026-02-03

### Added
- VS Code custom agents integration with automatic sync from canonical definitions
- `sync-agents.sh` for converting `.ai/agents/*.md` to `.github/agents/*.agent.md`
- YAML frontmatter in agent files (tool restrictions, handoffs, model specification)
- Dev container integration for automatic agent sync on setup

### Changed
- Custom agents available in VS Code agent switcher (@architect, @planner, etc.)
- 40% context reduction by loading only active agent instead of all 7

## [1.0.0] - 2026-01-28

### Added
- **maintainer** agent for framework evolution and repository maintenance
- **post-mortem** skill for learning from workflow failures
- **framework-review** skill for periodic framework health assessment
- Project Conventions section in README with standard paths and override mechanism
- Glossary of core terms, workflow concepts, and agent roles
- Conflict resolution hierarchy in ALWAYS_DO.md
- Definition of Done checklist (Must/Should/Nice-to-have) in milestone tracking
- Dependency gating rules (user approval, flag new/unpopular packages)

### Changed
- All agents migrated to concise template with Key Skills and escalation triggers
- Stub skills (branching, release, deployment) upgraded to "honest pointer" format with maturity labels
- All production skills standardized with maturity labels, failure modes, version history
- ALWAYS_DO.md expanded with conflict resolution, performance guidance, security rules

## [0.x] - Before 2026-01-28

Initial framework development:
- Core agents (architect, implementer, tester, documenter, deployer)
- Essential skills (epic lifecycle, milestone lifecycle, TDD workflows)
- Basic guardrails in ALWAYS_DO.md
