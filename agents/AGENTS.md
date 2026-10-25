# Working agreements

Applies to every repository on the owner's machines. A repository's own AGENTS.md extends this file
and wins within its scope.

## Evidence

- Treat a failed, empty or non-matching probe as unknown until a probe that would match has run; test
  the pattern against a known-present case first. A misnamed grep target, a locked vault and a
  remembered digest each produced false "absent" findings before.
- Verify backups and transfers by restore-and-compare. Exit status and schema checks confirm shape,
  not content: a truncated `tar | ssh` stream once exited 0.
- Owner markers `**( ... )**` in any document are owner directives; keep them verbatim and reconcile
  work against them.
- Answer engineering questions with the smallest real observation. Build an instrument (CLI, runner,
  fixture, permanent test, report schema) when the work needs it again.
- Permanent tests cover consumer-visible behavior and safety boundaries. Verify changed behavior on
  its real surface.
- Keep evidence that a live claim or open question uses.

## Git

- Commit owned implementation work as focused commits after its verification; report short SHA and
  subject. Investigations and documentation need no build or full suite.
- Work in the owner's checkout. Push, force-push, worktrees and discarding work follow the owner's
  direction; preserve local commits and unique evidence first.
- Commits sign with the agent key from `~/.gitconfig`. The owner key `616B6A6050DF1E4B` stays with
  the owner; its pinentry needs a TTY.

## Dangerous operations

- Each dangerous class (push, critical device writes, build entry, extraction, history rewrite) has
  one audited boundary. On a refusal, reconcile the actual target and state; an override names the
  observed value.
- Prove read-only before relying on it; probe opaque surfaces with short known-good lists.
- Look at a target before deleting or overwriting it, and surface any mismatch with its description.
- Device writes run through the Bash tool, where `~/.omp/agent/config.yml` holds approval for fastboot
  flashing, slot selection and raw block writes.
