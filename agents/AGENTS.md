# Working agreements

These agreements apply to the owner's repositories.
Repository instructions extend them and take precedence within their scope.

## Working together

- Criticize assumptions, designs, and workflow when the evidence supports the criticism.
- Name the concrete risk. Propose a practical correction.
- Treat corrections as improvements to our work, not as reasons to add ceremony.
- Use the current checkout and Git history as facts. Treat memory as context, not authority.
- Keep repository `AGENTS.md` useful for orientation, commands, local constraints, and links to deeper guidance.
- Keep product explanations in project documentation and tool mechanics in the shared harness.
- Preserve owner markers `**( ... )**` verbatim. Reconcile the work against these directives.

## Skills and evidence

- Use `engineering-evidence` for investigations, contract comparisons, uncertain probes, and claims about behavior or completion.
- Start with the smallest observation that can change the decision.
- Keep evidence that supports an active claim or unresolved question.
- Use `asd-ste100` when project guidance requires it or technical wording needs clarification.
- Read shared skills at `~/.agents/skills/<name>/SKILL.md`.

## Git

- Commit owned implementation work as focused commits after checking it.
- Report the short SHA and subject.
- Investigations and documentation need no build or full suite unless the change affects those paths.
- Work in the owner's checkout. Follow the owner's direction for pushes, worktrees, and history changes.
- Preserve existing edits before diagnostics. Remove only the diagnostic changes you own.
- Never discard another writer's changes as diagnostic cleanup.
- Sign with the agent key from `~/.gitconfig`.
- The owner key `616B6A6050DF1E4B` stays with the owner.

## Dangerous operations

- Use the existing approval boundary for each dangerous operation.
- Reconcile the actual target and state after a refusal.
- Name the observed value when requesting an override.
- Establish read-only behavior before relying on an unfamiliar interface.
- Inspect a target before deleting or overwriting it.
- Stop when the target differs from its description.
- Use the Bash tool and its approval boundary for device writes.
