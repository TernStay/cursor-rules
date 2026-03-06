# Cursor rules config

## repos.json

- **`repos`** – All tracked repos. Each entry has:
  - **`name`** – Short identifier (e.g. `turnstay_api`).
  - **`rule_type`** – `python` (backend services), `nextjs` (React/frontend), `sdk` (Python SDKs), or `other` (tracking only; push script never sends rules to these).
  - **`repo`** – GitHub org/repo (e.g. `TernStay/turnstay_api`).
  - **`enabled`** – Optional, default `true`. Set to `false` to exclude the repo from the push workflow without removing it from the config. Use `--all` when running the script to include disabled repos.
- **`sdk_repos`** – SDK repos; they will get their own rule set later. Listed here for visibility and future use; the push script does not process them until we add an `sdk` rule type.

Repo names and `repo` values must match GitHub (e.g. `dashboard-2.0`, `webhook-service`).
