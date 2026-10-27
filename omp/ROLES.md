# The Roles — OMP harness model routing

Configuration (omp 18.12.6). `config.yml` and `models.yml` are linked into `~/.omp/agent/`.
Git history here is the record of how seats moved.

## Seats

| Role | Model | Why |
|---|---|---|
| `default` | claude-opus-5-5 | OMO reference orchestrator. Fallback is Opus-refusal/outage only: gpt-6-sol:medium → gpt-5.6-sol:medium. Fable is skipped because the same cyber classifier refuses it. For a manual GPT main session, select `openai-codex/gpt-6.1-sol` directly (500K). |
| `plan` | claude-fable-5-1:xhigh | Scarce premium on a low-frequency, high-leverage seat (OMO Prometheus/Metis). Astra catches refusals. |
| `slow` | claude-fable-5-1:xhigh | Manual deep-think escalation (Ctrl-cycle) and advisor fallback. → gpt-6-astra:xhigh → gpt-6.1-sol:xhigh. |
| `oracle` | gpt-6-astra:high | Hard-reasoning/verdict lanes (OMO ultrabrain/deep-high, #8616). Lowered from xhigh 2026-09-29: Astra spent 1,205 output tokens/turn (73% hidden reasoning) vs Sol's 319; OMO deep-high followed 2026-10-01 (#9372). → gpt-6.1-sol:xhigh → claude-opus-5-5. 6.1 Sol stays behind Astra on verdict seats: it pushes past blocks in 23.5% of rollouts (Astra 17.4%) and misrepresents at 1.50% (Astra 0.51%). |
| `task` | gpt-6.1-sol:medium | Bundled `task` agent's planning seat. OMO deep-low leads with 6.1 Sol at medium (#9214): GPT-6 Sol's price, DeepSWE 75.2% at high vs GPT-6 Sol's 68.8% at max. `task.agentPrewalk.task` hands execution to `omni/opencode-go/deepseek-v4.1-flash:high` at the first eligible edit/write. → gpt-5.6-sol:medium → deepseek-flash:high. |
| `smol` | gpt-6.1-terra (no effort suffix) | Quick utility work, `sonic`, the Ctrl-cycle slot, and the fallback target of any `@smol` pattern. Moved off DeepSeek on 2026-10-27: Artificial Analysis puts Terra medium at TB4 32.3% in 209 s and 19K output tokens per task against DeepSeek V4.1 Flash 1017's 33.8% in 956 s and 218K. Pricing is $1/$5 per M, about 10x Haiku 5.5 and half Sonnet 5.5; Haiku 5.5 and DeepSeek Flash are the usual community picks for `smol` (omp docs example, standardcompute, james-carr.org). No suffix, so each agent keeps its own effort. Fallbacks (keyed on the exact model, so they cover the scout pin too): OpenCode Go DeepSeek low → Sonnet 5 low. Spell the Go id out; `deepseek/deepseek-flash:auto` resolved to an OpenRouter `~latest` route on atlas-agent without the DeepSeek prompt block. |
| `commit` | omni/opencode-go/deepseek-v4.1-flash:low | Commit messages. → deepseek/deepseek-flash:low → gpt-6-luna:low → sonnet-5:low. |
| `tiny` | omni/opencode-go/mimo-v2.6-flash | Session titles; `memory` follows it, but the backend is Hindsight. Chosen 2026-10-27 from opencode.ai/docs/go: $0.14/$0.28 per M, its own $60/mo bucket and 30,100 requests per 5 h on the $10 plan, no training, 0-day retention. A smoke title was good. Only fallback: `omni/openrouter/mistralai/mistral-nemo` ($0.029/$0.03 per M on OpenRouter's list). Left Codex (was gpt-6-luna:low). |
| `advisor` | claude-sonnet-5-5:high | Invoked manually by the owner. High matches Opus 5.5 medium on real-project coding scores at lower quota burn. → gpt-5.6-sol:medium → deepseek-flash:high. |
| `security` | gpt-daybreak-blue-latest:high | `security-reviewer`; Codex-only chain (Anthropic cyber refusals on RE work): → gpt-6-astra:high → gpt-6.1-sol:high → gpt-5.6-sol:high. Also usable for a manual main session after Anthropic refusals. 6.1 Sol's internal ExploitBench port is 21.5% vs 5.6 Sol's 3.5%. |
| `designer` | claude-sonnet-5-5:high | Sonnet 5.5's design strength at lower quota burn than Opus; low-traffic seat. |
| `vision` | gpt-5.6-sol:low | Off the Claude pool. → claude-sonnet-5-5:medium (chart reading 61.6% vs Sonnet 5's 15.6%) → deepseek-flash. |

Agent pins (`task.agentModelOverrides`): `scout` → gpt-6.1-terra:medium (2026-10-27: the pin sets the effort that `smol` leaves open; 78 scouts on DeepSeek low had a median wall time of 747 s, 30 turns and 29K output tokens); `reviewer` → claude-opus-5-5 → gpt-6-astra:xhigh until
the Claude 5x switch on Oct 8, then `@oracle`. `security-reviewer` → `@security` → `@oracle`.

The `omni` provider comes from the `omniroute-agent-extension` plugin (`omp plugin install
omniroute-agent-extension@3.2.3` per host). It takes `OMNIROUTE_URL`, `OMNIROUTE_API_KEY` and
`OMNIROUTE_AUTO_SYNC_INTERVAL_MINUTES` from the session environment (`shell/zshenv`, the key from
the dotfiles' `secrets/session.env`), so it needs no `config.json`. It syncs the `omni` models into
`~/.omp/agent/models.json` on session start and writes the key into that file's provider entry.

Agents: OMP's bundled set only. On 2026-10-24 a preflight error for an unknown agent listed `scout`, `reviewer`,
`security-reviewer`, `task` and `sonic`, plus `seance` from the omniroute plugin. There is no
`~/.omp/agent/agents` override directory. `sonic` runs on `@smol`; `scout` is pinned above.

On 2026-10-24 the custom agents (`sol-engineer`, `deepseek-worker`, `oracle`, and the `task` and
`scout` overrides) were removed. `sol-engineer` was taking delegations that the default lane
should get. The Sol-plans/Flash-executes default lane now uses OMP's own prewalk setting rather
than agent frontmatter. Work that must stay on Sol or Astra past the first edit passes `model`
per task. Start a fresh OMP session to refresh the advertised agent list. On other hosts, delete
the dangling `~/.omp/agent/agents` symlink after pulling.

## Context ceilings

On 2026-10-11 OpenAI raised GPT-6.1 Sol's default context in Codex and Work from 272K to 500K
([Tibo](https://x.com/thsottiaux/status/2109430343346581527)). OMP's catalog lists 500K for
`gpt-6.1-sol`; `models.yml` sets every other Codex model used here (`gpt-6-astra`, `gpt-6-sol`,
`gpt-6-luna`, `gpt-5.6-sol`, `gpt-daybreak-blue-latest`) to the same 500K. Only 6.1 Sol's 500K is
announced; the others are owner-directed. Subscription usage has no long-context fee
([forum recap](https://community.openai.com/t/28-days-of-shipping-at-openai/1403897)); the old
>272K surcharge (2x input/cache, 1.5x output) applies to API billing, which these seats do not use.

The separate `codex-main/gpt-6.1-sol` 600K identity was removed on 2026-10-24: the native
`openai-codex/gpt-6.1-sol` now has 500K. Select it directly (`omp --model openai-codex/gpt-6.1-sol`).

## Subscription balance

- Anthropic (20x until Oct 8, then 5x): default, plan, slow, reviewer, advisor, designer.
- Codex (Pro 20x): oracle, task planning, security, smol (including scout at medium), vision, and every refusal fallback.
- OpenCode Go ($10/mo; each model has its own monthly bucket, 20% per 5 h and 50% per week, per opencode.ai/docs/go on 2026-10-27; DeepSeek V4.1 Flash $80, MiMo-V2.6-Flash $60): commit, tiny, task execution after prewalk, and the first smol fallback.
- OpenRouter through OmniRoute (metered): the only tiny fallback.
- DeepSeek (metered, off-peak 0.5x): overflow when Go windows are exhausted; designer/vision/commit/task fallbacks.

Deferred to Oct 8: `reviewer` → `@oracle`.

## Grounding

OMO `docs/guide/agent-model-matching.md` history (Jul–Oct 2026): Opus sweep to 5.5
(`5c705853b`), Opus catch-all at medium (#8728), Luna → GPT-6 Luna (#8701), deep-low
GPT-6 Sol reverted to 5.6 Sol (#8885), Astra removed from catch-all (#8616), DeepSeek
V4.1 Flash as the fast rung after Luna (`2ca3be252`), deep-low → GPT-6.1 Sol (#9214),
deep-high Astra xhigh → high (#9372).

Selection criteria and how they map onto these seats: `omo-model-criteria.md`.

## Git workflow and OMO separation (2026-09-29)

- `task.isolation.merge: branch`. Patch mode (the default) replays an isolated child's diff into
  the parent as uncommitted changes and drops its commits; branch mode lands them as commits.
  Smoke: a child commit came back as a commit on a clean tree. OMP re-creates the commit on
  merge, and the re-created commit is unsigned (`%G?` = `N`; the child's own commit was `G`).
- Related workflow, firmware and OMO skills were deleted in the lab-habit reset, including
  restorable copies. Use current project guidance rather than archived skill recipes.

## DeepSeek system prompt

`~/.omp/agent/SYSTEM_TEMPLATE.md` is generated by `prompts/build-system-template.py`. For the
models in `DEEPSEEK_MODELS` it renders `prompts/deepseek-block0.hbs` as block 0; for every other
model it renders OMP's bundled block 0 byte-for-byte (`prompts/upstream-system-prompt.md`,
vendored per release). OMP re-renders block 0 on every model change, so the default task gets
the DeepSeek block from the prewalk handoff on, with the same tools Sol had.

- Rebuild after editing the block or upgrading OMP: `python3 prompts/build-system-template.py`.
  It refuses to build when the bundled template changed upstream; review the printed diff,
  then rerun with `--accept-upstream`.
- Requires `includeModelInPrompt: true` (the default): the branch keys on the rendered model id.
- Each rule answers a measured failure: DS was blocked 12.7% of bash calls for shell substitutes
  (Sol 0.3%), wrote 367 "wait/Hmm" markers per 100 turns (Sol 1.6), ran a 7.5-turn median tail
  after its last edit, and the web record shows unbounded post-edit verification, announce-then-
  stop, and fake tool calls. OMO ships V4.1 Flash with no extra rules (DSH Minimal 90.6 vs
  Standard 85.8 on Terminal-Bench 2.1), so the block replaces prose instead of adding to it:
  5.1K rendered chars for a production worker vs 8.1K bundled.
- Verified: the render test across scout/task/main contexts, a fresh `omp -p` scout
  (block present), and an RPC prewalk session whose block 0 switched from the bundled text to
  the DeepSeek block after handoff.

The bundled `task` prompt carries no handoff contract. The former `agents/task.md` contract
(investigation finished before the first edit; the brief's verification ownership ranks above the
post-handoff checklist) was removed with the custom agents. Put interfaces, acceptance checks and
verification ownership in the task brief.

## Skills and memory

- Project skills live in the owning repo at `.agents/skills/` and are committed there, so new
  worktrees and isolated children see them: borrrk-infra (13), gbl_root_canoe (13),
  canoe-boot-manager (4), and one each in canoe-msd, canoe-uefi-handoff, ota_fw_audit,
  ROMs/camera-port, pc-setup, moodle-bridge. Non-git homes: `~/Projects/edl-re`,
  `~/Games/NEFARAM-CS-Lab`, `~/Games/NEFARAM`. Discovery stops at the git root, so a skill is
  visible only inside its repo (existing worktrees see it after rebasing onto the commit).
- Cross-project skills live in `~/.agents/skills/`. `~/.omp/agent/managed-skills/` is empty.
- `autolearn.enabled: false`: auto-minted skills froze wrong patterns (never-commit, squash
  doctrine, OMO tool names, removed code paths). A new skill is written only when the owner
  asks, into the owning repo, and reviewed like code.
- Hindsight carries automatic memory: `hindsight.mentalModelsEnabled: true`
  (`mentalModelMaxRenderChars: 5000`), with bank and retain missions that prefer newer facts and
  mark conflicting older ones superseded.

## Open items

- `contextPromotion.enabled` is a Kimi leftover with no promotion target (zero promotions observed).
- Prewalk handoff triggers (09-29 transcripts): `write agent://…` hands off; `write xd://…` does not;
  `local://` not yet observed.
- Prewalk audit (123 engineer lanes, 10-03..10-07): Sol planned for a median 88 s; 73 handed off
  with open investigation items, and Flash then read a median 9 files Sol had not. OMP's post-handoff
  checklist ("run the full test module") contradicts the 74 briefs that leave tests to the parent;
  Flash's first turn argued it in 70 lanes and 14 ran gates anyway. With the bundled `task`
  prompt, these failure modes have no mitigation; check for them in task transcripts.
- Prewalk switches only on an `edit`/`write` after the child has called `todo` (18.12.6 gate). A
  child whose first action was `write` and that never wrote again stayed on Sol to the end (2026-10-24 smoke).
- Branch-mode isolation re-creates child commits unsigned; re-sign before pushing.
- `judge` resolves to `typesafe/jev-latest` (TypeSafe login, no config key), which turns on `find`,
  the auto thinking-level classifier, and stop detection. `find` sends code excerpts to TypeSafe.
- `gpt-6.1-sol` (task planning since 2026-10-02) has no local latency or turns-per-task data yet
  (`omo-model-criteria.md` R3/R4); measure it from task transcripts.
- `scout` on Terra medium has no A/B against DeepSeek low yet. Run one brief on each and compare wall time, turns and tool-call failures before trusting the 4.6x per-task figure (2026-10-27). Terra scouts and `sonic` get OMP's bundled block 0, not the DeepSeek block; `sonic` has no measurements on Terra.
