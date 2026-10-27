# AGENTS.md — dotfiles

Scope: this repository. `agents/AGENTS.md` is the global agreement it installs into
`~/.agents`, `~/.claude` and `~/.codex`; this file covers working in the repo itself.
`README.md` documents the layout, manifest modes and profiles.

The repository is public. Everything committed is published.

## Secrets

- Secret values live in `secrets/*.age`, encrypted to `secrets/recipients.txt`, in the 0600 files
  `install.sh` writes from them, and in the session environment `shell/zshenv` loads from
  `secrets/session.env` (sops dotenv).
- Values move file to file: encrypt from the live file
  (`age -a -R secrets/recipients.txt -o secrets/<name>.age <live file>`), decrypt into a pipe or a
  0600 file. Model context and tool arguments carry names, paths and hashes only.
- Verify a secret by round trip (`age -d -i ~/.config/dotfiles/age-identity.txt <file> | cmp -
  <live file>`) or by hash prefix. Check an environment secret's presence with `[[ -n $NAME ]]` or a
  hash of its value.
- New environment secret: `sops edit secrets/session.env` and add a `NAME=value` line.
  New file secret: add the `.age` file and a `decrypt` (or `gpg`) row in `manifest.tsv`, run
  `./install.sh --profile <profile>`, then `--check`.
- The age identity comes from the Bitwarden item in `secrets/age-identity.bw-item` through
  `install.sh`'s interactive unlock, or by copying the identity file between hosts over SSH with
  mode 0600.
- Host addresses (LAN and tailnet IPs) are private but not secret: they go in an encrypted file or
  a host-local override such as `~/.gitconfig.local`.

## Public detail

Everything committed, commit messages included, is published. Keep functional values where the
config needs them and keep prose generic.

- May be committed: home-relative paths (`~/Documents/Obsidian/University`), host aliases
  (`atlas-agent`), repository names (`1vivy/borrrk-infra`) and endpoints a config file needs to
  work (`omp/config.yml`, `shell/zshenv`).
- Comments, docs and commit messages name things by role ("the Hermes agent", "the agent's staged
  writer", "the sync server"). They do not name agent personas or profiles, internal service
  endpoints or scripts, schools, courses or people.
- Point at the private repository for specifics (`borrrk-infra resources/services/<name>/`) rather
  than restating them here.
- Before committing, `git grep` the change for such names. History rewrites are the owner's call.

## Changes

- Commit through `hooks/pre-commit` (gitleaks).
- After a change that affects installed files, run `./install.sh --profile <profile> --check` on
  each affected host: workstation, atlas-agent (`ssh atlas-agent`) and the Mac
  (`ssh vivys-macbook-air`).
- Hosts take new commits from `origin` with `dotfiles-update`.
