---
description: "Core TurnStay backend development guidelines - Python, FastAPI, SQLAlchemy patterns"
alwaysApply: true
---

# TurnStay Backend Development Guidelines

You are working on a TurnStay backend microservice - a Python FastAPI application with:
- SQLAlchemy 2.0 async ORM with PostgreSQL
- Alembic for database migrations
- Descope for authentication (JWT session tokens and access keys)
- Pydantic for request/response validation
- Poetry for dependency management
- Row-Level Security (RLS) for multi-tenant data isolation

## General Development Guidelines

### Search & Reuse First
Before writing new code, search the codebase for existing functionality. Reuse or extend existing functions, patterns, or internal libraries (`turnstay-ledger-client`, `turnstay-recon-client`, `turnstay-common`) instead of duplicating logic.

### Plan Minimal Changes
Aim for the smallest effective code change. Break complex tasks into smaller parts. Avoid over-engineering; keep solutions simple and focused. Do not add features, refactor code, or make "improvements" beyond what was asked.

### No Unfounded Assumptions
Only rely on given context (code, docs, user input). If information is missing or requirements are unclear, ask for clarification rather than guessing.

### Critical Thinking
Do not automatically agree with everything. If a proposed solution has flaws or can be improved, politely point it out and suggest a better approach. Prioritize correctness and clarity.

## Code Style & Organization

### Naming Conventions
- Variables/functions: `snake_case`
- Classes: `PascalCase`
- Constants: `SCREAMING_SNAKE_CASE`
- Endpoint modules: plural resource names (`accounts.py`, `payment_intents.py`)
- Test files: `test_{resource}.py`
- Utility files: `{domain}_utils.py`

### Import Organization
Keep imports sorted and grouped in this order:
1. Standard library (alphabetical)
2. Third-party packages (alphabetical)
3. Local imports - core modules
4. Local imports - API modules
5. Local imports - models and schemas

```python
# Standard library
import datetime
from collections.abc import AsyncGenerator

# Third-party packages
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

# Local imports - core
from app import constants, settings
from app.core.auth.descope import get_token_from_request

# Local imports - API
from app.api import deps
from app.api.utils.db_utils import refresh_and_return

# Local imports - models/schemas
from app.models import Account, Company
from app.schemas.requests import AccountCreateRequest
from app.schemas.responses import AccountResponse
```

### Code Quality
- Write self-explanatory code with clear naming; minimize inline comments
- Keep functions focused (Single Responsibility Principle)
- Aim for files < 300 lines; refactor if larger
- All code must pass Black formatting and Ruff linting
- Type hints are required for all function signatures
- Never hard-code secrets; use `settings.X` for configuration

## Authentication & Authorization

### Descope Integration
- All authentication uses Descope; never write custom JWT parsing
- Use `DescopeVerify().verify(token)` from `app/core/auth/descope.py`
- Token types: JWT session tokens (3 dot-separated parts) and access keys (opaque strings)

### Tenant Context
- Trust `request.scope["tenant_id"]` set by middleware
- Always use `company: Company = Depends(get_company)` or `CompanyAccess = Depends(get_company_access)`
- Never accept tenant/company ID from client input for data scoping

### Permission Checks
```python
# For endpoints requiring specific permissions
@router.post("/refund", dependencies=[Depends(check_permissions(["Dashboard Refund"]))])
async def create_refund(...):
    pass

# Admin endpoints use check_permissions_admin()
@router.get("/admin/companies", dependencies=[Depends(check_permissions_admin())])
async def get_all_companies(...):
    pass
```

## Error Handling

### HTTPException Usage
```python
# 400 - Bad Request
raise HTTPException(status_code=400, detail="Invalid account name")

# 401 - Unauthorized
raise HTTPException(status_code=401, detail="Token expired")

# 403 - Forbidden
raise HTTPException(status_code=403, detail="Insufficient permissions")

# 404 - Not Found
raise HTTPException(status_code=404, detail="Account not found")
```

### Logging
```python
from app.api.utils.logging import get_logger
logger = get_logger(__name__)

logger.info("Processing payment", extra={"payment_id": 123})
logger.error("Payment failed", exc_info=True)
```

Never use `print()` for logging. Never expose sensitive data in error messages.

## Security Checklist

- All inputs validated via Pydantic schemas
- Authentication required for non-public endpoints
- Permission checks for sensitive operations
- Tenant context enforced via CompanyAccess
- No hard-coded secrets
- No sensitive data in logs or error messages
- External calls use HTTPS with timeouts

## Quick Reference Commands

```bash
# Install dependencies
./scripts/install_dependencies.sh

# Run migrations
./scripts/db_migrate.sh

# Run tests
poetry run pytest -v

# Linting
poetry run ruff format .
poetry run ruff check --fix .

# Start dev server
poetry run uvicorn app.main:app --reload --port 8000
```
