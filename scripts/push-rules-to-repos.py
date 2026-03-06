#!/usr/bin/env python3
"""
Push cursor rules to registered repos and open a PR on each.

Run from cursor-rules repo root. Reads config/repos.json for the list of
repos and their rule_type; for each repo, applies the same rules as
install-rules.sh would, then creates a branch, commits, pushes, and opens a PR.

Usage:
  python scripts/push-rules-to-repos.py [--dry-run] [--type python|nextjs] [--repo NAME] [--all] [--https]
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


# Branch and PR defaults
BRANCH_NAME = "chore/update-cursor-rules"
PR_TITLE = "chore: sync cursor rules from cursor-rules repo"
PR_BODY_TEMPLATE = """Syncs Cursor IDE rules from the central [cursor-rules](https://github.com/TernStay/cursor-rules) repo.

- Updates `.cursor/rules/*.mdc` and `AGENTS.md` for this project's rule type.
- No functional code changes.
"""


def find_cursor_rules_root() -> Path:
    """Resolve cursor-rules repo root (must have config/repos.json and python/ or nextjs/)."""
    root = Path(os.environ.get("CURSOR_RULES_ROOT", os.getcwd())).resolve()
    if not (root / "config" / "repos.json").exists():
        raise SystemExit("config/repos.json not found. Run from cursor-rules repo root or set CURSOR_RULES_ROOT.")
    if not (root / "python").is_dir() and not (root / "nextjs").is_dir():
        raise SystemExit("cursor-rules root must contain python/ or nextjs/. Run from cursor-rules repo root.")
    return root


def load_config(root: Path) -> list[dict]:
    """Load config/repos.json and return list of repo entries (enabled only, unless --all)."""
    with (root / "config" / "repos.json").open() as f:
        data = json.load(f)
    repos = data.get("repos", data)
    if not isinstance(repos, list):
        raise SystemExit("config/repos.json must have a 'repos' array.")
    return repos


def is_repo_enabled(entry: dict) -> bool:
    """True if repo is enabled. Missing 'enabled' is treated as True."""
    return entry.get("enabled", True)


def collect_source_mdc_basenames(root: Path, rule_type: str) -> set[str]:
    """Same rule set as install script: rule_type/rules, rule_type (top-level), .cursor/rules."""
    basenames: set[str] = set()
    for part in [
        root / rule_type / "rules",
        root / rule_type,
        root / ".cursor" / "rules",
    ]:
        if part.is_dir():
            for f in part.glob("*.mdc"):
                if f.is_file():
                    basenames.add(f.name)
    return basenames


def copy_rules_into(target_root: Path, cursor_rules_root: Path, rule_type: str) -> None:
    """Copy rules and AGENTS.md from cursor-rules into target repo; remove stale .mdc files."""
    rules_dir = target_root / ".cursor" / "rules"
    rules_dir.mkdir(parents=True, exist_ok=True)

    source_basenames = collect_source_mdc_basenames(cursor_rules_root, rule_type)

    # Copy .mdc from rule_type/rules
    for src in (cursor_rules_root / rule_type / "rules").rglob("*.mdc"):
        if src.is_file():
            (rules_dir / src.name).write_text(src.read_text())

    # Copy .mdc from rule_type (top-level only)
    rule_type_dir = cursor_rules_root / rule_type
    if rule_type_dir.is_dir():
        for src in rule_type_dir.glob("*.mdc"):
            if src.is_file():
                (rules_dir / src.name).write_text(src.read_text())

    # Copy .mdc from .cursor/rules
    cr_rules = cursor_rules_root / ".cursor" / "rules"
    if cr_rules.is_dir():
        for src in cr_rules.glob("*.mdc"):
            if src.is_file():
                (rules_dir / src.name).write_text(src.read_text())

    # Remove stale .mdc in target
    if rules_dir.exists():
        for f in rules_dir.glob("*.mdc"):
            if f.name not in source_basenames:
                f.unlink()

    # AGENTS.md
    agents_src = cursor_rules_root / rule_type / "AGENTS.md"
    if agents_src.is_file():
        (target_root / "AGENTS.md").write_text(agents_src.read_text())


def run(cmd: list[str], cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=cwd or None, check=check, capture_output=True, text=True)


def run_visible(cmd: list[str], cwd: Path | None = None) -> None:
    subprocess.run(cmd, cwd=cwd or None, check=True)


def has_changes(repo_path: Path) -> bool:
    run(["git", "update-index", "-q", "--refresh"], cwd=repo_path)
    r = run(["git", "diff-index", "--quiet", "HEAD", "--"], cwd=repo_path, check=False)
    return r.returncode != 0


def main() -> None:
    parser = argparse.ArgumentParser(description="Push cursor rules to registered repos and open PRs.")
    parser.add_argument("--dry-run", action="store_true", help="Clone and apply rules only; do not push or create PRs.")
    parser.add_argument("--type", choices=["python", "nextjs"], help="Only process repos with this rule_type.")
    parser.add_argument("--repo", metavar="NAME", help="Only process the repo with this name in the registry.")
    parser.add_argument("--all", action="store_true", help="Include repos that have \"enabled\": false in config.")
    parser.add_argument("--https", action="store_true", help="Use HTTPS for clone/push (default: SSH, to avoid keychain prompts).")
    args = parser.parse_args()

    root = find_cursor_rules_root()
    repos = load_config(root)

    if not args.all:
        repos = [r for r in repos if is_repo_enabled(r)]
    # Only python and nextjs receive rules; other rule_types are tracking-only
    repos = [r for r in repos if r.get("rule_type") in ("python", "nextjs")]
    if args.type:
        repos = [r for r in repos if r.get("rule_type") == args.type]
    if args.repo:
        repos = [r for r in repos if r.get("name") == args.repo]
        if not repos:
            print(f"No repo named '{args.repo}' in config.", file=sys.stderr)
            sys.exit(1)

    if not repos:
        print("No repos to process after filtering.")
        return

    print(f"Processing {len(repos)} repo(s). Dry-run={args.dry_run}\n")

    results = {"pr_created": [], "skipped_no_changes": [], "error": []}

    for entry in repos:
        name = entry.get("name", "?")
        rule_type = entry.get("rule_type")
        repo_spec = entry.get("repo", "").strip()
        if not repo_spec or not rule_type:
            results["error"].append((name, "missing rule_type or repo"))
            continue
        # Normalize to org/repo
        if repo_spec.startswith("https://github.com/"):
            repo_spec = repo_spec.rstrip("/").replace("https://github.com/", "")
        elif repo_spec.startswith("git@github.com:"):
            repo_spec = repo_spec.rstrip("/").replace("git@github.com:", "").replace(".git", "")

        # Use SSH by default to avoid repeated macOS keychain prompts (git-credential-osxkeychain)
        if args.https:
            clone_url = f"https://github.com/{repo_spec}.git"
        else:
            clone_url = f"git@github.com:{repo_spec}.git"
        print(f"→ {name} ({rule_type}) {repo_spec}")

        with tempfile.TemporaryDirectory(prefix="cursor-rules-push-") as tmp:
            clone_path = Path(tmp) / "repo"
            try:
                run(["git", "clone", "--depth", "1", "--quiet", clone_url, str(clone_path)])
            except subprocess.CalledProcessError as e:
                results["error"].append((name, f"clone failed: {e.stderr or e.stdout}"))
                continue

            copy_rules_into(clone_path, root, rule_type)

            if not has_changes(clone_path):
                print(f"  Skipped (no changes)")
                results["skipped_no_changes"].append(name)
                continue

            if args.dry_run:
                run_visible(["git", "status", "--short"], cwd=clone_path)
                print(f"  [dry-run] Would create branch, commit, push, and open PR.")
                continue

            # Create branch, commit, push, PR
            run(["git", "checkout", "-b", BRANCH_NAME], cwd=clone_path)
            run(["git", "add", ".cursor/rules", "AGENTS.md"], cwd=clone_path)
            run(["git", "commit", "-m", "chore: sync cursor rules from cursor-rules repo"], cwd=clone_path)
            run(["git", "fetch", "origin", BRANCH_NAME], cwd=clone_path, check=False)
            push_result = run(["git", "push", "-u", "origin", BRANCH_NAME], cwd=clone_path, check=False)
            if push_result.returncode != 0 and "rejected" in (push_result.stderr or ""):
                # Branch exists on remote; rebase and push, or re-apply rules and force-push
                rebase_result = run(
                    ["git", "pull", "--rebase", "origin", BRANCH_NAME], cwd=clone_path, check=False
                )
                if rebase_result.returncode != 0:
                    run(["git", "rebase", "--abort"], cwd=clone_path, check=False)
                    reset_result = run(["git", "reset", "--hard", f"origin/{BRANCH_NAME}"], cwd=clone_path, check=False)
                    if reset_result.returncode != 0:
                        push_result = reset_result  # report ref not found
                    else:
                        copy_rules_into(clone_path, root, rule_type)
                        run(["git", "add", ".cursor/rules", "AGENTS.md"], cwd=clone_path)
                        run(["git", "commit", "-m", "chore: sync cursor rules from cursor-rules repo"], cwd=clone_path)
                        push_result = run(["git", "push", "--force-with-lease", "origin", BRANCH_NAME], cwd=clone_path, check=False)
                else:
                    push_result = run(["git", "push", "origin", BRANCH_NAME], cwd=clone_path, check=False)
            if push_result.returncode != 0:
                results["error"].append((name, f"push failed: {push_result.stderr or push_result.stdout}"))
                continue

            # gh pr create (--head so gh uses the branch we pushed when GH_REPO is set)
            env = os.environ.copy()
            env["GH_REPO"] = repo_spec
            try:
                subprocess.run(
                    [
                        "gh", "pr", "create",
                        "--title", PR_TITLE,
                        "--body", PR_BODY_TEMPLATE,
                        "--head", BRANCH_NAME,
                    ],
                    cwd=clone_path,
                    env=env,
                    check=True,
                )
            except subprocess.CalledProcessError as e:
                results["error"].append((name, f"gh pr create failed: {e.stderr or e.stdout}"))
                continue

            results["pr_created"].append(name)
            print(f"  PR created.")

    # Summary
    print()
    if results["pr_created"]:
        print(f"PRs created: {', '.join(results['pr_created'])}")
    if results["skipped_no_changes"]:
        print(f"Skipped (no changes): {', '.join(results['skipped_no_changes'])}")
    if results["error"]:
        for name, msg in results["error"]:
            print(f"Error {name}: {msg}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
