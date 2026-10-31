#!/usr/bin/env python3
"""Deterministic post-upgrade pass for the local OMP overrides; no model calls.

Exit 0: reconciled (template rebuilt/installed if needed, live smoke passed).
Exit 3: needs a judgment pass (upstream block 0 changed or a check failed); the
        report names what. Review the named source/diff directly.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
TEMPLATE = HERE.parent / "SYSTEM_TEMPLATE.md"
CANDIDATE = Path("/tmp/SYSTEM_TEMPLATE.new.md")
# `--model` takes no ":<effort>" suffix; `--thinking` sets the level the prompt renders as a suffix.
SMOKE = (
    ("omni/omp/deepseek-v4.1-flash", None, "You are DeepSeek V4.1 Flash"),
    ("omni/omp/deepseek-v4.1-flash", "low", "You are DeepSeek V4.1 Flash"),
    ("openai-codex/gpt-5.6-sol", None, "RFC 2119 keywords"),
)


def run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=REPO, capture_output=True, text=True)


def installed_version() -> str:
    match = re.search(r"(\d+\.\d+\.\d+)", run("omp", "--version").stdout)
    if not match:
        sys.exit("cannot parse omp --version")
    return match.group(1)


def block0(model: str, thinking: str | None) -> str:
    request = json.dumps({"id": "s", "type": "get_state"}) + "\n"
    args = ["omp", "--mode", "rpc", "--no-session", "--model", model]
    if thinking:
        args += ["--thinking", thinking]
    proc = subprocess.run(args, cwd=REPO, input=request, capture_output=True, text=True, timeout=120)
    for line in proc.stdout.splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("id") == "s":
            state = event.get("data") or event
            return (state.get("systemPrompt") or [""])[0]
    return ""


def main() -> None:
    version = installed_version()
    needs: list[str] = []

    build = run("python3", "omp/prompts/build-system-template.py", "--stdout")
    if build.returncode:
        # Non-DeepSeek branch must be OMP's current prompt: accept it, but flag the diff for a
        # DeepSeek-block review.
        diff = Path(f"/tmp/omp-{version}-block0.diff")
        diff.write_text(build.stdout)
        needs.append(f"bundled block 0 changed upstream; review {diff} for the DeepSeek block")
        build = run("python3", "omp/prompts/build-system-template.py", "--accept-upstream", "--stdout")
    # Compare content, not the version header: builder or DeepSeek-block edits must reinstall too.
    if TEMPLATE.exists() and TEMPLATE.read_text() == build.stdout:
        print(f"SYSTEM_TEMPLATE.md already current for omp {version}")
    else:
        CANDIDATE.write_text(build.stdout)
        check = run("bun", "omp/prompts/render-check.ts", str(CANDIDATE), version)
        if check.returncode:
            print(check.stdout)
            print(f"render check FAILED for omp {version}; template NOT installed")
            sys.exit(3)
        run("python3", "omp/prompts/build-system-template.py", "--accept-upstream")
        print(f"installed SYSTEM_TEMPLATE.md for omp {version}")

    for model, thinking, prefix in SMOKE:
        label = f"{model}:{thinking}" if thinking else model
        ok = block0(model, thinking).startswith(prefix)
        print(f"{'ok  ' if ok else 'FAIL'} live block 0 for {label}")
        if not ok:
            needs.append(f"live block 0 for {label} does not start with {prefix!r}")

    changed = run("git", "status", "--porcelain", "--", "omp/prompts").stdout.strip()
    if changed and not needs:
        run("git", "add", "--", "omp/prompts")
        run("git", "commit", "-q", "-m", f"omp: reconcile prompts for omp {version}", "--", "omp/prompts")
        print(f"committed: omp: reconcile prompts for omp {version}")

    if needs:
        print("NEEDS REVIEW:\n- " + "\n- ".join(needs))
        sys.exit(3)
    print(f"reconciled omp {version}")


if __name__ == "__main__":
    main()
