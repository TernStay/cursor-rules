# Python Backend Development Agent Instructions

## Project Context

This project uses Python for backend development with modern patterns and best practices. The specific technology stack may vary by project, but common patterns include:

- **Python 3.11+** with dependency management (Poetry/pip)
- **FastAPI** or similar web frameworks
- **SQLAlchemy** or similar ORMs for database access
- **Pydantic** for data validation
- **pytest** for testing

## Core Principles

1. **Search before writing** - Look for existing patterns/utilities before creating new code
2. **Minimal changes** - Make the smallest effective change; avoid over-engineering
3. **Ask when unclear** - Don't guess requirements; ask for clarification
4. **Follow existing patterns** - Match the codebase's style and conventions
5. **Type everything** - Use proper type hints throughout

## Key Patterns

### Code Organization
- Use clear, descriptive naming for variables and functions
- Keep functions focused on single responsibilities
- Organize imports following Python standards (stdlib, third-party, local)
- Use relative imports appropriately within packages

### Error Handling
- Use specific exception types rather than generic ones
- Provide meaningful error messages
- Handle edge cases gracefully
- Log errors appropriately without exposing sensitive information

### Testing
- Write tests for all public functions and methods
- Use descriptive test names that explain what is being tested
- Mock external dependencies to isolate unit tests
- Follow Arrange-Act-Assert pattern

## Commands

Common development commands (may vary by project):

```bash
pip install -r requirements.txt  # Install dependencies
python -m pytest                 # Run tests
python -m black .               # Format code
python -m flake8 .              # Lint code
python -m mypy .                # Type check
```

## Detailed Rules

See `.cursor/rules/` for comprehensive guidelines on specific topics and patterns.
