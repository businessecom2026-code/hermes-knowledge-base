# Hermes TUI dies silently and the terminal fills with mouse codes

Two distinct problems that always appear together and get mistaken for one. Diagnose and fix both;
fixing only the visible one guarantees the crash repeats.

## Symptom A (visible): `^[[<35;12;31M` spam

Every mouse move over the terminal prints SGR mouse-report coordinates as literal text. Harmless in
itself — the TUI died without restoring DEC modes, so mode 1003 (report ALL motion, no button held)
stayed armed and the terminal now reports the cursor to whatever reads stdin next: the shell, or a
freshly relaunched TUI mid-init.

## Symptom B (real): the TUI was killed, not exited

Always check this before touching the terminal. The spam only tells you the TUI did not exit cleanly.

## Diagnostic order

Read logs under `$LOCALAPPDATA/hermes/logs/` (Windows) / `~/.local/share/hermes/logs/`:

1. `tui_gateway_crash.log` — the Node parent's own lifecycle log.
   - `=== gateway exit · <ts> · reason=stdin EOF (peer closed) ===` with no exception above it means
     the parent was killed from OUTSIDE. Node never ran a handler, so there is nothing else to find
     here — move to memory. This is the signature of an OS OOM kill.
   - `uncaughtException: Error: write EPIPE` / `EIO` means the PTY died first (tab closed, SSH
     dropped). Different cause: the terminal went away, not memory.
   - Windows exit codes: `3221225786` = 0xC000013A = Ctrl+C / console close. `4294967295` = -1,
     generic abnormal.
2. `agent.log` — confirm the last API call timestamp lines up with the exit, and read the `in=` token
   count. A session running at 150k–190k input tokens holds a large render tree and transcript in
   the Node heap.
3. `errors.log` — rule out an unrelated crash loop.

## Root cause: the heap ceiling is sized for the container, not the machine

`hermes_cli/main_tui_launch.py` appends `--max-old-space-size=8192` to `NODE_OPTIONS` unless the user
already set one. `ui-tui/src/lib/memoryMonitor.ts` then derives its graceful-exit thresholds as a
PERCENTAGE of that ceiling — critical ~88%, high ~70%. On a machine that cannot supply 8GB the V8
limit is never approached, so the monitor never fires, the TUI never exits gracefully, and the OS
reaps the process with no log and no OOM event.

`_resolve_tui_heap_mb()` only shrinks the ceiling from a **cgroup** limit. On bare-metal Windows and
macOS there is no cgroup, so it always returns the full 8192 regardless of installed RAM.

**Rule: set `NODE_OPTIONS=--max-old-space-size=<MB>` in `$HERMES_HOME/.env` to roughly 20% of
installed RAM (e.g. 3072 on a 16GB machine) on any non-containerized host.** The token-level merge in
the launcher respects a user-supplied value, so this wins over the 8192 default. Below the ceiling the
monitor's warn/critical path actually fires and the TUI exits cleanly with a heap dump instead of
vanishing.

Check free RAM before blaming the config — a browser holding 1.3GB across two processes is often the
difference between surviving and being reaped.

## Fix Symptom A permanently: drop DEC 1003

Set in `config.yaml`:

```yaml
display:
  mouse_tracking: buttons
```

Presets (`ui-tui/packages/hermes-ink/src/ink/termio/dec.ts`):

| preset | DEC modes | keeps | drops |
|---|---|---|---|
| `off` | none | terminal-native selection + scroll | all TUI mouse |
| `wheel` | 1000+1006 | click, wheel | drag, hover |
| `buttons` | 1000+1002+1006 | click, wheel, drag-select | hover |
| `all` (default) | +1003 | hover-driven UI | — |

`buttons` is the right default on any host where the TUI has crashed before: it costs only
hover-triggered UI (scrollbar paginate-on-hover, link mouseenter) and makes the spam structurally
impossible, because 1003 is never armed in the first place.

`hermes config set display.mouse_tracking buttons` rejects the key as unrecognized — it is a valid
run-time key without a schema entry. **Append `--force`**; it writes correctly and
`hermes config get` reads it back. Do NOT edit `config.yaml` with the file tools: writes to the
Hermes config are refused by design.

`/mouse buttons` inside a live TUI sets the same value for the session and persists it.

## Immediate recovery on a poisoned terminal

`reset` alone is unreliable under git-bash/MSYS on Windows. Emit the full DEC reset — the same
sequence `ui-tui/src/lib/terminalModes.ts` writes on exit. Ship it as a script rather than retyping:

```bash
printf '\033[?1003l\033[?1002l\033[?1000l\033[?1006l\033[?1015l\033[?1005l'
printf '\033[?9l\033[?1004l\033[?2004l\033[?1049l\033[0m\033[?25h\033[2J\033[H'
```

## Both fixes need a TUI restart

`NODE_OPTIONS` is read only when Node is spawned; `mouse_tracking` only at interface boot. Say this
explicitly — a user who applies the fix and keeps the dead session open will hit the bug again and
conclude the fix did not work.
