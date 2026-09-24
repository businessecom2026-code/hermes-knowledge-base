---
name: ui-feel-audit
description: Use when UI "feels boxy/stiff" or workflow feels slow.
---

# UI feel audit

For complaints about how an interface *feels* rather than what it does: "too boxy",
"engessado/rigid", "looks like a spreadsheet", "the client needs a fast workflow",
"simulate a real user and tell me what to improve".

A feel complaint names a **symptom, not a cause**. Radius and padding are what everyone
reaches for first and are usually NOT the cause — especially in a codebase that already had
a spacing pass. Turn the complaint into a number before proposing anything.

If the repo also has an audit skill with a proof gate (e.g. `improve-ui`), use its
evidence discipline for reporting; this skill is the diagnostic layer that tells you WHERE
to look.

## 1. Locate the surface, then read its design primitives FIRST

Find the module that exports the shared class strings / tokens for the surface (a
`*-ui.tsx`, `tokens.ts`, `theme.*`) and read its comments before forming any opinion.

A prior deslopping pass with a recorded rationale makes a spacing or radius finding a
**regression**, not an improvement — and the comment usually names the constraint that pass
honored ("colour does not change", "contrast verified for protanopia"). Proposing against a
documented constraint is how an audit loses the user's trust in one line.

## 2. Census the surface: count signals, do not eyeball

Batch ONE shell loop over the few component files that own each module, normalising by total
lines so modules are comparable. Counting per file in separate calls wastes turns; the
comparison *between* modules is the finding.

| signal counted | near-zero means |
| --- | --- |
| `shadow-*` | every panel sits in one plane, separated only by 1px borders — the dominant source of "boxy / technical drawing" feel |
| `Skeleton` / structural placeholders | loading is a text swap, so each navigation repaints in one hard blink |
| `motion.` / entrance transitions | states appear instantly; nothing enters or leaves — reads as stiff |
| `transition` | interactive states give no feedback; hover/press feel dead |
| `rounded-(none\|sm\|md)` vs `rounded-(xl\|2xl\|full)` | which radius scale actually governs — check before claiming corners are the problem |
| `Cmd`/`Ctrl`/`kbd`/`cmdk` | zero = workflow is 100% mouse, the usual real cause of "slow" |
| `debounce` | search fires per keystroke or only on submit |
| `<input>`/`<select>`/`<textarea>` per form component | decisions-per-task — the actual speed ceiling |
| `aria-label`, `focus-visible`, `tabular-nums` | keyboard and data-legibility gaps in dense tables |

### 2a. A zero in a per-file grep is a HYPOTHESIS, not a finding

Grep the whole source tree for the CONCEPT before reporting any zero. A codebase that has
already had a cleanup pass extracts shared behaviour into a shared module or hook, so the
component file legitimately contains none of the token you counted — the behaviour is one
`import` line away. Reporting that zero tells the user their code lacks something it has,
which costs more trust than saying nothing.

The token names in the table above are English library idiom. In a codebase written in the
team's own language the same behaviour is named in that language, and every count comes
back zero while the feature is fully present:

| you grep for | may actually be named | found by |
| --- | --- | --- |
| `Skeleton` | `EsqueletoDeLista`, `Placeholder*` | grep the shared `*-ui.*` module's exports, then its import sites |
| `cmdk`, `<kbd>`, `metaKey` | `useAtalhosDeTela`, `useShortcuts` | grep `hooks/` for a keyboard hook, not components for key names |
| `debounce` | `useDebounced`, `useAtrasado` | grep for the state the search input feeds, and follow it |

So: resolve every candidate zero by (1) listing the shared UI module's exports, (2) grepping
`hooks/` and the tree for a same-meaning name, and only then calling it absent. Say which of
your own hypotheses the census killed — an audit that survives its own evidence unchanged
was not an audit.

### 2b. Count at the granularity the eye actually tracks

Elevation on the wrapper and elevation on the row are different findings, and a file-level
count merges them into one non-zero. In a list or table, grep the row element (`<tr`, the
repeated card) separately from its container: the usual real defect is a container that
lifts correctly around rows that have no hover, no `focus-visible`, and no banding, which
is exactly what makes a wide table read as a spreadsheet.

## 3. Read the census

- **Radius/padding already generous + `shadow-*` at zero** → the complaint is about **depth
  and separation**, not spacing. More padding here repeats work already done.
- **`transition` and entrance animation at zero** → the complaint is about **state change
  being instantaneous**; people call that "rigid" even when the static layout is fine.
- **Zero keyboard affordances + high field count** → "needs a fast workflow" is a
  **decisions-per-task** problem. Visual work will not move it; cutting, defaulting, or
  deferring fields and adding keyboard entry will.

## 3b. Dark theme: the shadow half of elevation does not exist

In a light theme, cast shadow does about half the work of lifting a card. On a dark
page it does **none** — black over near-black has nowhere to darken, and raising the
opacity or blur does not fix a physical impossibility. Elevation has to come from the
surface being **lighter** than the page, plus a white `inset` top edge as the light
catch; the cast shadow stays only for well-calibrated screens.

So do not port a light-theme reference's contrast ratio as a target. Copying the
*number* without the *conditions* that produced it yields a value that passes the
measurement and fails the eye: a light-theme reference at 1.10 needed ~1.38 in dark to
read as "landed" at all, because the surface degree now carries the elevation alone.

**When the measurement and the visual read disagree, the read decides.** The instrument
exists to stop silent regression, not to define the target — so pair every surface
measurement with a rendered look at the same screen before calling it done.

## 4. Report as counts, and separate proven from candidate

- Numbers, not adjectives: "18 fields for one entry", "1 `shadow-*` in 5029 lines" — not
  "the form is big".
- Static counts prove **absence** (no shadows, no skeletons, no shortcuts), which is enough
  to locate a cause. They cannot prove perceived hierarchy or density — keep those as
  candidates until the rendered surface is actually seen.
- When the user's stated hypothesis is wrong, say so with the counter-evidence in the same
  breath as the real cause. An audit that only confirms the hypothesis is worthless.

## 5. Wasted space and max-width constraints

When a user complains about "wasted space on desktop" or a layout feeling "squished", do not just make it `w-full` blindly. Find the `max-w-` token capping the container and read its rationale. Macro layout restrictions (like limiting a container's width so table rows don't become unreadably long) are often legitimate but misapplied to the wrong structural child (like a grid of cards or a calendar). 

1. **Calculate the exact pixel cost**: subtract the `max-w-` from the available window width (e.g. `1680 - 250 (menu) - 1152 (max-w-6xl) = 278px empty`).
2. **Measure what is squished inside**: divide the remaining width by the grid columns (e.g. 7 days in a calendar = 103px per day). The real cost of the empty space is what it forces the dense content to do.
3. **Check breakpoints against wrappers**: if a container uses `hidden xl:` (which triggers at 1280px) to hide columns on small screens, but the page wrapper is capped at `max-w-6xl` (1152px), those columns will NEVER render on desktop because the breakpoint is mathematically unreachable. The fix is to move the max-width up past the breakpoint line, honoring the layout intent without hiding the data.

## 6. "Simulate a client" means a logged-in walkthrough

A feel/workflow audit is not finished from source alone. It needs the real surface, which
usually needs a human login — set that up with the `browser-human-handoff` skill (the
agent's default browser is headless and shows the user nothing), and do the static census
while the human logs in instead of idling in a poll loop.

Count, on the live surface: clicks per primary task, fields before first save, time until
the first actionable pixel, and what is on screen during loading.
