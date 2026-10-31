# OMO model viability and suitability criteria

Distilled from oh-my-openagent `origin/dev` @ `4d561ab6d` (2026-09-29), refreshed at
`10c6c7fb7` (fetched 2026-10-02). The local clone's working tree at `~/Projects/oh-my-openagent`
is ~7.7k commits behind (still Opus 5 / GPT-5.6-only). Read upstream with
`git -C ~/Projects/oh-my-openagent show origin/dev:<path>`, never the working tree.

OMO publishes no numeric weights. Ranks below come from the "always/never" language in the
docs, the policy tests that pin the chains, and how conflicts actually get settled in
routing commits. The numeric weights in the final section are our own translation for
scoring OMP seats. They are not OMO data.

## Update: 2026-10-31

The [current guide](https://github.com/code-yeongyu/oh-my-openagent/blob/f34f5f130f1198a2c6d30ee9597a75edbf57acbe/docs/guide/agent-model-matching.md)
now leads Daily Normal with Opus 5.5 medium, then Kimi K3.1 Pro and GLM 5.3. Obsessive
Normal leads with Astra medium, then GPT-6.1 Sol Fast, GPT-6.1 Sol and GPT-5.6 Sol at medium.
Deep-low remains GPT-6.1 Sol medium; deep-high remains Astra high. Quick adds Haiku 5.5
medium before DeepSeek direct. Visual engineering and writing lead with Gemini 4 Argon low,
conditional on catalog support. Fable 5.5 is explicitly unreleased and launch-gated.

The sections below record the earlier revision, not the current ladders. OMO recommendations do
not prove that an OMP provider serves a model, that its quota is available, or that OMP uses
OMO's model-specific prompt.

## Sources

| What | Where (origin/dev) |
|---|---|
| Criteria prose, supported set, safe/risky overrides, scarce-quota placement | `docs/guide/agent-model-matching.md` |
| Agent chains (canonical) | `packages/model-core/src/agent-model-requirements.ts` |
| Category chains (canonical) | `packages/model-core/src/category-model-requirements.ts` |
| Chain schema (`variant`, `requiresModel`, `requiresAnyModel`, `requiresProvider`) | `packages/model-core/src/model-requirement-types.ts` |
| Global invariants | `packages/model-core/src/model-requirements-invariants.test.ts` |
| Lane-separation policy | `packages/model-core/src/category-routing-policy.test.ts` |
| Fast-rung policy (Luna → DeepSeek) | `packages/model-core/src/luna-deepseek-chain-policy.test.ts` |
| Runtime fallback: only `quota_exceeded` exhausts a provider | `packages/model-core/src/provider-exhaustion-fallback-policy.ts`, `runtime-fallback-error-classifier.ts` |
| Main-agent supported ladder | `packages/omo-senpi/src/components/model-profile/builtin-profiles.ts` |
| OmO Native mirror (subscription-first provider order) | `packages/senpi-task/src/{agents/builtin,category}/fallback-chains.ts` |

## Criteria, ranked

| Rank | Criterion | Rule | Evidence |
|---|---|---|---|
| 1 | **Family / prompt-style fit** | Claude and Claude-like models (Kimi K3, GLM) follow mechanics-heavy prompts: long checklists and nested todos. GPT follows principle-driven prompts: goal plus decision criteria, where more rules means more drift. Only fill a role from the family its prompt was written for. "A prompt cannot fix a model." | GPT-only: `ultrabrain`, `deep-low`, `deep-high`, hephaestus (`requiresProvider` GPT lanes). Claude-led: prometheus, metis, `visual-engineering`, `artistry`, `writing` (Claude-only; the lane disappears rather than borrow GPT). |
| 2 | **Maintainer verification** | A model counts as supported only if it has a tuned prompt preset and sits on the ladder. Off-ladder models "can break at the very next patch" and don't count as bugs when they do. | Main-agent ladder: `opus-5-5 medium → fable-5-1 xhigh → kimi-k3 max → gpt-6-astra xhigh → gpt-6.1-sol medium → gpt-6-sol medium → glm-5.3 max`. GLM is last: "less maintainer validation on nested todo, delegation, long-context paths". MiniMax/Qwen/MiMo/DeepSeek as orchestrator: "just don't". |
| 3 | **Role frequency × leverage vs scarce quota** | Spend the scarcest premium model on low-frequency, high-leverage seats (plan gap-analysis, plan review, hard verdicts). Never put it on continuous orchestration, execution, search or retrieval. | #8616 removed Astra from the `unspecified-high` catch-all ("most expensive lane the default for ordinary work"). #8526 split `deep` because nearly every task landed on Astra. Scarce Fable goes to Metis. |
| 4 | **Reasoning effort matched to decision difficulty** | The variant is part of the model choice. De-escalate when effort buys nothing but cost. | quick = Luna-fast `low`; explore/librarian = Kimi HighSpeed `off`; deep-low = 6.1 Sol `medium`; deep-high = Astra `high` (owner cut it from `xhigh`, #9372); ultrabrain = Astra `max`. Momus was cut from Sol xhigh after "runaway recursive subagent spawning and huge cost". `unspecified-high` Opus went max → medium (#8728). Writing uses `low`. |
| 5 | **Speed and throughput for utility roles** | Search and retrieval need speed, not intelligence. Opus or Fable on explore/librarian is "massive cost waste". | Search agents are headed by Kimi HighSpeed (`off`), then GPT-6 Luna-fast, then DeepSeek V4.1 Flash (`deepseek-flash`, `max`); `quick` runs Luna-fast `low` → DeepSeek `off`. |
| 6 | **Provider availability / redundancy** | Every rung lists every provider that serves the model. Provider order inside a rung is the ranking: subscription before metered (#8051), chatgpt-subscription before openai (#8300/#8734). A lane with no resolvable rung is reported, not silently re-routed to another family. | `isCategoryChainViable` in `senpi-task/src/category/builtins.ts`. Single-rung lanes deliberately fail rather than degrade: "a `deep-low` budget must not silently become an Astra bill" (#8526). |
| 7 | **Long-context / nested-workflow coherence** | This is folded into ranks 1–2. Claude Opus 5.5 and Fable 5.1 are "the reference configuration for the orchestration prompt"; GLM is "slightly looser on long nested workflows". | Ladder ordering. |
| 8 | **Vision** | Applies to one role only. | multimodal-looker: `gpt-5.6-sol low → kimi-k3 → glm-4.6v → gpt-5-nano` (pinned by test). |
| 9 | **Canonical ids / generation freshness** | Hard hygiene rule: requirement ids must be canonical and backed by the models.dev snapshot, and generations get swept quickly. | Invariants: no `gpt-5.5` rung; no retired Kimi K2 ids; no `/` in ids; no Haiku or nano routed through `opencode`. |
| — | **Refusal / cyber behaviour** | **Not a selection criterion in OMO.** It is only handled at runtime: pinned-model refusal falls through inside the turn (#9114). The error classifier has no refusal class. | Grep of chains and docs finds none. |

**How conflicts resolve:**
- Family fit and verification beat the quota rule. A lane is never filled from the wrong family: hephaestus stays GPT-only even on a Claude-only machine, and `writing` vanishes rather than borrow GPT.
- The quota rule beats raw capability: #8616, #8526 and the Momus de-escalation.
- Provider redundancy only ever widens a lane; it never crosses families.
- For utility roles, speed beats family fit: Haiku is allowed, Opus and Fable are banned.

## Role chains at origin/dev

| OMO role | Primary | Chain |
|---|---|---|
| sisyphus (orchestrator) | opus-5-5 max | → kimi-k3 → gpt-5.6-sol medium → glm-5.2 → big-pickle |
| hephaestus (deep autonomous) | gpt-6-sol medium | → gpt-5.6-sol medium (GPT providers only) |
| oracle | gpt-5.6-sol xhigh | → sol high (copilot) → gemini-3.1-pro high → opus-5-5 max → glm-5.2 |
| prometheus (planner) | fable-5-1 xhigh | → opus-5-5 max → kimi-k3 max |
| metis (plan gap analysis) | fable-5-1 max | → opus-5-5 max → kimi-k3 max |
| momus (plan reviewer) | gpt-6-astra xhigh | → astra high (copilot) → opus-5-5 max → gemini-3.1-pro high → glm-5.2 |
| atlas / sisyphus-junior | sonnet-5 | → kimi-k3 → gpt-5.6-sol medium → minimax-m3 → minimax-m2.7 |
| explore / librarian | kimi-for-coding-highspeed off | → gpt-6-luna-fast low → deepseek-flash max → qwen3.7-plus → minimax-m2.7 → haiku-4-5 |
| multimodal-looker | gpt-5.6-sol low | → kimi-k3 → glm-4.6v → gpt-5-nano |

| Category | Chain |
|---|---|
| `ultrabrain` | astra max → sol max |
| `deep-high` | astra high **only** |
| `deep-low` | gpt-6.1-sol medium → gpt-6.1-sol-fast medium → gpt-5.6-sol medium → gpt-5.6-sol-fast medium |
| `visual-engineering` / `artistry` | fable-5-1 max → opus-5-5 max → kimi-k3 max |
| `unspecified-high` | opus-5-5 medium → glm-5.3 max → kimi-k3 max |
| `unspecified-low` | sonnet-5-5 medium → mimo-v2.6-pro max → grok-4.7 xhigh → gpt-5.6-terra high → sonnet-5 low → … |
| `quick` | gpt-6-luna-fast low → deepseek-flash off → qwen3.6-flash low → minimax → grok non-reasoning → haiku → glm-5.3-flash / mimo-v2.6-flash low (Z.ai- or Xiaomi-only machines, #9202) |
| `writing` | opus-5-5 low → opus-4-6 max (Claude-only) |

### GPT-6 Sol vs GPT-5.6 Sol (Sep 22–26)

GPT-6 Sol was adopted on 9-22/23: Hephaestus (#8687), deep-low (#8701), a
gpt-6-sol-fast head rung (#8714), and GPT-5.6 dropped from deep-low entirely (#8718).
Most of that was rolled back by 9-26: Geeky·Normal went to `gpt-5.6-sol` medium (#8807),
and deep-low went to `gpt-5.6-sol-fast → gpt-5.6-sol` medium, with GPT-6-Sol-only
registries now locked out (#8885, shipped in v5.0.0). The maintainer's issues state the
target state but no reason for the reversal.

At dev, GPT-6 Sol remains only at the Hephaestus head and as rung 6 of the main-agent
ladder, behind GPT-6.1 Sol. The oracle, multimodal-looker, ultrabrain-fallback and
Atlas/Junior-fallback Sol rungs are GPT-5.6; deep-low now leads with GPT-6.1 Sol.

### GPT-6.1 Sol (Sep 29 – Oct 1)

OpenAI shipped GPT-6.1 Sol on 9-29/30 at GPT-6 Sol's price ($2/$10 per M; cached input halved
to $0.10) with near-Astra scores: DeepSWE v1.1 75.2% at high vs GPT-6 Sol's 68.8% at max;
OSWorld 2.0 71.4% vs Astra's 73.5%. OMO adopted it within two days: deep-low head at medium
(#9214), main-agent ladder rung 5 ahead of GPT-6 Sol (`16f3b5733`), and the Geeky · Normal
head as `gpt-6.1-sol-fast` (#9214, #9372). Only the ChatGPT subscription and the OpenAI API
serve it, so Copilot and OpenCode lanes fall through to GPT-5.6 Sol; GPT-6 Sol stays out of
deep-low. The same batch moved deep-high and Geeky · Heavy from Astra `xhigh` to `high` on the
owner's call, with no measurement cited (#9372). Agent chains (hephaestus, oracle, momus,
multimodal-looker) did not change.

OMO's capability snapshot gives 6.1 Sol 400K context, 128K output, and efforts low..max
(`none`/`minimal` downgrade to low, as on Astra); OMP's catalog lists 272K. The system-card
addendum shows what OMO's criteria don't weigh: unwanted persistence after a block in 23.5% of
rollouts (Astra 17.4%), misrepresentation 1.50% (Astra 0.51%, GPT-6 Sol 1.30%), and more
reward-hacking and concealed-uncertainty flags than Astra.

## Mapping to OMP seats

| OMP seat (`config.yml`) | OMO analogue | Criteria that decide it |
|---|---|---|
| `default` | sisyphus | 1, 2, 7: supported ladder only |
| `plan` | prometheus / metis | 3: scarce premium belongs here |
| `oracle` | oracle / momus / `ultrabrain` | 1 (GPT), 3, 4 |
| `task` → bundled `task` agent (plans; prewalk hands execution to Flash) | hephaestus / `deep-low` | 1 (GPT only), 4 (medium) |
| `slow` → `reviewer` | momus | 1 (GPT), 4 |
| `smol`, `commit`, `scout`, `sonic`, prewalk target | explore / librarian / `quick` | 5, 4: `off`/`low` effort |
| `tiny` | `quick` | 5 |
| `vision`, `designer` | multimodal-looker / `visual-engineering` | 8 / 1 (Claude-led) |
| `security` | — | Local rule R1 below |

## Local rules OMO does not cover

- **R1 Refusal tolerance for RE/security.** Anthropic's own help centre documents exploit, binary-scanning and pentest requests being re-routed from Opus 5.5 down to Opus 4.8. RE, Ghidra and device lanes stay on GPT (`config.yml` security chain).
- **R2 Harness legitimacy of the subscription.** A seat is only as durable as the plan's terms for third-party harnesses. Anthropic's terms ([code.claude.com legal-and-compliance](https://code.claude.com/docs/en/legal-and-compliance)) say subscription OAuth is "intended exclusively for … ordinary use of Claude Code and other native Anthropic applications", and Anthropic "may enforce … without prior notice". OMP authenticates Claude seats with that OAuth. OpenAI staff call third-party harnesses acceptable ([openai/codex#8338](https://github.com/openai/codex/issues/8338)). OpenCode Go publishes a validated-client list that includes Pi.
- **R3 Measured latency.** Per-turn medians from our own transcripts outrank vendor speed claims. On 2026-09-28: Opus 5.5 4.9s, gpt-6-sol 7.7s, Sol 6.2s at a flat 54 tok/s, Astra 37s as main session.
- **R4 Tokens to finish the task, not tokens per turn.** Astra takes the fewest turns per task (24, vs 45 for Sol; Artificial Analysis) despite its slow turns.

## Scoring a candidate model or plan for a seat

1. **Gates (any failure means reject for that seat).** Criterion 1 (right family), criterion 2 (on the ladder for `default`), R1 (RE lanes), R2 (a durable harness path).
2. **Weighted score on what's left (our weights, 100 total).** Quota fit for the seat's frequency (criterion 3) 30; effective capacity per dollar on the plan 25; reasoning-effort headroom (criterion 4) 15; measured latency (R3/R4) 15; provider redundancy (criterion 6) 10; context/vision needs (criteria 7–8) 5.
3. **Verify before adopting.** Smoke the seat in OMP and confirm each child assistant's `model` field and `resolvedModelIsFallback`; don't trust print-mode output.
