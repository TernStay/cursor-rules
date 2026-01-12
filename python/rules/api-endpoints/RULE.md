---
description: "FastAPI endpoint patterns and conventions for TurnStay services"
globs: 
  - "app/api/endpoints/**/*.py"
alwaysApply: false
---

# API Endpoint Patterns

## Standard Endpoint Structure

```python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api import deps
from app.models import Company
from app.schemas.requests import ResourceCreateRequest
from app.schemas.responses import ResourceResponse

router = APIRouter()

@router.post("/resource", response_model=ResourceResponse)
async def create_resource(
    request_data: ResourceCreateRequest,
    company_access: deps.CompanyAccess = Depends(deps.get_company_access),
    session: AsyncSession = Depends(deps.get_session),
    company: Company = Depends(deps.get_company),
):
    """Create a new resource."""
    # Business logic here
    resource = await create_resource_util(session, **request_data.model_dump())
    await session.commit()
    return await refresh_and_return(session, resource)
```

## HTTP Method Conventions

| Operation | Method | Path |
|-----------|--------|------|
| Create | POST | `/api/v1/resource` |
| Read One | GET | `/api/v1/resource?id=X` |
| Read Many | GET | `/api/v1/resources` |
| Update | PATCH | `/api/v1/resource` |
| Delete | DELETE | `/api/v1/resource?id=X` |

## Path Prefixes

- Standard: `/api/v1/...`
- Admin: `/api/v1/admin/...`
- Public (no auth): `/api/v1/public/...`
- Webhooks: `/api/v1/webhooks/...`

## Required Practices

- Always use `response_model` in route decorators
- Use `CompanyAccess` for tenant-scoped data access
- Use `fastapi_pagination.Page[...]` for list endpoints
- Raise `HTTPException` for errors (400, 404, 403, etc.)

## Dependency Injection

Always use FastAPI dependencies for common requirements:

```python
@router.get("/accounts", response_model=Page[AccountResponse])
async def get_accounts(
    session: AsyncSession = Depends(deps.get_session),
    company_access: deps.CompanyAccess = Depends(deps.get_company_access),
    company: Company = Depends(deps.get_company),
):
    """List all accounts for the current tenant."""
    accounts = await company_access.get_accounts()
    return paginate(accounts)
```

## Router Registration

Include new routers in `app/api/api.py`:

```python
from app.api.endpoints import new_resource

api_router.include_router(
    new_resource.router,
    prefix=API_VERSION_PREFIX,
    tags=["new-resource"],
)
```
