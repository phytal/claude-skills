---
name: implementation-review
description: Thorough review of code changes for correctness, optimality, and elegance using parallel subagents. Use this skill whenever the user asks to review an implementation, audit recent changes, review a diff or PR, check code quality, or wants a second opinion on changes they or someone else made. Also trigger when the user says things like "review this", "how does this look", "check my changes", "audit this code", or "review the implementation" — even if they don't specify the axes explicitly.
---

# Implementation Review

You've been asked to review a set of code changes. Your job is to provide a thorough, structured review across three axes: **correctness**, **optimality**, and **elegance**. Each axis gets its own subagent so it receives deep, focused attention rather than a surface-level pass.

## Step 1: Identify the changes

Figure out what's being reviewed. The user might:
- Reference a PR or branch (`review PR #123`, `review my changes on feature-x`)
- Point to specific files (`review the changes in src/auth/`)
- Ask you to review recent work (`review what I just did`, `review the last commit`)
- Paste a diff directly

Use `git diff`, `git log`, `git show`, or file reads as needed to understand the full scope of changes. Identify all modified, added, and deleted files.

Before spawning subagents, build a brief **change summary** — a list of files changed and a 1-2 sentence description of what the changes accomplish overall. This gives each subagent the big picture so they don't waste time rediscovering it.

## Step 2: Spawn three review subagents in parallel

Launch one subagent per review axis, all at the same time. Each subagent receives the change summary and the list of files to review, then does its own deep investigation.

### Correctness subagent

```
You are reviewing code changes strictly for correctness.

**Change summary:** <summary>
**Files changed:** <file list>

Your job is to find bugs, logic errors, and incorrect behavior. For each file, read the changed code and enough surrounding context to understand the intent. Specifically look for:

- Logic errors: wrong conditions, off-by-one, incorrect operator, missing negation
- Data issues: type mismatches, null/undefined not handled, wrong data structure assumptions
- Concurrency/ordering: race conditions, missing locks, incorrect async/await usage
- API contract violations: wrong parameters, missing required fields, incorrect return types
- Edge cases: empty inputs, boundary values, error paths not handled
- Security: injection vectors, missing auth checks, exposed secrets, unsafe deserialization
- Integration: does the change break callers? Are migrations consistent with code? Do tests still make sense?

For each finding, report:
- severity: critical / warning / nit
- file: path and line range
- issue: what's wrong
- suggestion: how to fix it (be specific — include the corrected code if possible)

If you find nothing wrong, say so. Don't manufacture issues.
```

### Optimality subagent

```
You are reviewing code changes strictly for performance and efficiency.

**Change summary:** <summary>
**Files changed:** <file list>

Your job is to find performance problems and missed optimization opportunities. For each file, read the changed code and enough context to understand data flow and scale. Specifically look for:

- Algorithmic complexity: O(n²) where O(n) is possible, unnecessary nested loops, redundant traversals
- Database: N+1 queries, missing indexes implied by new query patterns, full table scans, unnecessary eager loading
- Memory: large allocations in hot paths, unbounded collections, missing pagination, leaking references
- I/O: synchronous calls that could be async, missing batching, redundant network round-trips
- Caching: opportunities for memoization, repeated expensive computations, cache invalidation issues
- Unnecessary work: dead code paths, over-fetching data, computing values that are never used

For each finding, report:
- severity: critical / warning / nit
- file: path and line range
- issue: what's suboptimal
- suggestion: the more efficient alternative (with code if applicable)
- impact: rough sense of when this matters (e.g., "only at >10k rows", "on every request")

Don't flag micro-optimizations that sacrifice readability for negligible gains. Focus on things that matter at realistic scale.
```

### Elegance subagent

```
You are reviewing code changes for elegance — clarity, maintainability, and design quality.

**Change summary:** <summary>
**Files changed:** <file list>

Your job is to assess whether the code is clean, well-structured, and easy to work with going forward. Specifically look for:

- Clarity: confusing names, misleading abstractions, code that requires comments to understand but has none, code that has comments but shouldn't need them
- Structure: functions doing too many things, tangled responsibilities, awkward control flow, deep nesting
- Consistency: does the new code match the style and patterns of the surrounding codebase? Does it follow the project's conventions?
- Duplication: copy-pasted logic that should be extracted, nearly-identical code paths that could be unified
- Abstraction: over-engineering (unnecessary indirection, premature generalization) or under-engineering (hardcoded values, magic strings, missing abstractions that would genuinely help)
- API design: are new interfaces intuitive? Would a future developer understand how to use them without reading the implementation?

For each finding, report:
- severity: critical / warning / nit
- file: path and line range
- issue: what could be cleaner
- suggestion: how to improve it (with code if applicable)

Respect the existing codebase style. Don't recommend wholesale rewrites or style changes that conflict with established patterns. Focus on the delta — is the new code pulling its weight?
```

## Step 3: Synthesize the results

Once all three subagents return, compile a unified review. Don't just concatenate — synthesize.

### Structure the output as:

**Overview**: 2-3 sentences on the overall quality of the changes. Be honest but not harsh.

**Critical findings** (if any): Issues that should be fixed before merging. Group related findings across axes if they overlap (e.g., a correctness bug that's also an elegance issue — present it once with both perspectives).

**Warnings**: Things worth addressing but not blocking.

**Nits**: Minor suggestions. Keep these brief — a one-liner each.

**Verdict**: One of:
- **Ship it** — changes look good, at most minor nits
- **Needs fixes** — has issues that should be addressed (list them)
- **Needs discussion** — has design-level concerns that need alignment before proceeding

### Deduplication

If multiple subagents flag the same thing from different angles, merge them into a single finding and note which axes it affects. Don't repeat the same issue three times.

### Applying fixes

After presenting the review, offer to auto-fix any findings the user agrees with. For critical and warning severity findings, suggest applying them. For nits, leave it to the user.
