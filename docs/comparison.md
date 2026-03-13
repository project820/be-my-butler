# BMB vs Other Tools

An honest comparison of BMB against other AI coding tools. Every tool has trade-offs -- this page helps you decide if BMB fits your workflow.

---

## Feature Matrix

| Capability | BMB | Aider | Composio | opencode |
|---|---|---|---|---|
| Multi-agent orchestration | 9 specialized agents | Single agent | Depends on integration | Single agent |
| Cross-model verification | Blind divergent protocol | No | No | No |
| Council debate | Multi-round adversarial | No | No | No |
| Worktree isolation | Per-agent git worktrees | No | N/A | No |
| Auto-learning | 3-tier (project, global, CLAUDE.md) | No | No | No |
| Context compression | 3-layer (L1/L2/L3) | Repo map | N/A | No |
| Session continuity | session-prep.md | Chat history | N/A | Chat history |
| Pipeline analytics | Bird's Law severity, pattern promotion | No | No | No |
| Live library docs | Context7 MCP integration | No | N/A | No |
| Recipe system | 6 recipes | N/A | N/A | N/A |
| tmux required | Yes | No | No | No |
| Claude Code dependency | Yes | No (any LLM) | No | No |
| Setup complexity | Medium | Low | Medium | Low |
| Token cost per task | High (multi-agent) | Low (single agent) | Varies | Low |

---

## BMB vs Aider

[Aider](https://aider.chat) is a terminal-based pair programming tool that works with many LLM providers.

**Where Aider wins:**
- Works with any LLM provider (OpenAI, Anthropic, local models)
- Zero setup -- `pip install aider-chat` and go
- Lower token cost per task (single agent, single pass)
- Great for quick edits and iterative pair programming
- Active open-source community with frequent releases

**Where BMB wins:**
- Multi-agent verification catches bugs that self-review misses
- Cross-model blind review eliminates single-model bias
- Council debate prevents architectural mistakes before code is written
- Worktree isolation enables parallel execution without conflicts
- Auto-learning accumulates project-specific rules over time
- Session continuity preserves context across conversations
- Analytics layer with Bird's Law severity tracking identifies recurring failure patterns
- Consultant Coordinator model provides dual-channel user advisory + pipeline monitoring

**Choose Aider when:** You want fast, interactive pair programming with minimal overhead. Tasks are small and well-defined. You trust a single model's output with your own review.

**Choose BMB when:** You are building something where correctness matters more than speed. The task is complex enough that a single pass is likely to miss edge cases. You want systematic verification before merging.

---

## BMB vs Composio

[Composio](https://composio.dev) is an integration framework that connects AI agents to external tools and APIs.

**Where Composio wins:**
- Integrates with 200+ external services (GitHub, Slack, Jira, etc.)
- Provider-agnostic -- works with any agent framework
- Strong API integration layer
- Good for building custom agentic workflows

**Where BMB wins:**
- Purpose-built for code quality, not general integration
- Deep Claude Code integration (agents, skills, tmux orchestration)
- Verification pipeline with blind cross-model review
- No external API dependencies for core functionality
- Simpler mental model: 11.5 steps, 9 agents, done
- Built-in analytics and observability for pipeline health

**Choose Composio when:** You need AI agents that interact with external services. Your workflow involves API calls, ticket management, or multi-service orchestration.

**Choose BMB when:** Your primary goal is writing and verifying code. You want a structured pipeline rather than a custom agent framework.

---

## BMB vs opencode

[opencode](https://github.com/opencode-ai/opencode) is a TUI (terminal UI) wrapper for AI coding assistants.

**Where opencode wins:**
- Polished terminal UI with file browser and diff viewer
- Lower complexity -- no tmux, no multi-agent coordination
- Works with multiple LLM providers
- Good for single-file edits and exploration

**Where BMB wins:**
- Multi-agent pipeline with specialized roles
- Cross-model blind verification
- Worktree isolation for parallel work
- Auto-learning and knowledge indexing
- Structured recipes for different task types

**Choose opencode when:** You want a better terminal experience for AI-assisted coding. Tasks are straightforward and do not need multi-step verification.

**Choose BMB when:** You need a full pipeline from brainstorming through verification. You want multiple agents challenging each other's work.

---

## Honest Limitations

BMB is not the right tool for every situation. Here are its real costs:

### Token Cost

BMB runs multiple Claude instances (9 agents) plus optional cross-model calls. A full `feature` pipeline costs 150k-400k tokens. A simple `research` run is 20k-60k. For comparison, a single Aider edit might cost 5k-20k tokens.

**Mitigation:** Choose lighter recipes (`bugfix`, `infra`) for simpler tasks. The 3-layer compression system reduces waste, but multi-agent orchestration is inherently more expensive than single-agent.

### Complexity

BMB requires tmux, git, python3, sqlite3, and Claude Code. Cross-model verification adds Codex or Gemini CLI. This is more setup than a simple `pip install`.

**Mitigation:** `bmb doctor` verifies all dependencies. `/BMB-setup` generates configuration. The install script handles most setup automatically.

### Claude Code Dependency

BMB is built specifically for Claude Code's agent system. It does not work with other LLM CLIs (Aider, Continue, Cursor) as the orchestration layer. If Anthropic changes Claude Code's agent API, BMB needs to adapt.

### tmux Requirement

The entire pipeline runs inside tmux. If you are not comfortable with tmux or your environment does not support it (some cloud IDEs, Windows without WSL), BMB will not work.

### Latency

A full 11.5-step pipeline takes 10-30 minutes depending on task complexity and timeouts. This is appropriate for features that would take a human developer hours, but overkill for a one-line fix.

**Mitigation:** Use `bugfix` recipe (5-10 min) for small fixes. Use `research` recipe (2-5 min) for exploration only.

### Learning Curve

Understanding 9 agents, 11.5 steps, and 6 recipes takes time. The handoff file system, worktree lifecycle, and blind verification protocol all have specific rules.

**Mitigation:** Start with `research` recipe to learn brainstorming. Graduate to `bugfix` for a short pipeline. Use `feature` once comfortable.

---

## When to Use BMB

| Scenario | Recommendation |
|----------|----------------|
| Quick one-line fix | Do not use BMB. Edit directly. |
| Small bug with known cause | `bugfix` recipe or skip BMB |
| Feature with multiple files | `feature` recipe |
| Refactoring a module | `refactor` recipe |
| Evaluating a technology choice | `research` recipe |
| Security-sensitive changes | `feature` recipe (cross-model verification adds confidence) |
| Prototype / throwaway code | Do not use BMB. Speed matters more than correctness. |
| Production code that must be right | BMB's sweet spot |
