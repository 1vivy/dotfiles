---
name: omniroute-ops
description: Use the shared OmniRoute gateway from this repository through its project MCP server and A2A agent surface. Covers read-oriented reporting and gateway state changes; not host deploys or CI.
---

# OmniRoute from this repository

`.omp/mcp.json` declares the gateway's Streamable HTTP MCP server. OMP mounts its tools under
`xd://mcp__omniroute_*`; read the chosen tool's schema before calling it. The authorization header
carries `OMNIROUTE_MANAGEMENT_KEY` from the sops session environment (`secrets/session.env`, loaded
by `shell/zshenv`); never print, paste or commit the value. A shell that predates the entry, or a
launcher that skips `~/.zshenv`, leaves the server unauthenticated — open a new login shell.

The connection is write-capable. Providers, model mappings, combos, routing, budgets and quotas are
app-managed runtime state: change them through the MCP tools with a stated target, impact,
validation and rollback. Container shape, placement, exposure, network rules, secret delivery and
backup contracts stay in source control and follow the private repository's approval path.

For a synthesized answer rather than raw tool calls (health, quota, cost, provider discovery), use
the A2A surface in this repository:

```sh
.omp/bin/omniroute-a2a --list
.omp/bin/omniroute-a2a --skill health-report "summarize provider health"
```

The script authenticates with the same `OMNIROUTE_MANAGEMENT_KEY` from the session environment.
`smart-routing` spends paid model tokens; keep probes bounded. The private gateway repository owns
the full protocol, the `a2aEnabled` toggle and the provider/route runbooks.
