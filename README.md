# dotfiles

Owner harness configuration for the `1vivy` estate. Private. One clone per host, adopted with
`./install.sh`.

This repository holds the harness dotfiles the owner actually runs: agent context files, skills,
OMP config, Claude/Codex/Paseo config, shell, git, ssh, terminal and small tool configs. It is not a
Nix or system-configuration repo — hosts are built from `1vivy/borrrk-infra`; this repo only fills in
the user-level files that live in the homes.

## Layout

| Path | What |
|---|---|
| `AGENTS.md` | Agent instructions for working in this repository (not installed) |
| `agents/AGENTS.md` | Global working agreements; linked to `~/.agents/AGENTS.md`, `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md` |
| `agents/RULES.md` | OMP sticky rules (always applied, also inside task subagents, which do not receive `AGENTS.md`); linked to `~/.omp/agent/RULES.md` |
| `agents/skills/<name>/` | The 2 harness skills; linked as `~/.agents/skills` and `~/.claude/skills`, and per-skill into `~/.codex/skills/<name>` |
| `omp/` | OMP user config (`config.yml`, `models.yml`, `mcp.json`, `lsp.yaml`, `SYSTEM_TEMPLATE.md`) |
| `omp/prompts/` | `SYSTEM_TEMPLATE.md` builder, vendored upstream prompts and the post-upgrade `reconcile-omp.py` run by `omp-reconcile` / `omp update`. Never installed |
| `omp/ROLES.md`, `omp/omo-model-criteria.md` | Documentation only — role catalogue and model-selection criteria. Never installed |
| `paseo/config.json` | Seed (see below) |
| `shell/`, `git/`, `ssh/config.d/`, `terminal/`, `tools/` | Shell, git, ssh, terminal emulator and small tool configs |
| `xerahs/` | XerahS launcher (capture actions bound by KDE shortcuts) and its `app-xerahs.service` tray unit; workstation only. Uploader configs hold the Zipline token and are never committed |
| `manifest.tsv` | The install manifest: `mode, repo_path, target, profiles` |
| `install.sh` | Adopter |
| `secrets/`, `.sops.yaml` | age ciphertext (`*.age`), the sops dotenv `session.env` for session environment secrets, the public `recipients.txt`, and `age-identity.bw-item` (the Bitwarden item ID holding the private identity); `.sops.yaml` holds the sops creation rule |
| `hooks/pre-commit` | gitleaks secret scan; installed via `core.hooksPath` |

## link, seed, decrypt, gpg

`manifest.tsv` assigns every entry one of four modes:

- **link** — `install.sh` replaces the target with a symlink into this repo. The repo file is the
  single source of truth; edits are made here and appear everywhere immediately. A real file or
  directory already sitting at the target is moved into the backup directory first when its content
  differs; when it is byte-identical it is simply replaced by the link.
- **seed** — the repo file is copied into place **only when the target does not exist**. Seeds are
  starting points for tools that own and rewrite their own config (Paseo); once
  seeded, the live file is authoritative and the repo copy is not pushed over it. `--check` reports
  divergence as `seed-drift` so it is visible, never silently overwritten.
- **decrypt** — the repo holds an age-encrypted file under `secrets/`; `install.sh` decrypts it to the
  target with mode 0600, backing up a differing target first. `--check` decrypts in memory and
  reports `secret-drift` when the live file differs, or `unverified` when this host has no identity.
- **gpg** — the repo holds an age-encrypted armored secret key; `install.sh` imports it into the gpg
  keyring unless its fingerprint is already there. Carried: the passphrase-less agent signing key
  `97B197860AFFE0A3` that `git/gitconfig` signs with. The owner key `616B6A6050DF1E4B` is never
  carried.

Directory links are supported (e.g. `agents/skills -> ~/.agents/skills`).

Third-party skills are git submodules pinned to a reviewed commit (currently
`agents/skills/asd-ste100` → `danyuchn/asd-ste100-skill`). `install.sh` runs
`git submodule update --init` before linking, and `--check` reports a submodule that is
uninitialized (`missing`) or off its pin (`drift`). To take an upstream update, review it, then
`git -C agents/skills/<name> pull` and commit the new pin.

## Profiles

`./install.sh --profile <name>` installs only the entries whose `profiles` column names that profile
(or `all`):

- **workstation** — the owner's CachyOS desktop: everything, including OMP config, terminal emulators
  and the Paseo seed.
- **atlas-agent** — the NixOS agent host: agent context, skills, OMP config, shell/git/ssh/tools and
  tmux. No terminal-emulator config, no Paseo.
- **mac** — owner harness, shell/git/tools, tmux, WezTerm/Ghostty and macOS XerahS seeds.
  Fleet SSH configuration is rendered by `borrrk-infra`, not copied from Linux.

Flags:

```
./install.sh --profile workstation --dry-run   # print the plan, change nothing
./install.sh --profile workstation             # adopt
./install.sh --profile workstation --check     # report ok/missing/replaced-link/seed-drift; exit 1 on problems
```

`--check` is the health probe. `replaced-link` means a tool rewrote a symlinked file into a real file
and the link needs to be re-established; `missing` means the entry was never installed; `seed-drift`
means the live seed has moved on from the repo copy; `secret-drift` means a decrypted secret no
longer matches its ciphertext.

Backups of anything displaced live under `~/.local/state/dotfiles/backup/<timestamp>/`, preserving the
target's path below `$HOME`.

## Adding a file

1. Copy the current live file into the repo at the path that matches its group (`shell/`, `tools/`, …).
2. Add one `manifest.tsv` row: mode, repo path, target, profiles.
3. Commit. `hooks/pre-commit` (gitleaks) must pass.

Keep the repo copy byte-identical to the live file at the moment of adoption, so `--check` starts
clean.

## Secrets

Secret values enter git only as age ciphertext in `secrets/`. One age identity decrypts them all.
It lives at `~/.config/dotfiles/age-identity.txt` (mode 0600) and nowhere in the repo; its public
half is `secrets/recipients.txt`.

- **New host:** `install.sh` fetches the identity from the Bitwarden secure note whose item ID is in
  `secrets/age-identity.bw-item`. It uses `$BW_SESSION` when that is already unlocked, otherwise it
  runs `bw login`/`bw unlock` on the terminal. The session lives only in that process. Hosts without
  `bw` (atlas-agent) take a copy of the identity: `install -m 600 age-identity.txt ~/.config/dotfiles/`.
- **Environment secrets** live in `secrets/session.env`, a sops dotenv file: names are readable,
  values are encrypted to the recipient in `.sops.yaml`. Edit with `sops edit secrets/session.env`
  (`zshenv` exports `SOPS_AGE_KEY_FILE`); sops opens the decrypted file in `$EDITOR` and re-encrypts
  on save. `shell/zshenv` decrypts it with the host's identity on the first shell after boot, or after
  the file changes, into a per-user runtime file (`$XDG_RUNTIME_DIR` on Linux, the user temp dir on
  macOS) and exports it to every shell. Logging in to the machine is the trust boundary; Bitwarden is
  only touched once per new host, to fetch the identity.
- **File secrets:** `age -a -R secrets/recipients.txt -o secrets/<name>.age <live file>`, add a
  `decrypt` row to `manifest.tsv`, commit. Edit by re-encrypting from the live file.
- **Requires** `age` and `sops` on every host (`pacman -S age sops`, `brew install age sops`; NixOS
  via the borrrk-infra workstation module).

## Node

Every host runs Node through fnm (`pacman -S fnm`, `brew install fnm`, NixOS via the borrrk-infra
workstation module). `shell/zshenv` sets `FNM_DIR` and puts fnm's `default` alias on `PATH` for
non-interactive shells and services; `shell/zshrc` runs `fnm env --use-on-cd`, so interactive shells
follow `.node-version`/`.nvmrc`. Once per host: `fnm install 24 && fnm default 24`.
`FNM_COREPACK_ENABLED` gives each installed version `pnpm`/`yarn` shims. `tools/npmrc` sends global
installs to `~/.local` on every host, so they survive Node upgrades. A user service that needs node
puts `~/.local/share/fnm/aliases/default/bin` on its `PATH`.

## Never committed in plaintext

Secret values and secret-bearing state stay out of this repository in plaintext, always:

- `~/.netrc`, `~/.config/gh/hosts.yml`, `~/.vault-token`
- `~/.claude.json`, `~/.codex/auth.json`, any `auth.json` or `.env`
- `~/.hindsight/secrets`, `~/.config/borrrk/openbao-agent.json`
- `~/.paseo/daemon-keypair.json`, `~/.paseo/push-tokens.json`, `~/.paseo/local-credential`
- SSH private keys, `known_hosts`, agent sockets
- session/history/stats databases (`agent.db`, `history.db`, `models.db`, `logs_*.sqlite`, …), caches,
  blobs and shell snapshots

The fleet SSH configuration (`~/.ssh/config.d/borrrk`: host aliases and LAN addresses) is carried
encrypted as `secrets/ssh-fleet.conf.age`. Its `/home/vivy` paths are Linux-only, so the `mac`
profile skips it; there `scripts/borrrk doctor` in `1vivy/borrrk-infra` renders the file with the
right home.

`hooks/pre-commit` runs `gitleaks protect --staged` over every commit; `install.sh` points
`core.hooksPath` at `hooks/`. Before the first commit the tree was also scanned with
`gitleaks detect --no-git` — zero findings.

`.gitleaks.toml` extends the default ruleset and carries one reviewed allowlist: the GPG signing key
*fingerprint* on the `signingkey` line of `git/gitconfig`. It is a public value, not key material.

## SSH and terminals

Install `tmux` (3.2 or newer), `zsh`, and terminfo for `tmux-256color` on machines where you run
tmux. On macOS, `brew install tmux zsh` supplies tmux; choose Ghostty or WezTerm as the client.
Run `./install.sh --profile mac` on the Mac, `--profile workstation` on the desktop, and
`--profile atlas-agent` on the server. The installer manages configs, not package installation.

- Connect normally with `ssh host`, then run `tmux new-session -A -s main`; or use
  `ssh -t host 'tmux new-session -A -s main'` to attach directly. No forced remote command,
  global TERM override, agent forwarding, or automatic tmux nesting is installed.
- WezTerm opens a local `main` tmux session when tmux is installed. Ghostty leaves the shell
  unwrapped. When already in local tmux, `C-b C-b` sends a prefix to a remote nested tmux.
  Prefer a separate terminal tab for direct remote attachment if nested prefixes are inconvenient.
- Wheel/trackpad scrolling enters tmux history at a shell prompt instead of navigating shell
  input history. Mouse-aware programs retain their own scrolling. `C-b [` is keyboard copy mode;
  PageUp/PageDown navigate, `/` searches, `v` starts selection, `y` copies, and `q` exits.
  Hold Shift for terminal-native selection where supported (configured explicitly in WezTerm).
- `C-b %` / `C-b "` split horizontally/vertically; `C-b c` creates a window, retaining the current
  directory. Windows start at 1. `C-b d` detaches; `C-b r` reloads `~/.tmux.conf`.
  New history limits apply to new windows. Existing servers can reload without killing sessions.
- Extended keys are enabled only when an application requests them (`extended-keys on`, not
  `always`); tmux 3.5+ reports them using CSI-u. This preserves Shift/Ctrl+Enter for applications
  using modifyOtherKeys while keeping legacy input unchanged. Ghostty's existing OMP-specific
  Shift+Enter and Alt+Backspace mappings are retained. This is not full Kitty keyboard-protocol
  or graphics passthrough support; use a direct terminal session for features requiring those.
- Copies use OSC 52 through the attached client, so no remote `xclip`/`pbcopy` is needed.
  The client must permit clipboard writes; enable that in Termius if required. Applications inside
  tmux cannot directly set tmux's clipboard (`set-clipboard external`). No unrestricted passthrough
  or plugin manager is enabled.
- Ghostty's SSH shell integration installs its terminfo remotely when possible and falls back to
  `xterm-256color` when installation fails. Standard Termius/iTerm2 `xterm-256color` also works.
  Do not globally export TERM in shell startup files. For an unfamiliar client reporting an unknown
  terminal, use `TERM=xterm-256color ssh host` for that connection, or install its actual terminfo.
  Verify the server with `infocmp "$TERM"` outside tmux and `infocmp tmux-256color` inside it.
- Both emulator configs select **MesloLGS NF**, matching Powerlevel10k. Install the four font faces
  linked in the [Powerlevel10k font instructions](https://github.com/romkatv/powerlevel10k#fonts)
  on each connecting desktop/Mac (Font Book on macOS), then select the same family in Termius or
  iTerm2. SSH does not transmit fonts; headless servers need no font installation. The tmux status
  line uses plain text, so it remains readable from clients without Nerd Fonts.

Fleet aliases and authentication remain owned by `borrrk-infra/scripts/borrrk doctor`. The current
SSH setup already uses keepalives and disables agent forwarding; terminal setup does not replace
keys, host verification, or those generated aliases. Neither WezTerm's native SSH mode nor iTerm2's
`tmux -CC` control mode is required for normal SSH/tmux operation.

## Notes

- OMP's own skill directory (`~/.agents/skills`) is the link target, so `~/.omp/agent/skills` stays
  empty and unused.
