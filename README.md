# Claude Skills

A collection of Claude Code skills for code review and implementation analysis, powered by parallel subagents.

## Skills

| Skill | Description |
|-------|-------------|
| **flag-review** | Triage AI-generated code review flags. Spawns a subagent per flag to investigate, auto-fixes actionable issues, and dismisses noise. |
| **feedback-review** | Vet feedback from any source (teammate PR reviews, AI flags, structured findings). Parallel subagents evaluate each point for correctness, optimality, and elegance. |
| **implementation-review** | Deep code review across three axes (correctness, optimality, elegance) using three parallel subagents. Produces a unified review with a ship/fix/discuss verdict. |
| **implementation-recap** | Generates a structured writeup of the problem, solution, and defense of why the approach is correct, optimal, and elegant. |
| **codex-review** | Cross-validates changes using OpenAI Codex CLI as an independent reviewer. Iterative loop: Codex reviews, subagents evaluate feedback, fixes are applied, Codex re-reviews until approval. |

## Install

### As a plugin (recommended, auto-updates)

```
/plugin marketplace add phytal/claude-skills
/plugin install claude-skills@phytal-skills
```

### Manual

```bash
git clone https://github.com/phytal/claude-skills.git
cd claude-skills
./install.sh
```

This copies the skills to `~/.claude/skills/` where they're available globally.

## Usage

Invoke any skill directly:

```
/flag-review
/feedback-review
/implementation-review
/implementation-recap
/codex-review
```

Or just describe what you need — the skills trigger automatically based on context.

## License

MIT
