---
name: react-form-engineering
description: Use when building, refactoring, or debugging React forms.
---

# React Form Engineering

Forms are where three validators disagree in silence: the browser (HTML5 `required`), the
component (JS checks before `fetch`), and the server (zod/schema). Nearly every "preenchi
tudo e não salva" bug is two of them holding contradictory rules with no message reaching
the screen. Work the pipeline in order.

## 1. Diagnose "não salva" before changing anything

Walk the three gates in this order and name which one is refusing:

1. **Browser gate** — does `onSubmit` even fire? If not, a `required` input is invalid and
   unfocusable. Chrome aborts the submit *silently* (console: `An invalid form control with
   name='x' is not focusable`) whenever a `required` field sits inside a wrapper with
   `display:none` / `hidden`. The button appears to do nothing.
   **Pitfall**: If the browser gate blocks you during testing because of invalid data (e.g. typing '101' into a `type="email"` field), fix your test data. **Never** modify the application source code to remove `required` or type constraints just to bypass a validation you failed to satisfy.
2. **Component gate** — an early `return` in the submit handler. Check that every early
   return releases *all* locks (see §3).
3. **Server gate** — a 4xx whose message the UI swallows. Different routes shape errors
   differently (`{error, issues}` vs `{error, details:{fieldErrors}}`); an error reader that
   only knows one shape prints a generic "não foi possível salvar" and hides the field name.

## 2. Multi-step / wizard forms

These rules are what make a wizard actually submit:

- **Hide steps with CSS, never with conditional unmount**, when submission reads
  `new FormData(event.currentTarget)`. `{etapa === 1 && <Campos/>}` removes the inputs from
  the DOM, so FormData silently drops every field of the inactive step and the payload
  arrives half-empty. Use `<div className={etapa === 1 ? 'block' : 'hidden'}>`.
- **Gate the "Próximo passo" button with `formRef.current?.reportValidity()`.** Hidden empty
  `required` fields from step 1 dead-lock the final submit; validating before the step is
  hidden turns a mute button into a visible browser tooltip on the offending field.
- **Send the user back to the step that owns the failing field.** When validation rejects
  `city` and the user is on step 1, `setEtapa(<step of field>)` first, then focus the input
  (a `setTimeout(..., 50)` after the state change, because focusing a still-hidden node
  does nothing).
- Keep the step state as narrow as the flow (`useState<1 | 2>(1)`) so an out-of-range step
  is a type error, not a blank screen.

## 3. The submit lock must always be released

A double-click guard (`gravandoAgora.current = true`) and a `setSalvando(true)` that disables
the button are both locks. Route **every** early exit through one `recusar()` helper that
shows the message *and* clears both:

```tsx
const recusar = (msg: string) => {
  setErro(msg);
  gravandoAgora.current = false;
  setSalvando(false);
};
```

Without this, one bounced validation freezes the form forever and only a page reload frees
it — the user reports it as "não salva por nada".

## 4. Do not ask the same question twice

When a select already answers a question (`Tipo: Cliente / Fornecedor / Outro`), a second
checkbox "este contato também é cliente" is redundant UI that gates real functionality
behind a click nobody understands. Derive it: `const ehCliente = tipo === 'CLIENT'`. Same
principle for a secondary drawer/`<details>` that re-asks for name, document and address
that the main form already collected — lift its *useful* parts (document upload / OCR
autofill) into the main form and delete the drawer.

Country-specific helper copy ("No Brasil o CEP preenche...") does not belong in a form that
ships to other countries — either branch it on the selected country or remove it.

## 5. Field limits must mirror the server

`maxLength` on the input and `max(n)` in the server schema are one number in two places. A
field that accepts 120 chars against a schema that validates 60 produces a generic 400 that
names no field. When changing one, change both.

When a block of fields is jointly optional (an address), the rule belongs to the **block**,
not the field: empty passes, complete passes, half-filled is rejected naming the missing
fields (`superRefine` in zod). Making each field individually optional lets half an address
into the database, which is worse than none because nobody rechecks a field that looks
filled.

## 6. Editing a large form file safely

JSX files of 1000+ lines resist scripted surgery. Rules learned the hard way:

- **Never reorder JSX blocks with a regex that matches an opening tag and a closing tag
  separately.** `indexOf('</Bloco>')` finds the *first* one, and slicing between mismatched
  indices duplicates the whole component — the file silently triples in size and still
  "looks right" in a tail.
- **After any scripted edit, verify before doing anything else:** `wc -l <file>` against the
  previous count and `git diff --stat`. A jump of thousands of lines means the script
  duplicated content; `git checkout <file>` and redo it in smaller, anchored steps.
- Prefer the `patch` tool with unique surrounding context over `sed`/`node -e`/`python -c`
  one-liners. When a heredoc is unavoidable, write the script to a file first
  (`cat << 'EOF' > patch.py`) — inline heredocs with backticks and `${}` get mangled by the
  shell and by JS template-literal parsing, and safety hooks block the noisy ones.
- Clean up the scratch scripts (`patch.py`, `fix.py`, `*.txt` dumps) before committing.

## 7. Before pushing a form fix

- `git status --porcelain` — untracked new files break the remote build with `TS2307`
  while the local tree compiles fine.
- `git diff package.json package-lock.json` — installing a package to unblock a local
  typecheck can silently **downgrade** an unrelated dependency. A downgraded lib breaks the
  remote build, the deploy never publishes, and the site keeps serving the previous bundle:
  the user reports "continua a mesma coisa" for a fix that was never deployed.
- Verify the deploy actually landed by comparing the hashed asset name before and after
  (`curl -s <site> | grep -oE 'assets/index-[^"]+\.js'`). Same hash = the build failed;
  say so instead of claiming it shipped.
- Report the finish with a clock time ("pronto às 13:46"), typical and worst case — not a
  duration.

## Red flags

- A `required` attribute anywhere that can be hidden.
- A submit handler with an early `return` that does not go through `recusar()`.
- A checkbox whose only job is to repeat a choice a select already made.
- A scripted edit followed by a commit with no `wc -l` / `git diff --stat` in between.
- Telling the user something is deployed without checking the served asset hash.
