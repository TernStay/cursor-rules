# Pushing Cursor Rules to Multiple Repos (PR workflow)

## Idea

**Pull workflow (current):** Each project runs `install-rules.sh` to pull the latest rules from cursor-rules.

**Push workflow (this feature):** From the cursor-rules repo, you maintain a registry of repos and their rule type. When you change rules (e.g. Python), you run one script; it updates each matching repo with the new rules and opens a PR on each so you can review and merge.

**Human version:** “I changed the Python cursor rules. I want every Python service to get those changes. Instead of going to each repo and running the install script, I run one script here and get a PR on each of those repos with the updated rules.”

---

## What’s needed

### 1. Registry (source of truth for “which repo gets which rules”)

A config file in cursor-rules that lists:

- **Repo identifier** – e.g. `turnstay_api`, `secure_card_service`, `Dashboard-2.0`
- **Rule type** – `python` | `nextjs` (same as `install-rules.sh`)
- **GitHub repo** – org/repo or full URL for clone and PR creation

Example (`config/repos.json`):

```json
{
  "repos": [
    { "name": "turnstay_api", "rule_type": "python", "repo": "TernStay/turnstay_api" },
    { "name": "secure_card_service", "rule_type": "python", "repo": "TernStay/secure_card_service" },
    { "name": "Dashboard-2.0", "rule_type": "nextjs", "repo": "TernStay/Dashboard-2.0" }
  ]
}
```

`repo` can be `org/repo` or a full GitHub URL; the script normalizes to `org/repo` for clone and `gh pr create`.

The script reads this and, for each entry, applies the same rule set that `install-rules.sh <rule_type>` would (same files, same pruning of stale rules).

### 2. Script behavior

Script (e.g. `scripts/push-rules-to-repos.sh` or a small Python script) run **from cursor-rules repo root**:

1. **Load registry** – Read the config. By default only repos with `"enabled": true` (or missing `enabled`) are included; use `--all` to include disabled repos. Optionally filter by `--type` or `--repo`.
2. **For each repo:**
   - Clone the repo into a temporary directory (or reuse a workspace).
   - Copy rules from **local** cursor-rules into the clone:
     - For the repo’s `rule_type`: copy `python/` or `nextjs/` rules (same logic as install script: `.cursor/rules/*.mdc` + `AGENTS.md`), and remove any `.mdc` in the target that no longer exist in the source.
   - If there are no changes, skip (no commit, no PR).
   - If there are changes:
     - Create a branch (e.g. `chore/update-cursor-rules` or `cursor-rules-sync-YYYYMMDD`).
     - Commit (e.g. “chore: sync cursor rules from cursor-rules repo”).
     - Push the branch.
     - Open a PR (e.g. `gh pr create`) with a title/body that point back to cursor-rules (and optionally the commit or release).
3. **Summary** – Print which repos got a PR, which were skipped (no changes), and any errors.

### 3. Options and UX

- **`--dry-run`** – Don’t push or create PRs; only clone, apply rules, and report what would change.
- **`--type python`** – Only process repos with `rule_type: python`.
- **`--repo turnstay_api`** – Only process that one repo (by name in the registry).
- **`enabled`** – In config, set `"enabled": false` on a repo to exclude it from the push workflow; use `--all` to include disabled repos.
- **Branch name** – Fixed (e.g. `chore/update-cursor-rules`) so re-runs can update the same PR if the branch already exists.

### 4. Dependencies and environment

- **Git** – Clone and push.
- **GitHub CLI (`gh`)** – Create PRs; must be authenticated (`gh auth status`).
- **Push access** – The account used for `git push` and `gh pr create` must have push (and ideally PR create) rights on each target repo.
- **Run from cursor-rules root** – Script assumes it’s run from the repo root so it can find `config/repos.yaml` (or `.json`) and `python/`, `nextjs/`, `.cursor/rules/`.

### 5. Security and safety

- **No secrets in config** – Only repo identifiers and URLs; use `gh`/Git credentials for auth.
- **PRs, not direct push to main** – Pushing to a branch and opening a PR keeps main protected and gives a place to review and CI.
- **Dry-run** – Use `--dry-run` to confirm which repos would be updated before creating PRs.

---

## File layout

```
cursor-rules/
├── config/
│   └── repos.json          # Registry: repo name, rule_type, GitHub repo (org/repo)
├── scripts/
│   ├── install-rules.sh    # (existing) pull rules into current project
│   └── push-rules-to-repos.py   # push rules to registered repos and open PRs
└── docs/
    └── PUSH_RULES_TO_REPOS.md   # This doc
```

The script is Python (stdlib only, no PyYAML). Edit `config/repos.json` to add or remove repos; then run from cursor-rules root:

```bash
# All registered repos
python scripts/push-rules-to-repos.py

# Only Python repos
python scripts/push-rules-to-repos.py --type python

# One repo by name
python scripts/push-rules-to-repos.py --repo turnstay_api

# See what would change without pushing
python scripts/push-rules-to-repos.py --dry-run
```

---

## Summary

| Need | Solution |
|------|----------|
| List of repos and types | `config/repos.yaml` (or `.json`) |
| “Apply same rules as install” | Reuse install script’s copy/prune logic from local cursor-rules |
| Create PR per repo | Clone → copy rules → branch → commit → push → `gh pr create` |
| Filter (e.g. only Python) | `--type python`, `--repo name` |
| Safety | `--dry-run`; always open PR, never push to main |
| Auth | Git + `gh` CLI; user must have push access to each repo |

Once the registry and script are in place, the workflow is: edit Python (or Next.js) rules in cursor-rules → run the push script (optionally with `--type python`) → review and merge the opened PRs in each service.
