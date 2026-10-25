#!/usr/bin/env bash
# install.sh — adopt this dotfiles repo on a host.
#
# Usage:
#   ./install.sh --profile workstation [--dry-run] [--check]
#
# Profiles: workstation | atlas-agent | mac
#   --dry-run  print the plan, change nothing
#   --check    report per-entry state (ok/missing/replaced-link/seed-drift/secret-drift);
#              exit non-zero when any entry is not ok. Never mutates.
#
# Behaviour is driven by manifest.tsv (mode, repo_path, target, profiles).
#   link     symlink target -> repo file/dir. A real file/dir already at the target
#            is moved to the backup dir first when it differs; when it is identical
#            it is replaced by the link (the tool never rewrites it back).
#   seed     copy the repo file into place only when the target is missing.
#   decrypt  write the age-decrypted repo file to the target with mode 0600,
#            backing up a differing target first. The age identity is read from
#            $AGE_IDENTITY; when absent it is fetched once from the Bitwarden item
#            named in secrets/age-identity.bw-item (interactive unlock; the session
#            is never stored).
#   gpg      import the age-decrypted armored secret key into the gpg keyring
#            (target column is informational); skipped when its fingerprint is present.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$REPO/manifest.tsv"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
BACKUP_ROOT="$STATE_DIR/backup"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$STAMP"
PROFILE=""
DRY_RUN=0
CHECK=0

die() { printf 'install.sh: %s\n' "$*" >&2; exit 2; }

usage() {
  sed -n '2,23p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --profile) [ $# -ge 2 ] || die "--profile needs a value"; PROFILE="$2"; shift 2 ;;
    --profile=*) PROFILE="${1#*=}"; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --check) CHECK=1; shift ;;
    -h|--help) usage 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

[ -n "$PROFILE" ] || die "missing --profile (workstation|atlas-agent|mac)"
case "$PROFILE" in
  workstation|atlas-agent|mac) ;;
  *) die "unknown profile: $PROFILE" ;;
esac
[ -f "$MANIFEST" ] || die "manifest not found: $MANIFEST"

expand() { case "$1" in "~/"*) printf '%s/%s' "$HOME" "${1#\~/}" ;; *) printf '%s' "$1" ;; esac; }

in_profile() { # $1 = profiles column
  case "$1" in
    all) return 0 ;;
    *) case ",$1," in *",$PROFILE,"*) return 0 ;; *) return 1 ;; esac ;;
  esac
}

AGE_IDENTITY="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/age-identity.txt"
AGE_RECIPIENTS="$REPO/secrets/recipients.txt"
AGE_ITEM_FILE="$REPO/secrets/age-identity.bw-item"
IDENTITY_STATE="" # "", ready, failed: resolve at most once per run

# identity_ready: 0 when $AGE_IDENTITY holds a key listed in secrets/recipients.txt.
# Fetches it from Bitwarden when absent. Prompts read /dev/tty because the manifest
# loop owns stdin.
identity_ready() {
  case "$IDENTITY_STATE" in ready) return 0 ;; failed) return 1 ;; esac
  if [ ! -s "$AGE_IDENTITY" ]; then
    if [ "$DRY_RUN" = 1 ]; then
      printf '    would fetch age identity from Bitwarden into %s\n' "$AGE_IDENTITY"
      IDENTITY_STATE=ready; return 0
    fi
    fetch_identity || { IDENTITY_STATE=failed; return 1; }
  fi
  if ! grep -qxF "$(age-keygen -y "$AGE_IDENTITY" 2>/dev/null)" "$AGE_RECIPIENTS"; then
    printf '    ERROR: %s is not a key listed in secrets/recipients.txt\n' "$AGE_IDENTITY"
    IDENTITY_STATE=failed; return 1
  fi
  IDENTITY_STATE=ready
}

fetch_identity() {
  local item session status
  item="$(cat "$AGE_ITEM_FILE" 2>/dev/null || true)"
  if [ -z "$item" ] || ! command -v bw >/dev/null 2>&1; then
    printf '    ERROR: no age identity at %s; install bw (item in secrets/age-identity.bw-item)\n' "$AGE_IDENTITY"
    printf '           or copy the identity from another host with mode 0600\n'
    return 1
  fi
  session="${BW_SESSION:-}"
  status="$(BW_SESSION="$session" bw status 2>/dev/null || true)"
  case "$status" in
    *'"status":"unlocked"'*) ;;
    *'"status":"unauthenticated"'*)
      printf '    Bitwarden login (fetches the age identity; the session is not stored)\n'
      session="$(bw login --raw </dev/tty)" || return 1 ;;
    *)
      printf '    Bitwarden unlock (fetches the age identity; the session is not stored)\n'
      session="$(bw unlock --raw </dev/tty)" || return 1 ;;
  esac
  mkdir -p "$(dirname "$AGE_IDENTITY")"
  rm -f "$AGE_IDENTITY"
  if ! (umask 077; BW_SESSION="$session" bw get notes "$item" > "$AGE_IDENTITY") || [ ! -s "$AGE_IDENTITY" ]; then
    rm -f "$AGE_IDENTITY"
    printf '    ERROR: could not read Bitwarden item %s\n' "$item"
    return 1
  fi
  printf '    fetched age identity from Bitwarden item %s\n' "$item"
}

# same_content <repo_path> <target>
# 0 when target is byte-identical to the repo path (recursive for dirs).
same_content() {
  local src="$1" dst="$2"
  if [ -d "$src" ]; then
    [ -d "$dst" ] || return 1
    diff -rq --no-dereference "$src" "$dst" >/dev/null 2>&1
  else
    [ -f "$dst" ] || return 1
    cmp -s "$src" "$dst"
  fi
}

backup_target() { # $1 = target
  local t="$1" rel
  rel="${t#"$HOME"/}"
  [ "$rel" = "$t" ] && rel="${t#/}"
  if [ "$DRY_RUN" = 1 ]; then
    printf '    would back up %s -> %s\n' "$t" "$BACKUP_DIR/$rel"
  else
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    mv "$t" "$BACKUP_DIR/$rel"
    printf '    backed up %s -> %s\n' "$t" "$BACKUP_DIR/$rel"
  fi
}

do_link() { # $1 = repo_path, $2 = target
  local src="$REPO/$1" dst="$2"
  [ -e "$src" ] || [ -L "$src" ] || { printf '    ERROR: repo path missing: %s\n' "$src"; FAIL=1; return; }
  [ "$DRY_RUN" = 1 ] || mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ]; then
    if [ "$(readlink "$dst")" = "$src" ]; then
      printf '    ok (already linked)\n'; return
    fi
    printf '    relinking (was -> %s)\n' "$(readlink "$dst")"
    [ "$DRY_RUN" = 1 ] || rm -f "$dst"
  elif [ -e "$dst" ]; then
    if same_content "$src" "$dst"; then
      printf '    identical; replacing with link\n'
      [ "$DRY_RUN" = 1 ] || rm -rf "$dst"
    else
      printf '    differs; backing up then linking\n'
      backup_target "$dst"
    fi
  else
    printf '    creating link\n'
  fi
  if [ "$DRY_RUN" = 1 ]; then
    printf '    would link %s -> %s\n' "$dst" "$src"
  else
    ln -s "$src" "$dst"
    printf '    linked %s -> %s\n' "$dst" "$src"
  fi
}

do_seed() { # $1 = repo_path, $2 = target
  local src="$REPO/$1" dst="$2"
  [ -f "$src" ] || { printf '    ERROR: repo path missing: %s\n' "$src"; FAIL=1; return; }
  [ "$DRY_RUN" = 1 ] || mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ]; then
    printf '    ok (seed target present, left untouched)\n'
    return
  fi
  if [ "$DRY_RUN" = 1 ]; then
    printf '    would seed %s -> %s\n' "$dst" "$src"
  else
    cp -p "$src" "$dst"
    printf '    seeded %s <- %s\n' "$dst" "$src"
  fi
}

do_decrypt() { # $1 = repo_path, $2 = target
  local src="$REPO/$1" dst="$2" tmp
  [ -f "$src" ] || { printf '    ERROR: repo path missing: %s\n' "$src"; FAIL=1; return; }
  command -v age >/dev/null 2>&1 || { printf '    ERROR: age is not installed\n'; FAIL=1; return; }
  identity_ready || { FAIL=1; return; }
  if [ "$DRY_RUN" = 1 ]; then
    printf '    would decrypt to %s (0600)\n' "$dst"; return
  fi
  mkdir -p "$(dirname "$dst")"
  tmp="$(mktemp "$(dirname "$dst")/.dotfiles-decrypt.XXXXXX")" # mktemp creates 0600
  if ! age -d -i "$AGE_IDENTITY" "$src" > "$tmp"; then
    rm -f "$tmp"; printf '    ERROR: decryption failed\n'; FAIL=1; return
  fi
  if [ -f "$dst" ] && [ ! -L "$dst" ] && cmp -s "$tmp" "$dst"; then
    rm -f "$tmp"; chmod 600 "$dst"; printf '    ok (already current)\n'; return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    printf '    differs; backing up then writing\n'
    backup_target "$dst"
  fi
  mv "$tmp" "$dst"
  printf '    decrypted %s (0600)\n' "$dst"
}

# gpg_fpr <repo_path>: primary fingerprint of the encrypted armored key.
gpg_fpr() {
  age -d -i "$AGE_IDENTITY" "$REPO/$1" 2>/dev/null | gpg --batch --with-colons --show-keys 2>/dev/null \
    | awk -F: '/^fpr/{print $10; exit}'
}

do_gpg() { # $1 = repo_path, $2 = target (informational)
  local src="$REPO/$1" fpr
  [ -f "$src" ] || { printf '    ERROR: repo path missing: %s\n' "$src"; FAIL=1; return; }
  command -v age >/dev/null 2>&1 || { printf '    ERROR: age is not installed\n'; FAIL=1; return; }
  command -v gpg >/dev/null 2>&1 || { printf '    ERROR: gpg is not installed\n'; FAIL=1; return; }
  identity_ready || { FAIL=1; return; }
  if [ "$DRY_RUN" = 1 ]; then printf '    would import secret key into the gpg keyring\n'; return; fi
  fpr="$(gpg_fpr "$1")"
  [ -n "$fpr" ] || { printf '    ERROR: no key in decrypted %s\n' "$1"; FAIL=1; return; }
  if gpg --batch --list-secret-keys "$fpr" >/dev/null 2>&1; then
    printf '    ok (secret key %s present)\n' "$fpr"; return
  fi
  if age -d -i "$AGE_IDENTITY" "$src" | gpg --batch --quiet --import; then
    printf '    imported secret key %s\n' "$fpr"
  else
    printf '    ERROR: gpg import failed\n'; FAIL=1
  fi
}

check_link() { # $1 = repo_path, $2 = target
  local src="$REPO/$1" dst="$2"
  if [ ! -e "$src" ] && [ ! -L "$src" ]; then printf 'missing (repo path absent)'; return 1; fi
  if [ -L "$dst" ]; then
    if [ "$(readlink "$dst")" = "$src" ]; then printf 'ok'; return 0; fi
    printf 'replaced-link (points at %s)' "$(readlink "$dst")"; return 1
  fi
  if [ -e "$dst" ]; then printf 'replaced-link (real %s)' "$([ -d "$dst" ] && echo dir || echo file)"; return 1; fi
  printf 'missing'; return 1
}

check_seed() { # $1 = repo_path, $2 = target
  local src="$REPO/$1" dst="$2"
  if [ ! -e "$dst" ]; then printf 'missing'; return 1; fi
  if cmp -s "$src" "$dst"; then printf 'ok'; return 0; fi
  printf 'seed-drift (differs from repo)'; return 1
}

check_decrypt() { # $1 = repo_path, $2 = target
  local src="$REPO/$1" dst="$2"
  if [ ! -f "$src" ]; then printf 'missing (repo path absent)'; return 1; fi
  if [ ! -e "$dst" ]; then printf 'missing'; return 1; fi
  if ! command -v age >/dev/null 2>&1; then printf 'unverified (age not installed)'; return 1; fi
  if [ ! -s "$AGE_IDENTITY" ]; then printf 'unverified (no age identity at %s)' "$AGE_IDENTITY"; return 1; fi
  if age -d -i "$AGE_IDENTITY" "$src" 2>/dev/null | cmp -s - "$dst"; then printf 'ok'; return 0; fi
  printf 'secret-drift (differs from decrypted repo file)'; return 1
}

check_gpg() { # $1 = repo_path, $2 = target (informational)
  local fpr
  if [ ! -f "$REPO/$1" ]; then printf 'missing (repo path absent)'; return 1; fi
  if ! command -v gpg >/dev/null 2>&1; then printf 'missing (gpg not installed)'; return 1; fi
  if [ ! -s "$AGE_IDENTITY" ]; then printf 'unverified (no age identity at %s)' "$AGE_IDENTITY"; return 1; fi
  fpr="$(gpg_fpr "$1")"
  if [ -n "$fpr" ] && gpg --batch --list-secret-keys "$fpr" >/dev/null 2>&1; then printf 'ok'; return 0; fi
  printf 'missing (secret key %s not in keyring)' "${fpr:-?}"; return 1
}

FAIL=0
printf 'dotfiles install: profile=%s repo=%s%s%s\n' "$PROFILE" "$REPO" \
  "$([ "$DRY_RUN" = 1 ] && echo ' dry-run')" "$([ "$CHECK" = 1 ] && echo ' check')"

# Submodule-backed skills (agents/skills/*) must be checked out at the pinned commit
# before linking; `git pull` alone does not update them.
if git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 && [ -f "$REPO/.gitmodules" ]; then
  if [ "$CHECK" = 1 ]; then
    while read -r sm_sha sm_path _; do
      case "$sm_sha" in
        -*) printf '  missing         submodule %s (not initialized)\n' "$sm_path"; FAIL=1 ;;
        +*) printf '  drift           submodule %s (not at pinned commit)\n' "$sm_path"; FAIL=1 ;;
      esac
    done <<EOF
$(git -C "$REPO" submodule status)
EOF
  elif [ "$DRY_RUN" = 1 ]; then
    printf '  submodules: would run git submodule update --init\n'
  else
    git -C "$REPO" submodule update --init --quiet || { printf '    ERROR: git submodule update --init failed\n'; FAIL=1; }
  fi
fi

while IFS=$'\t' read -r mode repo_path target profiles; do
  case "$mode" in ''|\#*) continue ;; esac
  [ -n "${profiles:-}" ] || continue
  in_profile "$profiles" || continue
  dst="$(expand "$target")"
  if [ "$CHECK" = 1 ]; then
    # check_<mode> by name: macOS bash 3.2 cannot parse `case` inside $( ).
    if status="$("check_$mode" "$repo_path" "$dst")"; then
      printf '  ok              %-9s %s -> %s\n' "$mode" "$target" "$repo_path"
    else
      printf '  %-15s %-9s %s -> %s\n' "${status%% *}" "$mode" "$target" "$repo_path"
      FAIL=1
    fi
    continue
  fi
  printf '  %s %s -> %s\n' "$mode" "$target" "$repo_path"
  case "$mode" in
    link) do_link "$repo_path" "$dst" ;;
    seed) do_seed "$repo_path" "$dst" ;;
    decrypt) do_decrypt "$repo_path" "$dst" ;;
    gpg) do_gpg "$repo_path" "$dst" ;;
    *) printf '    ERROR: unknown mode %s\n' "$mode"; FAIL=1 ;;
  esac
done < "$MANIFEST"

if [ "$CHECK" = 1 ]; then
  if [ "$FAIL" = 0 ]; then printf 'check: clean\n'; else printf 'check: problems found\n'; fi
  exit "$FAIL"
fi

if [ "$DRY_RUN" = 0 ]; then
  if [ -d "$BACKUP_DIR" ]; then printf 'backup dir: %s\n' "$BACKUP_DIR"; else printf 'backup dir: (none needed) %s\n' "$BACKUP_ROOT"; fi
  mkdir -p "$STATE_DIR" && printf '%s\n' "$PROFILE" > "$STATE_DIR/profile" # read by dotfiles-update
  if git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$REPO" config core.hooksPath "$REPO/hooks"
    printf 'git core.hooksPath -> %s/hooks\n' "$REPO"
  fi
fi
exit "$FAIL"
