# TurnStay Cursor Rules

Centralized repository for Cursor IDE rules across all TurnStay projects. These rules ensure consistent AI-assisted development practices across our microservices.

## 📁 Structure

```
cursor-rules/
├── python/                    # Python/FastAPI backend rules
│   ├── AGENTS.md              # Simple markdown agent instructions
│   └── rules/                 # Structured rules (.cursor/rules format)
│       ├── turnstay-backend/  # Core development guidelines (always apply)
│       ├── api-endpoints/     # FastAPI endpoint patterns
│       ├── database-orm/      # SQLAlchemy & RLS patterns
│       ├── pydantic-schemas/  # Request/response schema patterns
│       └── testing/           # pytest patterns
│
├── nextjs/                    # Next.js frontend rules
│   ├── AGENTS.md              # Simple markdown agent instructions
│   └── rules/                 # Structured rules
│       ├── nextjs-core/       # Core Next.js guidelines
│       ├── components/        # React component patterns
│       ├── api-routes/        # API route patterns
│       └── styling/           # Tailwind/CSS patterns
│
├── scripts/
│   └── install-rules.sh       # Script to install rules in a project
│
└── README.md
```

## 🚀 Quick Start

### Option 1: Use the Install Script

```bash
# Install Python rules in a backend project
curl -sSL https://raw.githubusercontent.com/TernStay/cursor-rules/main/scripts/install-rules.sh | bash -s -- python

# Install Next.js rules in a frontend project
curl -sSL https://raw.githubusercontent.com/TernStay/cursor-rules/main/scripts/install-rules.sh | bash -s -- nextjs
```

### Option 2: Clone and Copy

```bash
# Clone this repo
git clone git@github.com:TernStay/cursor-rules.git ~/cursor-rules

# For Python projects
cp -r ~/cursor-rules/python/rules/ /path/to/project/.cursor/rules/
cp ~/cursor-rules/python/AGENTS.md /path/to/project/AGENTS.md

# For Next.js projects
cp -r ~/cursor-rules/nextjs/rules/ /path/to/project/.cursor/rules/
cp ~/cursor-rules/nextjs/AGENTS.md /path/to/project/AGENTS.md
```

### Option 3: Git Submodule (Advanced)

```bash
# Add as submodule
git submodule add git@github.com:TernStay/cursor-rules.git .cursor-rules

# Symlink the rules you need
ln -s .cursor-rules/python/rules .cursor/rules
```

## 📋 Rule Types

Each rule folder contains a `RULE.md` file with frontmatter that controls how it's applied:

| Type | Frontmatter | Behavior |
|------|-------------|----------|
| **Always Apply** | `alwaysApply: true` | Applied to every chat session |
| **File-Scoped** | `globs: ["**/*.py"]` | Applied when working with matching files |
| **Agent-Decided** | `description: "..."` | Agent decides based on context |
| **Manual** | No frontmatter | Only when @-mentioned |

## 🐍 Python Rules (FastAPI/SQLAlchemy)

For TurnStay backend microservices:

- **turnstay-backend**: Core guidelines, auth patterns, code style (always applies)
- **api-endpoints**: FastAPI endpoint structure, HTTP conventions
- **database-orm**: SQLAlchemy async patterns, RLS, migrations
- **pydantic-schemas**: Request/response validation patterns
- **testing**: pytest-asyncio patterns, fixtures, mocking

### Applies To

- `turnstay_api`
- `ledger`
- `recon`
- `payouts`
- `treasury`
- `secure_card_service`
- `webhook-service`

## ⚛️ Next.js Rules

For TurnStay frontend applications:

- **nextjs-core**: Core Next.js 14+ patterns, app router
- **components**: React component patterns, hooks
- **api-routes**: API route handlers
- **styling**: Tailwind CSS patterns

## 🔄 Keeping Rules Updated

### Manual Update

```bash
# From your project directory
cd /path/to/your/project
../cursor-rules/scripts/install-rules.sh python --update
```

### Automated (CI/CD)

Add to your CI pipeline to check for rule updates:

```yaml
- name: Check cursor rules
  run: |
    # Compare local rules with remote
    diff -r .cursor/rules/ <(curl -sL $RULES_URL/python/rules/)
```

## 🛠️ Contributing

1. Edit rules in this repository
2. Test in a project by copying locally
3. Create a PR with your changes
4. After merge, run install script in all projects

## 📖 Reference

- [Cursor Rules Documentation](https://cursor.com/docs/context/rules)
- [TurnStay Tech Stack](./docs/TECHNOLOGY_STACK.md)
- [TurnStay Design Patterns](./docs/DESIGN_PATTERNS.md)

## 🏷️ Versioning

We use tags for stable rule versions:

```bash
# Install specific version
curl -sSL https://raw.githubusercontent.com/TernStay/cursor-rules/v1.0.0/scripts/install-rules.sh | bash -s -- python
```
