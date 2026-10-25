---
name: omp-wayland-pipewire-capture-repair
description: "Repair OMP Wayland capture when the native addon lacks wayland-pipewire, then prove portal capture and install an isolated matching CLI build."
---

# Diagnose
Use computer first. A CaptureFailed mentioning `wayland-pipewire` means compile-time omission, not necessarily a missing portal. Check installed `omp --version`, executable kind/path, `pkg-config --modversion libpipewire-0.3 libspa-0.2`, and user PipeWire/WirePlumber/portal services. KDE unit is `plasma-xdg-desktop-portal-kde.service`, not `xdg-desktop-portal-kde.service`.

# Build matching sources
Fetch exact installed tag from can1357/oh-my-pi into an isolated hidden checkout. Read current manifests/scripts before acting. v18.1.10 crate default=[] and Bazel crate_features=[]; ordinary build-bindings.ts lacks feature passthrough. Cargo explicitly enables it. The old global npm installation may differ from the compiled ~/.bun/bin/omp; don't repair the wrong version.

For v18.1.10, `bun install --frozen-lockfile --ignore-scripts`; install pinned `nightly-2026-08-08` with minimal profile, then `RUSTFLAGS='-C target-cpu=x86-64-v3' CARGO_BUILD_JOBS=8 cargo +nightly-2026-08-08 build --locked -p pi-natives --features wayland-pipewire --profile ci`. CI profile is optimized, thin-LTO, stripped. Nix already documents enabling the feature; no capture code rewrite was required.

# Isolate local native identity
Compiled loaders extract embedded addon into ~/.omp/natives/<native-package-version> and reuse it only when manifest size matches. Replacing that cache alone is not durable; old/new same-version executables can restore conflicting embedded files. Never spoof/pad file size or bypass sentinel.

Use an honest unique local version, e.g. 18.1.10-wayland.1: explicit version in crates/pi-natives/Cargo.toml, matching packages/natives/package.json, and matching Rust NAPI sentinel __piNativesV18_1_10_wayland_1 in crates/pi-natives/src/lib.rs. For CLI identity update packages/coding-agent/package.json AND packages/utils/package.json: CLI VERSION imports utils metadata. Update those three root package.json catalog pins too, otherwise Bun tries to fetch published originals rather than workspace packages. Regenerate Bun lock via bun install --ignore-scripts and Cargo lock via offline build; do not bypass minimum-release-age. Rebuild native after sentinel change.

Avoid XDG_DATA_HOME as a cache-only workaround: utils/dirs.ts relocates broader user configuration/state when XDG vars are set.

# Embed and compile
Stage target/ci/libpi_natives.so as packages/natives/native/pi_natives.linux-x64-modern.node; compare bytes. This is a local x86-64-v3 build, not universal distribution. Fresh checkout has no stale opposite variant; never embed an old baseline alongside a rebuilt modern. Run `CROSS_TARGET=linux-x64 PI_NATIVE_VARIANT=modern bun --cwd=packages/coding-agent run build`. Output packages/coding-agent/dist/omp-linux-x64. It generates stats/tool views/docs/native embedding and resets temporary payloads. `--version` must report intended local version; `--smoke-test` must pass (worker handshake only, NOT capture proof).

# Real capture proof and install
After informing owner, run a temporary Bun script importing createDesktopSession from packages/natives/native/desktop.js. Read capabilities, await session.capture('desktop'), save PNG, finally await session.close(). Use supervised process while awaiting portal consent. Owner must select screen and approve ScreenCast interactively; never click consent yourself. This path does not request RemoteDesktop/input control. Confirm frame dimensions/backend and visually read image. v18.1.10 selects a monitor; window capture is an AT-SPI crop, not portal window-source capture.

Back up installed executable and byte-compare. Install verified new binary through unique same-directory temporary file + atomic rename; never overwrite loaded executable/addon in-place. Run installed --version/--smoke-test and compare extracted local-version addon to tested source addon. Remove temporary capture script/private screenshot after proof. Keep backup/source provenance.

# Restart constraint
Bun worker threads/native modules remain resident in running OMP; replacing executable doesn't refresh current computer facade. Owner must fully restart OMP and resume conversation (`omp -c` from same directory or `omp -r` picker). Then exercise computer.screenshot through actual eval facade before resuming GUI work. Do not claim old session was hot-reloaded. Native capabilities() may be undefined before successful worker operation because supervisor only caches capabilities from a result.
