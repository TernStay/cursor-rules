# TurnStay Backend Agent Instructions

## Project Context

This is a TurnStay backend microservice using:
- **Python 3.11** with **Poetry** for dependency management
- **FastAPI** for the web framework
- **SQLAlchemy 2.0** async ORM with **PostgreSQL**
- **Alembic** for database migrations
- **Descope** for authentication
- **Pydantic** for data validation
- **Row-Level Security (RLS)** for multi-tenant data isolation

## Core Principles

1. **Search before writing** - Look for existing patterns/utilities before creating new code
2. **Minimal changes** - Make the smallest effective change; avoid over-engineering
3. **Ask when unclear** - Don't guess requirements; ask for clarification
4. **Follow existing patterns** - Match the codebase's style and conventions

## Key Patterns

### Endpoints
- Use `CompanyAccess` for tenant-scoped data access
- Always include `response_model` in route decorators
- Use `HTTPException` for error responses

### Database
- Always use `AsyncSession`
- Use `selectinload` for relationships
- Commit then refresh for new objects

### Authentication
- Use `DescopeVerify().verify(token)` - never write custom JWT parsing
- Trust `request.scope["tenant_id"]` from middleware
- Use `check_permissions()` for authorization

### Testing
- Use pytest-asyncio with provided fixtures
- Always mock external services (Descope, payments, etc.)
- Follow Arrange-Act-Assert pattern

## Commands

```bash
./scripts/install_dependencies.sh  # Install deps
./scripts/db_migrate.sh            # Run migrations
poetry run pytest -v               # Run tests
poetry run ruff check .            # Lint
```

## Detailed Rules

See `.cursor/rules/` for comprehensive guidelines on specific topics.
