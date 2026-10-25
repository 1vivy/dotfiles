---
name: linux-game-stutter-triage
description: "Diagnose Linux game hitching when CPU/GPU averages look healthy, VRAM accounting leaks, or disk stays busy with little visible I/O."
---

# Linux game stutter triage

## Use when

- A running game hitches despite healthy average FPS, CPU load, and GPU utilization.
- NVIDIA logs suggest VRAM eviction, a long-lived process may have leaked framebuffer memory, or a priority-elevated CPU task is spinning.
- `/proc/pressure/io` is high while per-process I/O cannot explain an NVMe device near 100% busy.
- The lead suspect is thermal or acoustic instead (throttling, fan policy, pump or coil whine): use `desktop-cooling-fan-noise-ops`.

## Procedure

1. **Gather latency evidence before changing game settings.**
   ```sh
   ps aux --sort=-%cpu | sed -n '1,15p'
   nvidia-smi --query-gpu=utilization.gpu,clocks.sm,clocks.max.sm,power.draw,temperature.gpu,memory.used,memory.total,pstate --format=csv
   cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
   cat /proc/pressure/cpu
   cat /proc/pressure/io
   sudo dmesg -T | grep -iE 'xid|nvrm|evict|oom' | tail -n 20
   ```
   - `performance` or `schedutil` is expected; `powersave` is suspect.
   - CPU PSI `full>0` or `some avg10>5` indicates real contention.
   - Clocks far below maximum at P0 with low temperature point to power/driver behavior rather than thermal throttling.

2. **Interpret NVIDIA evidence.**
   - `NV_ERR_NO_MEMORY`, `GspRmAlloc failed`, or `ctxBufPoolReserve` spam proves VRAM exhaustion.
   - Xid 13 naming a PID means that process is crashing GPU channels and may leak framebuffer memory.
   - Sum per-process usage and compare it with authoritative FB `Used`.
   ```sh
   nvidia-smi | sed -n '/Processes/,$p'
   nvidia-smi | sed -n '/Processes/,$p' | grep -oP '\d+MiB' | tr -d 'MiB' | paste -sd+ | bc
   nvidia-smi -q -d MEMORY | sed -n '/FB Memory/,/BAR1/p'
   sudo fuser -v /dev/nvidia0 /dev/nvidia-uvm
   ```
   - A multi-gigabyte gap with no hidden device holder is orphaned/leaked FB memory in a listed long-lived client; a leaker can show 3.5 GB per-process while actually retaining 24 GB.

3. **Remediate a VRAM leak without killing the game when possible.**
   - KDE: `systemctl --user restart plasma-plasmashell.service`; panels blink, but kwin, Xwayland, and the game remain running.
   - Close or restart browser/Electron GPU processes so they respawn cleanly.
   - If kwin or Xwayland owns the leak, only a driver reload or reboot reclaims it.
   - Recheck memory and dmesg. Residual hitching may clear only at the next map load or game restart while evicted buffers repopulate.

4. **Inspect CPU offenders.**
   - For any process above 90% CPU with `<` in STAT, run `ps -o pid,ppid,ni,stat,etime,args` and trace ancestry with `pstree -ps <pid>`.
   - Negative-nice spinners can steal scheduler slots even when PSI looks modest; stuck container builds commonly have a `containerd-shim` ancestor.
   - Report before killing because the process may belong to another workflow.

5. **Detect a TRIM/discard storm that process tools cannot see.**
   - Signature: `/proc/pressure/io` `full>20` sustained, healthy CPU/GPU, no matching `/proc/*/io` deltas, and system-wide stalls.
   - Measure `/proc/diskstats` deltas across four seconds: busy percent is `Δio_ticks/4000×100`.
   - About 100% busy with fewer than 100 read+write IOPS means the device is executing work other than normal reads/writes.
   - Read discard fields omitted by many tools: field 14 is completed discard operations and field 16 is discarded sectors. Thousands of discard IOPS identifies a TRIM sweep.
   - `pgrep -af fstrim` finds the weekly `fstrim.service` (`fstrim.timer` is enabled; `systemctl list-timers fstrim.timer` shows the next slot — on this host Mondays ~00:43 MDT plus randomized delay); on a cheap NVMe such as Netac, each TRIM can park the controller for about 10 ms.
   - If no fstrim runs, inspect `/sys/fs/btrfs/<uuid>/discard/{discardable_extents,iops_limit}` for an async-discard backlog after mass deletion.

6. **Relieve the discard storm.**
   - For active fstrim, run `sudo systemctl stop fstrim.service`; it is advisory housekeeping and will run again in the next timer window.
   - For btrfs async discard, lower `discard/iops_limit` to a value such as 10 during the session, then restore it.
   - Move `fstrim.timer` to an idle `OnCalendar` slot and exclude giant game/asset trees from desktop indexing through `baloofilerc`.

## Traps / failure signatures

- Suspending an indexer such as baloo may reduce writes but will not clear a primary TRIM saturation; SIGSTOP it and remeasure before attributing the fix.
- `Meminfo` Dirty near zero plus a busy device argues against writeback.
- `mount -o remount,nodiscard` does not stop fstrim, and btrfs `discard/iops_limit` does not throttle fstrim; they are different paths.
- Drive-internal garbage collection is a last-resort explanation; check SMART wear percentage and temperature first.
- Long desktop uptime plus growing shell RSS/VRAM makes the compositor a better first suspect than game settings.

## Verification

1. After VRAM remediation, require a multi-gigabyte increase in free memory and no new NVRM/Xid lines.
2. After stopping fstrim or throttling btrfs discard, require diskstats busy below 20%.
3. Confirm PSI I/O `avg10` decays; it is a trailing average and can lag recovery by 30–60 seconds.
4. Recheck the running game only after the measured pressure source clears; do not credit an unrelated graphics-setting change.
