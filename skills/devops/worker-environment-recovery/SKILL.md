---
name: worker-environment-recovery
description: Use when the Hermes TUI/terminal dies on its own, when the terminal fills with mouse-code garbage like ^[[<35;12;31M, or when workers fail repeatedly with HTTP 502/400, SSE stream endings, or "pid gone" crashes. Diagnoses and fixes unstable dev environments and silent TUI deaths, preventing wasted quota on retries.
---

## Procedure

1. **Diagnose environment instability**
   - When a worker card shows repeated crashes (exit code non-zero, "pid gone", or HTTP 502/400 in logs) for the same task:
   - Check for orphaned processes consuming dev ports:
     ```bash
     ps aux | grep -E "node|vite"
     ```
   - Common ports to verify: 5173 (Vite dev server), 3000 (alternative dev server)

2. **Terminate orphaned processes**
   - For each orphaned PID found:
     ```bash
     kill -9 <PID>
     ```
   - If unsure, restart the terminal session or development environment to clear all user processes.

3. **Clear development caches**
   - Remove Vite and Node module caches that may cause conflicts:
     ```bash
     rm -rf node_modules/.vite
     rm -rf .vite
     ```
   - Optional: clear npm cache if corruption suspected
     ```bash
     npm cache clean --force
     ```

4. **Verify dependency integrity**
   - Reinstall lockfile-consistent dependencies in an isolated terminal:
     ```bash
     npm ci
     ```
   - Ensure no `ERR!` errors; if present, check network or registry access.

5. **Confirm dev server stability**
   - Start the development server manually to verify it binds correctly:
     ```bash
     npm run dev
     ```
   - Wait for readiness signal (e.g., "ready in Xms" or "Local: http://localhost:5173")
   - Leave this running in a separate terminal/test pane.

6. **Retrigger the worker**
   - Do not manually rerun the worker; instead:
   - Ensure the original kanban card is in `ready` state (it will auto-promote when environment is stable)
   - The Hermes dispatcher will pick it up on its next tick (default 60s)
   - Monitor logs for successful test execution.

7. **When the crash is the Hermes TUI itself, not the app under test**
   - Read `$LOCALAPPDATA/hermes/logs/tui_gateway_crash.log` before anything else. A line
     `=== gateway exit · <ts> · reason=stdin EOF (peer closed) ===` with NO preceding exception means
     the Node parent was killed from outside — the TUI never got to log. Follow
     `references/hermes-tui-crash.md` for the full procedure.

## Pitfalls

- **Never retry without environment fix**: Repeatedly spawning workers on an unstable environment wastes quota, delays resolution, and may corrupt shared caches. Always stabilize the environment first.
- **Don't assume code failure**: HTTP 502/400 or SSE errors in worker logs typically indicate proxy/dev server issues, not application code bugs. Verify environment before opening correction cards.
- **Check all dev ports**: Orphaned processes may use non-standard ports (e.g., 5174 if 5173 is busy). Scan for any node/vite processes, not just known ports.
- **Cache persistence**: `node_modules/.vite` survives `git checkout` and can cause stale build issues; clear it explicitly when switching branches.
- **Manual dev server test is required**: `npm ci` succeeding does not guarantee the dev server will start; port conflicts or filesystem watches can still fail.
- **Dispatcher handles retrigger**: Once the environment is stable, the blocked worker card will auto-retry via the dispatcher—manual intervention breaks the kanban flow.
- **TUI Mouse Spam / ANSI artifacts**: Raw SGR sequences like `^[[<35;12;31M` flooding the prompt on every mouse move are a SYMPTOM, not the failure — a TUI died without running its mode-reset, leaving DEC 1003 (all-motion mouse reporting) armed, so the terminal now narrates the cursor into whatever reads stdin. Treat the spam as evidence the TUI was KILLED rather than exited, and diagnose the death (see `references/hermes-tui-crash.md`); clearing the screen alone guarantees a repeat. Restore the terminal with the full DEC reset in that reference, not `reset` alone — `reset` does not reliably clear 1003 under git-bash/MSYS on Windows.
- **Bypassing unavailable browser tools**: If browser tools drop off (CDP disconnects or `[WinError 1225]`), do NOT attempt to script `browser-use` manually via terminal. A disconnected CDP means the browser is genuinely unreachable; manual python scripts will fail with JS evaluation errors or hang the gateway process. Have the user restart the browser environment.

## Related Skills

- `devops/cadeia-kanban-hermes`: For writing effective kanban cards that avoid environmental false positives
- `dev/tdd`: For writing tests that don't flake due to environmental dependencies
- `security/appsec-audit`: If environment issues stem from security tools blocking dev server
