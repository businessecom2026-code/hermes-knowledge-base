---
name: browser-human-handoff
description: Use when the human must log in or see the browser.
---

# Browser human handoff

For any task where the human must SEE and USE the browser themselves: login walls, captcha
(Turnstile/reCAPTCHA), 2FA, bank/SSO consent, "open X so I can log in and you watch".

The agent's default browser session is **headless** (`--headless=new`, temp profile
`agent-browser-chrome-<uuid>`). It renders nothing on screen. Any task that ends with
"…and then I log in" fails silently in it: the agent sees the page, the human sees nothing.

Run this procedure BEFORE telling the user to log in.

## 0. Detect that you are headless

```python
js("navigator.userAgent")   # contains 'HeadlessChrome' -> nothing is on screen
```

Do NOT use CDP window bounds as evidence of visibility. `Browser.getWindowForTarget`
happily reports `{'width':1280,'height':720,'windowState':'normal'}` for a headless
window that does not exist, and `Page.bringToFront` returns success. Both are lies for
this purpose — only the UA and the OS window list tell the truth.

## 1. Free the port and drop the headless browser

```bash
~/AppData/Local/hermes/bin/browser-use --reload    # stops the daemon
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='chrome.exe'\" | Where-Object { \$_.CommandLine -match 'agent-browser-chrome' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force -ErrorAction SilentlyContinue }"
```

Match on the temp profile name, never on `chrome.exe` alone — the user's own Chrome, with
their tabs and sessions, is in that process list too.

## 2. Launch a visible Chrome with a debug port

```bash
"/c/Program Files/Google/Chrome/Application/chrome.exe" \
  --remote-debugging-port=9222 \
  --user-data-dir="C:/Users/<user>/AppData/Local/Temp/<task>-visible-profile" \
  --no-first-run --no-default-browser-check \
  --window-size=1500,950 --window-position=60,30 \
  "<url>" >/dev/null 2>&1 &
```

- **A fresh `--user-data-dir` is mandatory.** Launching against the user's normal profile
  while their Chrome is already running only opens a tab in that existing process and the
  debug port never binds — `curl` then refuses and you conclude wrongly that the launch failed.
- Pass `--user-data-dir` as a **native forward-slash path** (`C:/Users/...`). Chrome is a
  native program and MSYS path translation is off, so `/c/Users/...` is not understood.
- Give explicit `--window-size`/`--window-position`, so you can later name the exact window
  the user should click into.

Verify the port is real Chrome, not headless:

```bash
curl -s http://127.0.0.1:9222/json/version   # "Browser": "Chrome/NNN"  (never 'HeadlessChrome')
```

## 3. Point the agent at that window

Export `BU_CDP_URL` **in the same shell command that runs browser-use**:

```bash
export BU_CDP_URL=http://127.0.0.1:9222 && ~/AppData/Local/hermes/bin/browser-use <<'PY'
ensure_real_tab()
print(page_info())
PY
```

Setting `os.environ['BU_CDP_URL']` inside the browser-exec code does NOT reach the daemon
that is already running — it keeps serving the headless browser and, worse, respawns a new
headless Chrome on the next call. Confirm the switch took by the viewport: `page_info()`
must report the real window size (e.g. 1484x855 for a 1500x950 window), not the headless
default. Every later call needs the same env var.

## 4. Prove the human can SEE it before asking them to act

A window can be `IsWindowVisible=True` and still be invisible: minimized, on another
virtual desktop, or behind a locked screen. Ask the OS, per chrome PID:
`GetForegroundWindow` + `GetWindowText`, then `IsWindowVisible`, `IsIconic`, `GetWindowRect`.

Read the result like this:

| OS says | meaning | action |
| --- | --- | --- |
| `IsIconic=True` | minimized — the usual cause of "I don't see any window" | `ShowWindow(h, 9)` then `SetWindowPos` then `SetForegroundWindow` |
| foreground title is the lock screen / screensaver | the machine locked, nothing is visible to anyone | tell the user to unlock, and STOP polling |
| rect at `0,0-0,0` | GPU/helper process, not a real window | ignore it |
| two chrome PIDs with the same page title | one is the user's own Chrome without a debug port | name position+size of YOUR window so they log into the one you can read |

A poll loop that keeps printing `/login` is evidence about the WINDOW, not about the user's
speed. After ~2 minutes of no change, stop polling and re-verify window state — minimized,
locked, or wrong-window is nearly always the answer.

## 5. Hand over, then resume

- Say in one line which window, and what you need: "the 1500x950 window at 60,30 — log in there".
- Never type a password, card number, or one-time code. Captcha and 2FA are the human's by
  design: use `browser_vault_*` for saved credentials and `browser_vault_enter_code` for codes.
- Use the wait productively: run the static/code half of the task while the human logs in,
  instead of burning turns on a sleep loop.
- Poll for the handoff with a cheap signal (`js("location.pathname")`), and treat "still on
  the login path" as a trigger for step 4, not for a longer sleep.

## Cleanup

The visible Chrome and its temp profile persist until killed. Close it when the task ends
(or say it is still open), so the next session does not attach to a stale window.
