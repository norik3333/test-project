# Context Engineering

> Based on: Anthropic "Effective Context Engineering for AI Agents" (2025)
> Core principle: Find the minimal set of high-signal tokens that maximizes
> the probability of a desired outcome within a limited attention budget.

## The Right Altitude

System prompts and instructions must avoid two failure modes:

| Failure | Symptom | Fix |
|---------|---------|-----|
| Over-specific | Brittle if-else logic hardcoded | Use strong heuristics, not exact scripts |
| Over-abstract | Vague, high-level guidance | Add concrete examples and decision criteria |

Start with the minimum necessary information. Add detail only when testing reveals a failure mode.

## Just-in-Time Context (JIT)

Do NOT front-load entire files, schemas, or docs into context.
Instead, keep lightweight identifiers and load dynamically:

```
WRONG:  Read all 50 source files into context before starting
RIGHT:  Use glob/grep to locate relevant files, read only what's needed
```

- Use `glob` and `grep` for on-demand file discovery
- Use `git log`/`git blame` for history — don't memorize it
- Maintain pointers (file paths, URLs, query strings) not payloads
- CLAUDE.md provides pre-loaded context; everything else is JIT

## Progressive Disclosure

Let agents discover context layer by layer:

1. **File names and sizes** — infer complexity and purpose
2. **Directory structure** — understand architecture
3. **Specific file sections** — read only relevant parts
4. **Full file content** — only when necessary

Never read an entire large file when `offset`/`limit` or grep can narrow the scope.

## Compaction

When context grows large, preserve high-signal information and discard noise.

### What to preserve
- Architectural decisions and rationale
- Unresolved bugs and blockers
- Implementation constraints and dependencies
- Current task state and progress

### What to discard
- Redundant tool output (same file read multiple times)
- Verbose error traces after the root cause is identified
- Intermediate exploration that led to dead ends
- Repeated messages and confirmations

### Tool result clearing
The safest compaction: old tool results deep in message history rarely need re-reading.
Prefer summarizing findings immediately after tool calls rather than relying on raw output later.

## Sub-agent Context Discipline

Sub-agents explore extensively but return concisely:

```
Sub-agent work:   30,000+ tokens of exploration (grep, read, analysis)
Sub-agent return: 1,000-2,000 tokens of distilled findings
```

Rules for sub-agents:
- Include concrete file paths and line numbers in findings
- Summarize patterns, not raw data
- Flag decisions that need the parent agent's judgment
- Never return raw tool output — always distill

## Tool Design Principles

- **Self-contained**: Each tool does one thing well
- **Token-efficient**: Return minimal useful output
- **Unambiguous**: If a human can't tell which tool to use, neither can the model
- **No overlap**: Minimize functional duplication between tools

## Memory vs Context

| Use memory for | Use context for |
|----------------|-----------------|
| Cross-session knowledge | Current task state |
| User preferences and feedback | Active file contents |
| Project decisions and rationale | Tool call results |
| Reference pointers (URLs, paths) | Intermediate computation |

Memory is for information that future sessions need.
Context is for information that the current turn needs.

## Anti-patterns

- Dumping entire codebases into context "just in case"
- Long lists of edge cases in system prompts (use examples instead)
- Fat tool sets with overlapping functionality
- Reading files that were already read earlier in the conversation
- Returning verbose sub-agent results instead of distilled summaries
