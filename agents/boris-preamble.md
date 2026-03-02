# Boris Team Preamble

Read and internalize before starting any task.

## Karpathy Philosophy

### Coding
- **Software 2.0**: Don't hardcode complex logic. Let AI handle what AI handles best.
- **Minimalism**: "The best code is no code." No unnecessary abstractions. Minimal code, maximum effect.
- **Vibe Coding**: AI writes code, humans set direction and verify. No micromanaging internals.

### Agentic Engineering
- **Orchestrate, don't type**: You are one agent in a pipeline. Stay in your role. Don't do others' jobs.
- **Autonomy slider**: Follow your scope strictly. Escalate unknowns to team-lead, don't guess.
- **Generate-Verify loop**: Produce output, then verify. Never claim done without evidence.
- **Jagged intelligence**: LLMs ace hard tasks and fail easy ones. Double-check trivial assumptions.
- **Anterograde amnesia**: You forget between sessions. Write everything to handoff files. If it's not written down, it doesn't exist.

## Team Rules
- **English only**: All documents, comments, commit messages, and handoffs must be written in English.
- **Research before brute-force**: When stuck, search GitHub issues and Reddit for real-world solutions before forcing through. Don't guess — find evidence.

## Council Principle

> "Debates are always recorded. Previous debates are always referenced.
> Learn from failures and successes to move forward."

- Before any design or technical decision, check `.boris/councils/LEGEND.md` for related past debates
- If contradicting a previous consensus, explicitly state WHY the change is warranted
- All debate outputs (round files, CONSENSUS.md) MUST include `Created: YYYY-MM-DD HH:MM KST`
- Council records are institutional memory — never delete, only append

## Codex Hidden Card Protocol

When stuck on a problem after **2+ failed approaches**, consult Codex for a fresh perspective:

1. Write problem description to `.boris/codex-consult.md`:
   - What was tried
   - Why it failed
   - What constraints exist
2. Invoke Codex:
   ```bash
   codex exec -m gpt-5.3-codex --full-auto \
     -C /Users/dayum_gud/2ndbrain \
     "Read .boris/codex-consult.md. Provide alternative approaches.
      Do NOT write code — only describe strategies and reasoning."
   ```
3. Read Codex response and decide whether to adopt
4. Record consultation outcome via Secretary (SendMessage to lead)
5. Implement the chosen approach — **Claude ALWAYS writes all code**

**Key rules:**
- Codex ADVISES only — Claude WRITES all code
- Trigger threshold: 2+ failed approaches (not preemptive)
- If Codex is unavailable, proceed without it (no blocking)

## Cross-Model Verification

Testing and verification stages run independently on BOTH Claude and Codex:
- Neither model sees the other's output until both complete
- Discrepancies between models ARE the value — they reveal blind spots
- The Lead reconciles results into a unified report
- If Codex is unavailable, degrade gracefully to single-model (v1 behavior)
