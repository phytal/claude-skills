---
name: feedback-review
description: >
  Analyze feedback on code from any source — teammate PR reviews, AI-generated
  flags, implementation review findings, or pasted critique — and vet each point
  for correctness, optimality, and elegance before acting on it. Uses parallel
  subagents for thorough investigation. Triggers on phrases like "got this feedback",
  "teammate review", "review comments", "PR feedback", "address these findings",
  "handle this review", or when the user pastes numbered/bulleted critique, flag
  output, or structured review results.
---

# Feedback Review

Analyze feedback point-by-point using parallel subagents, then implement accepted changes.

## Step 1: Parse the feedback

Feedback can arrive in different formats. Normalize it into discrete points:

- **GitHub PR**: Fetch comments with `gh api repos/{owner}/{repo}/pulls/{number}/comments` and the PR review body with `gh pr view {number}`.
- **AI flags** (from flag-review or similar): Each flag is one point. The title is the summary, the description has the details.
- **Structured review** (from implementation-review or similar): Each finding is one point, already tagged with severity and axis.
- **Pasted text**: Parse into discrete points — one per bullet, paragraph, or numbered item.

For each point, extract:
- A short summary of the claim or suggestion
- The file(s) and line(s) referenced (if any)
- The source (teammate name, tool name, or "anonymous")

## Step 2: Dispatch subagents for investigation

Spawn one subagent per feedback point, all in parallel. Each subagent investigates a single point independently against the actual codebase.

The subagent prompt:

```
You are investigating a piece of feedback to determine if it's valid and worth acting on.

**Feedback point:** <summary>
**File(s):** <file paths and lines, if any>
**Full detail:** <the complete feedback text for this point>
**Source:** <who/what generated this feedback>

Instructions:
1. Read the file(s) and lines referenced. Read enough surrounding context to fully understand the code — callers, tests, related modules.
2. Evaluate the feedback across three dimensions:

   **Correctness**: Is the claim factually accurate? Does the code actually exhibit the described issue? Verify against the real code — do not take the reviewer's word at face value.

   **Optimality**: If a fix is suggested, is it the best approach? Is there a strictly better alternative? If no fix is suggested, what would the optimal fix look like?

   **Elegance**: Is the suggestion clean, maintainable, and consistent with the surrounding codebase style? Would the change make the code better or worse to work with?

3. Return your verdict:
   - correctness: yes / partly / no — with evidence (file path + line)
   - optimality: yes / partly / no — explain why, suggest alternative if partly/no
   - elegance: yes / partly / no — explain why
   - action: one of:
     - "accept" — feedback is right, apply as suggested
     - "accept-modified" — feedback is right but a better fix exists (describe it)
     - "push-back" — feedback is wrong or not worth acting on (explain why)
     - "discuss" — feedback raises a real concern but the right fix involves a design decision
   - suggested_fix: specific code changes if action is accept or accept-modified (empty otherwise)
```

## Step 3: Synthesize and present

Once all subagents return, compile the results into a summary table:

```
| # | Point (short summary) | Correct? | Optimal? | Elegant? | Action           |
|---|----------------------|----------|----------|----------|------------------|
| 1 | ...                  | Yes      | Yes      | Yes      | Accept           |
| 2 | ...                  | Yes      | Partly   | No       | Accept-modified  |
| 3 | ...                  | No       | --       | --       | Push back        |
| 4 | ...                  | Yes      | Yes      | Partly   | Discuss          |
```

Below the table, for each non-trivial verdict:
- **Accept-modified**: Briefly describe the better alternative
- **Push back**: Provide a clear rationale with code evidence
- **Discuss**: Frame the design question and present options

## Step 4: Implement

After presenting the summary, ask the user which points to act on (default: all accepted + accept-modified). Then make the code changes.

For "discuss" items, wait for the user's decision before proceeding.

## Guidelines

- Verify every claim against the actual code. Read the exact lines referenced — never evaluate from memory alone.
- If a point is partially right, acknowledge what's correct and what isn't.
- Avoid sycophancy. Reviewers — human or AI — can be wrong. Say so plainly with evidence.
- When the feedback source is an AI tool, be especially skeptical of theoretical concerns that the code already handles.
- When the feedback source is a teammate, pay extra attention to implicit context they might have (domain knowledge, past incidents, team conventions) that isn't visible in the code.
