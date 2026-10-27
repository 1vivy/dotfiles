# Obsidian — adoption plan (not installed)

Nothing here is in `manifest.tsv` yet.

## Current state (2026-10-27)

- Clients: workstation (pacman `obsidian`) and Mac (`Obsidian.app`), both 1.14.5; atlas-agent has none.
  Each has one vault, `University`; the vault path differs per host (see the app's `obsidian.json`).
- Self-hosted LiveSync syncs notes only. Hidden-file sync and customization sync are off, so each
  host's `.obsidian/` is independent.
- `.obsidian/` is stock on both hosts: `app.json`, `appearance.json`, `core-plugins.json` and
  `graph.json` are identical. They differ only in `community-plugins.json` (workstation adds `tldraw`)
  and the LiveSync plugin version (1.0.29 on the workstation, 1.0.23 on the Mac).
- Obsidian writes config with `fsPromises.writeFile` (seen in `app.js` of the 1.14.5 asar), which
  writes through symlinks. `link` mode should therefore survive setting changes. This is unverified
  against a running app.

## Todo

- [ ] `obsidian/` mirrors `.obsidian/`: `app.json`, `appearance.json`, `core-plugins.json`,
      `community-plugins.json` (take the workstation copy, which includes `tldraw`).
- [ ] `link` rows per profile (workstation, mac); targets are the per-host vault `.obsidian/` paths.
      Keep the private paths out of the public repo (host-local value or encrypted row).
- [ ] Prove link survival: toggle a setting in the app, then `./install.sh --check` shows `ok`, not
      `replaced-link`.
- [ ] Do not carry `workspace.json` or `graph.json` (view state), plugin code (installed from the
      community browser), or LiveSync `data.json` (credentials and per-device state; set up by Setup
      URI per borrrk-infra `obsidian-sync` devices doc).
- [ ] README: app install per host (pacman / Obsidian.app), what is carried, and why LiveSync
      hidden-file/customization sync must stay off while links are in place.
- [ ] Install tldraw on the Mac; consider updating its LiveSync to match.
- [ ] Alternative to weigh first: LiveSync customization sync also reaches the iPad, which dotfiles
      cannot.
