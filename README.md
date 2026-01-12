# Cursor Rules

A meta-repository for building and distributing Cursor IDE rules. This project creates standardized development guidelines for various technology stacks and provides tools for rule installation and validation.

## 📁 Structure

```
cursor-rules/
├── python/                    # Python/FastAPI backend rules template
│   ├── AGENTS.md              # Agent instructions for Python projects
│   └── rules/                 # Python-specific .mdc rule files
│       ├── turnstay-backend.mdc  # TurnStay backend patterns (example)
│       ├── api-endpoints.mdc      # FastAPI endpoint patterns
│       ├── database-orm.mdc       # SQLAlchemy patterns
│       ├── pydantic-schemas.mdc   # Request/response validation
│       └── testing.mdc            # pytest patterns
│
├── nextjs/                    # Next.js frontend rules template
│   ├── AGENTS.md              # Agent instructions for Next.js projects
│   ├── nextjs-core.mdc        # Core Next.js guidelines
│   ├── components.mdc         # React component patterns
│   ├── api-routes.mdc         # API route handlers
│   └── styling.mdc            # Tailwind CSS patterns
│
├── .cursor/
│   └── rules/                 # Rules for this cursor-rules project
│       ├── cursor-rules.mdc       # Core cursor-rules development
│       ├── rule-development.mdc   # Rule writing patterns
│       ├── script-development.mdc # Script development patterns
│       ├── documentation.mdc      # Documentation patterns
│       └── testing.mdc            # Testing patterns
│
├── scripts/
│   └── install-rules.sh       # Script to install rules in target projects
│
├── docs/
│   ├── DESIGN_PATTERNS.md     # Design patterns guide
│   └── TECHNOLOGY_STACK.md    # Technology stack reference
│
└── README.md
```

## 🚀 Quick Start

### For Projects Using Rules

Install rules in your project:

```bash
# Install Python rules in a backend project
curl -sSL https://raw.githubusercontent.com/TernStay/cursor-rules/main/scripts/install-rules.sh | bash -s -- python

# Install Next.js rules in a frontend project
curl -sSL https://raw.githubusercontent.com/TernStay/cursor-rules/main/scripts/install-rules.sh | bash -s -- nextjs
```

### For Rule Development

Clone this repository to create or modify rules:

```bash
git clone https://github.com/TernStay/cursor-rules.git
cd cursor-rules
```

### Manual Installation

```bash
# Clone this repo
git clone https://github.com/TernStay/cursor-rules.git ~/cursor-rules

# For Python projects
mkdir -p /path/to/project/.cursor/rules/
cp ~/cursor-rules/python/rules/*.mdc /path/to/project/.cursor/rules/
cp ~/cursor-rules/python/AGENTS.md /path/to/project/AGENTS.md

# For Next.js projects
mkdir -p /path/to/project/.cursor/rules/
cp ~/cursor-rules/nextjs/*.mdc /path/to/project/.cursor/rules/
cp ~/cursor-rules/nextjs/AGENTS.md /path/to/project/AGENTS.md
```

### Option 3: Git Submodule (Advanced)

```bash
# Add as submodule
git submodule add git@github.com:TernStay/cursor-rules.git .cursor-rules

# Symlink the rules you need
mkdir -p .cursor/rules
ln -s ../.cursor-rules/python/rules/*.mdc .cursor/rules/
```

## 📋 Rule Types

Each rule is a `.mdc` file with frontmatter that controls how it's applied:

| Type | Frontmatter | Behavior |
|------|-------------|----------|
| **Always Apply** | `alwaysApply: true` | Applied to every chat session |
| **File-Scoped** | `globs: ["**/*.py"]` | Applied when working with matching files |
| **Agent-Decided** | `description: "..."` | Agent decides based on context |
| **Manual** | No frontmatter | Only when @-mentioned |

**Note:** Cursor 2.3+ uses `.mdc` files (not `RULE.md` in folders). The install script handles this automatically.

## 📋 Available Rule Templates

### Python Rules Template

A comprehensive set of rules for Python/FastAPI backend development:

- **turnstay-backend**: Core development guidelines and patterns
- **api-endpoints**: FastAPI endpoint structure and HTTP conventions
- **database-orm**: SQLAlchemy async patterns and database access
- **pydantic-schemas**: Request/response validation patterns
- **testing**: pytest patterns, fixtures, and mocking strategies

### Next.js Rules Template

Frontend development patterns for Next.js applications:

- **nextjs-core**: Core Next.js 14+ patterns and App Router conventions
- **components**: React component patterns and composition
- **api-routes**: API route handlers and server actions
- **styling**: Tailwind CSS patterns and styling conventions

### Cursor Rules Development

Rules for maintaining this cursor-rules project:

- **cursor-rules**: Core guidelines for rule development
- **rule-development**: Patterns for writing .mdc rule files
- **script-development**: Installation and validation script patterns
- **documentation**: Documentation writing and maintenance patterns
- **testing**: Testing patterns for rule validation

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
    diff -r .cursor/rules/ <(curl -sL https://raw.githubusercontent.com/TernStay/cursor-rules/main/python/rules/)
```

## 🛠️ Contributing

### Adding New Rules

1. **Identify the technology stack** the rule applies to
2. **Create the .mdc file** following the established format
3. **Add appropriate frontmatter** (name, description, globs/alwaysApply)
4. **Test the rule** in a sample project
5. **Update documentation** if needed

### Modifying Existing Rules

1. **Assess impact** on projects using the rule
2. **Maintain backward compatibility** where possible
3. **Update frontmatter** if the rule scope changes
4. **Test thoroughly** across different project types

### Pull Request Process

1. Create a PR with your rule changes
2. Include test results from sample projects
3. Update this README if adding new rule templates
4. Ensure CI checks pass

## 📖 Reference

- [Cursor Rules Documentation](https://cursor.com/docs/context/rules)
- [Technology Stack Guide](./docs/TECHNOLOGY_STACK.md)
- [Design Patterns Guide](./docs/DESIGN_PATTERNS.md)

## 🏷️ Versioning

We use tags for stable rule versions:

```bash
# Install specific version
curl -sSL https://raw.githubusercontent.com/TernStay/cursor-rules/v1.0.0/scripts/install-rules.sh | bash -s -- python
```
