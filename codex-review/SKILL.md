---
name: codex-review
description: >
  Cross-validate Claude Code's implementation plan or code changes using OpenAI Codex CLI
  as an independent second opinion. Runs an iterative review loop: Codex reviews, Claude
  dispatches subagents to evaluate each feedback point in parallel (using feedback-review
  analysis), implements accepted changes via parallel subagents, then sends a summary back
  to the same Codex conversation for re-review. Repeats until Codex approves or has no
  further actionable feedback. Triggers on phrases like "codex review", "double check with
  codex", "second opinion", "cross-validate", or "verify with codex".
---

# Codex Review

Iterative cross-validation loop between Claude Code and OpenAI Codex CLI, using parallel subagents for thorough evaluation and implementation.

## Prerequisites

- `codex` CLI must be installed and authenticated (`which codex` to verify)
- An OpenAI API key must be configured for codex

## Workflow Overview

```
Codex reviews code/plan (background Bash + TaskOutput)
        |
        v
Spawn subagents to evaluate each feedback point in parallel
        |
        v
Spawn subagents to implement accepted changes in parallel
        |
        v
Resume Codex conversation with change summary
        |
        v
Codex re-reviews --> loop until APPROVE or no actionable feedback
```

## Step 1: Identify what to review

Determine the scope:
- **Uncommitted diff** (default): All staged/unstaged/untracked changes
- **Code changes**: Specific files Claude just wrote or edited
- **A plan**: An implementation plan Claude produced

## Step 2: Run initial Codex review

Use the **Write tool** to write the review prompt to `/tmp/codex-prompt.txt`, then run `codex exec` as a **background Bash call** (`run_in_background: true`). Use `TaskOutput` to block until Codex finishes, then read the output file.

**Do NOT use Task subagents for running Codex** — subagent Bash permissions are more restrictive than the main conversation and will be denied for file writes and `codex exec`.

### 2a. Write the prompt file

Use the Write tool to create `/tmp/codex-prompt.txt` with the following content (fill in the CONTEXT section):

```
You are an independent code reviewer. Your job is to thoroughly review code changes in this repository.

<CONTEXT>
[concise summary of what was implemented, why, and which files were changed]
</CONTEXT>

Review process:
1. Run 'git diff' and 'git diff --cached' to see all changes
2. Read the changed files in full to understand context
3. Read any other files you need (imports, callers, tests, types) to fully understand the impact
4. Do NOT stop early -- read as many files as you need for a complete review

Evaluate on three dimensions:
- CORRECTNESS: Bugs, logic errors, missing edge cases, incorrect assumptions, broken contracts
- OPTIMALITY: Unnecessary complexity, better algorithms, simpler approaches, performance concerns
- ELEGANCE: Code style consistency, idiomatic patterns, maintainability, naming

For each issue found:
- Reference the specific file path and line number
- Explain what is wrong and why
- Suggest a concrete fix

End with an overall verdict: APPROVE, REQUEST CHANGES, or NEEDS DISCUSSION.
If REQUEST CHANGES, number each requested change for easy reference.
```

### 2b. Run Codex in the background

```bash
# run_in_background: true
codex exec -C <project-root> --sandbox read-only \
  -o /tmp/codex-review-output.txt \
  - < /tmp/codex-prompt.txt
```

Then use `TaskOutput(task_id=<id>, block=true, timeout=600000)` to wait for completion (up to 10 minutes).

### 2c. Read the output

Use the Read tool to read `/tmp/codex-review-output.txt`.

For reviewing a **plan** instead of code, replace the review instructions accordingly — ask Codex to validate that referenced files/functions exist and behave as assumed, and that the approach is sound.

Execution notes:
- Always use `--sandbox read-only` — Codex must never write files
- Use `-C <dir>` to point at the project root
- Always use `-o /tmp/codex-review-output.txt` to capture the final message
- Always write the prompt with the Write tool — never use `cat << 'EOF'` in Bash

## Step 3: Evaluate Codex's feedback using parallel subagents

Parse Codex's output into discrete feedback points. Then spawn one subagent per feedback point, all in parallel. Each subagent independently investigates whether Codex's claim is valid.

The subagent prompt for each point:

```
You are investigating a piece of feedback from an AI code reviewer (OpenAI Codex) to determine if it's valid.

**Feedback point #N:** <summary>
**File(s):** <file paths and lines referenced>
**Full detail:** <the complete feedback text for this point>

Instructions:
1. Read the file(s) and lines referenced. Read enough surrounding context to fully understand the code — callers, tests, related modules, type definitions.
2. Evaluate the feedback across three dimensions:

   **Correctness**: Is Codex's claim factually accurate? Does the code actually exhibit the described issue? Verify against the real code — do not take the reviewer's word at face value.

   **Optimality**: If a fix is suggested, is it the best approach? Is there a strictly better alternative?

   **Elegance**: Is the suggestion clean, maintainable, and consistent with the surrounding codebase style?

3. Return your verdict:
   - correctness: yes / partly / no — with evidence (file path + line)
   - optimality: yes / partly / no — explain why, suggest alternative if partly/no
   - elegance: yes / partly / no — explain why
   - action: one of:
     - "accept" — feedback is right, apply as suggested
     - "accept-modified" — feedback is right but a better fix exists (describe it)
     - "reject" — feedback is wrong or not worth acting on (explain why)
     - "discuss" — raises a real concern but needs a design decision from the user
   - suggested_fix: specific code changes if action is accept or accept-modified
   - files_to_modify: list of file paths that would need changes
```

Once all subagents return, compile the results into a summary table:

```
| # | Codex Feedback (summary) | Correct? | Optimal? | Elegant? | Action           |
|---|--------------------------|----------|----------|----------|------------------|
| 1 | ...                      | Yes      | Yes      | Yes      | Accept           |
| 2 | ...                      | Yes      | Partly   | No       | Accept-modified  |
| 3 | ...                      | No       | --       | --       | Reject           |
```

For "accept-modified" rows, show the alternative. For "reject" rows, provide a one-line rationale with evidence.

## Step 4: Implement accepted changes using parallel subagents

Group accepted changes by file independence — changes that touch different files can be implemented in parallel, changes to the same file must be sequential.

For each independent group, spawn a subagent:

```
Implement the following code change:

**Feedback point #N:** <summary>
**Action:** <accept or accept-modified>
**Fix to apply:** <the specific fix from the evaluation step>
**Files to modify:** <file list>

Instructions:
1. Read the target file(s) in full
2. Apply the fix precisely — change only what's needed
3. Verify the change doesn't break surrounding code
4. Report back: files modified, what changed, and any concerns
```

After all implementation subagents complete, collect what was changed:
- Which files were modified
- What specifically changed in each file
- Which feedback point each change addresses

## Step 5: Resume the Codex conversation for re-review

Use `codex exec resume --last` to continue the existing Codex conversation. This preserves the full transcript, plan history, and approvals from the initial review so Codex has complete context.

**Flag compatibility note**: `resume` does NOT support `--sandbox`, `-o`, or `-C`. These are only on the base `codex exec` subcommand. The session retains the sandbox mode and working directory from the initial `codex exec` call, so `--sandbox` and `-C` are not needed. For output capture, redirect stdout instead of using `-o`.

### 5a. Write the resume prompt file

Use the Write tool to create `/tmp/codex-prompt.txt`:

```
I have made the following changes based on your review:

<CHANGES>
[For each implemented change:]
- Point #N: [what was changed and in which file]
  [brief description of the fix]

[For each rejected point:]
- Point #N: REJECTED -- [reason with evidence]
</CHANGES>

Please re-review:
1. Run 'git diff' again to see the current state of all changes
2. Verify the fixes actually address the issues you raised
3. Check that the fixes didn't introduce new problems
4. Look for anything you missed in the first review

Same evaluation criteria: CORRECTNESS, OPTIMALITY, ELEGANCE.
End with a verdict: APPROVE, REQUEST CHANGES, or NEEDS DISCUSSION.
If REQUEST CHANGES, number each new requested change.
```

### 5b. Run Codex resume in the background

```bash
# run_in_background: true
codex exec resume --last - < /tmp/codex-prompt.txt > /tmp/codex-review-output.txt
```

Then use `TaskOutput(task_id=<id>, block=true, timeout=600000)` to wait for completion.

### 5c. Read the output

Use the Read tool to read `/tmp/codex-review-output.txt`.

## Step 6: Loop until done

Read the new Codex output from `/tmp/codex-review-output.txt`.

**If verdict is APPROVE**: Stop. Present the final summary to the user.

**If verdict is REQUEST CHANGES or NEEDS DISCUSSION**:
1. Go back to Step 3: spawn subagents to evaluate the new feedback points
2. Implement accepted changes via subagents (Step 4)
3. Resume the Codex conversation with the new change summary (Step 5)
4. Repeat

**Loop termination conditions** (stop if any are true):
- Codex returns APPROVE
- Codex has no new actionable feedback (only style nitpicks or opinions)

## Step 7: Present final results

When the loop terminates, present a complete summary:

---

**Codex Review — Final Results**

**Rounds**: [N] review iterations

**Changes implemented**:
- [list of all changes made across all rounds, with file paths]

**Feedback rejected** (with rationale):
- [list of Codex suggestions that were rejected and why]

**Final Codex Verdict**: [APPROVE / last verdict if loop hit termination]

---

## Guidelines

- Codex is a second opinion, not the final authority. The subagent evaluation is the filter.
- Never skip the feedback evaluation step. Every Codex claim must be verified against actual code before implementation.
- If Codex and Claude genuinely disagree on a point, present both perspectives to the user with evidence and let them decide.
- Keep prompts focused. Let Codex read files via its own tool use rather than dumping file contents into prompts.
- If `codex` is not installed or authentication fails, inform the user and suggest they install/configure it.
