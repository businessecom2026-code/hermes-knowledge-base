---
name: remote-repo-audit
description: "Audit a GitHub repo over gh API without cloning it."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [github, gh, audit, private-repo, reconnaissance, delivery-state, multi-account]
    category: software-development
    related_skills: [github, codebase-inspection]
---

# Remote repo audit (no clone)

Use when asked to open, inspect, verify or audit a GitHub repository — often
private, often on another person's account — that is NOT cloned locally
("o que tem nesse repo", "verifica o que está lá", "dá uma olhada no
repositório X"). Answers "what is in it and what state is it in" using only
`gh` API reads, then reports delivery state rather than commit history.

Do not clone: a clone costs minutes and disk on asset-heavy repos, and every
question below is answerable from the API.

For PR/issue/release *operations*, use the `github` skill. This skill is
read-only reconnaissance and the report that follows it.

## 0. Resolve the account before anything else

The user names the owner by **email**; `gh` knows only **logins**. Multiple
accounts commonly sit in the keyring at once and only one is active.

```bash
gh auth status                      # lists every account + which is active
gh auth switch --user <login>       # switch BEFORE any repo call
gh api user -q .login               # confirm who you now are
gh repo list <login> --limit 100    # private repos only appear for their owner
```

- Switch first, then read. A private repo queried under the wrong active
  account returns 404/empty and reads as "does not exist" — you will report
  the wrong thing.
- When the email maps to no obvious login, list repos of each authenticated
  account and match by repo name; do not ask the user to guess their login.
- Never print the token, even masked, back to the user.

## 1. Metadata and shape

```bash
R=<owner>/<repo>
gh repo view $R --json name,description,visibility,defaultBranchRef,pushedAt,\
createdAt,diskUsage,languages,isArchived,isFork,licenseInfo,homepageUrl
gh api repos/$R/git/trees/<default-branch>?recursive=1 \
  -q '.tree[] | "\(.type) \(.size // 0) \(.path)"'
```

- `homepageUrl` usually reveals the live deploy — say where it is published.
- Large `diskUsage` against small code is almost always binary assets
  (`public/`, `assets/`); call that out so size is not read as "big codebase".

## 2. Find where the work actually is — never trust the default branch

This is the step that changes the conclusion. A default branch can hold a stub
while the real system sits unmerged in a draft PR.

```bash
gh api repos/$R/branches --paginate -q '.[] | "\(.name)\t\(.commit.sha[0:8])"'
gh pr list -R $R --state all
gh issue list -R $R --state all
gh api repos/$R/compare/main...<branch> -q '"ahead: \(.ahead_by), files: \(.files|length)"'
gh api repos/$R/compare/main...<branch> -q '.files[] | "\(.status) +\(.additions)/-\(.deletions) \(.filename)"'
gh run list -R $R --limit 5
```

- Compare every non-default branch against the default before concluding what
  the project contains — the diff file list is the fastest map of a feature
  built but never merged.
- Cross-check `gh pr list --state all` for long-lived DRAFT PRs: green CI plus
  draft plus weeks of silence is a stalled delivery, and it is the single most
  useful thing to report.

## 3. Read files without cloning

```bash
gh api repos/$R/contents/<path> -q .content | base64 -d            # default branch
gh api "repos/$R/contents/<path>?ref=<branch>" -q .content | base64 -d
```

Read these first — they carry the project's own verdict on itself and beat any
inference from code:

| File pattern | What it answers |
|---|---|
| `README.md`, `package.json` | stack, scripts, real name vs repo name |
| `docs/**/STATUS*`, `PLANO*`, `BACKLOG*` | which phases are done vs pending |
| `docs/**/AUDITORIA*`, `CHECKLIST*` | the team's own blocker list with priorities |
| `DECISOES-PENDENTES*`, ADRs | open business decisions blocking delivery |
| `.gitignore`, `.env.example` | whether secrets are actually excluded |

Read the branch copy of the status/decision docs too — it is usually more
recent than the merged copy.

## 4. Secret-exposure check (always, on every private repo audit)

Do not just look for keys; confirm the mechanism that keeps them out:

- `.gitignore` covers `.env`, `.env.*`, `*.pem`, `*.key`, `*.p12`.
- `.env.example` files contain placeholders only, never real hosts or keys.
- No PII or spreadsheet dumps committed (check `docs/`, `data/`, `public/`).

Report this explicitly even when clean — for a private repo it is a question
the user has but does not ask.

## 5. Report by product state, not by commit log

The user reads the answer as "what do I have and can I ship it". Open with
what the system IS and where the work stands; commits and SHAs are evidence,
not structure.

Order that works:

1. One line: repo identified, access confirmed, visibility, last push, deploy URL.
2. **Where the work lives** — branch table (default vs feature), open/draft PRs, CI state.
3. What is inside, by product module in plain language (landing, CRM, automation, docs) — not as a directory listing.
4. Findings that change a decision, numbered: stalled PR, open P0 blockers from the repo's own audit, unresolved business decisions, security posture, known vulnerabilities.
5. Close by offering the next concrete step (open a specific file, or run the review chain on the stalled PR).

Rules:
- Never lead with commit hashes or a chronological log — it reads as if the
  wrong place was inspected.
- Quote the repo's own numbers (rows imported, P0 count, phases done) instead
  of your impression of maturity.
- Distinguish "code exists" from "deployed and working", because green CI on an
  unmerged branch is neither.

## Pitfalls

- Keep each `terminal` call short and single-purpose: long chained commands with
  many `echo`/`for` sections can exceed the local safety-hook evaluation window
  and come back unverified, costing a full retry. Split by subject (metadata,
  branches, files) instead of one mega-command.
- Native tools (`gh`, `git`) on Windows do not accept MSYS `/c/...` paths; pass
  `C:/...` style paths or rely on the shell builtin `cd`.
- `gh search repos <term> --owner <login>` is reliable only when that owner is
  the *active* account — otherwise prefer `gh repo list <login>`.
