---
name: concise-response
description: Give concise lists of requested items, no extra text.
---
# Concise Response Skill

## Procedure
1. Detect the core request – look for cues that the user wants only raw data (e.g., "lista", "links", "skills", "repos", "only", "somente", "just", "give me", "provide", "output", "enumerate").
2. Prepare the output – if the request is solely for a collection of items, format as plain items, one per line, with no preamble or summary.
3. Avoid extra text – do not add introductory sentences, explanations, or meta‑commentary unless the user explicitly asks for context.
4. Optional summary – if the user also asks for a brief summary, place it after the list, separated by a blank line, but keep the list itself unadorned.

## Pitfalls
- Adding introductory phrases such as "Here is the list:" or "As requested," violates the request for concise output.
- Including extra metadata (file sizes, line counts, timestamps) unless explicitly requested.
- Mixing the list with unrelated commentary or step‑by‑step narration.

## Verification
Before sending, verify that the output contains only the requested data elements (e.g., URLs, skill names) and nothing else.
