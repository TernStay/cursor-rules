# TurnStay Design Patterns & Best Practices

> Comprehensive guide to design patterns, coding conventions, and best practices across TurnStay microservices.
> Use this document to ensure consistency when building Cursor rules.

---

## Table of Contents

1. [API Endpoint Patterns](#api-endpoint-patterns)
2. [Authentication & Authorization](#authentication--authorization)
3. [Database Access Patterns](#database-access-patterns)
4. [Schema Design (Request/Response)](#schema-design-requestresponse)
5. [Dependency Injection](#dependency-injection)
6. [Error Handling](#error-handling)
7. [Testing Patterns](#testing-patterns)
8. [Middleware Architecture](#middleware-architecture)
9. [Migration Workflow](#migration-workflow)
10. [Code Organization Rules](#code-organization-rules)

---

## API Endpoint Patterns

### Standard Endpoint Structure

Every endpoint follows this consistent pattern:

```python
# app/api/endpoints/account.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api import deps
from app.models import Company
from app.schemas.requests import AccountCreateRequest
from app.schemas.responses import AccountResponse

router = APIRouter()

@router.post("/account", response_model=AccountResponse)
async def create_account(
    request_data: AccountCreateRequest,
    company_access: deps.CompanyAccess = Depends(deps.get_company_access),
    session: AsyncSession = Depends(deps.get_session),
    company: Company = Depends(deps.get_company),
):
    """Create a new account.
    
    - Validates request data via Pydantic schema
    - Uses CompanyAccess for tenant-scoped data access
    - Returns strongly-typed response
    """
    # Business logic here
    account = await create_account_util(session, **request_data.model_dump())
    await session.commit()
    return account
```

### CRUD Endpoint Naming Convention

| Operation | HTTP Method | Path | Example |
|-----------|-------------|------|---------|
| Create | POST | `/resource` | `POST /api/v1/account` |
| Read One | GET | `/resource?id=X` | `GET /api/v1/account?id=1` |
| Read Many | GET | `/resources` | `GET /api/v1/accounts` |
| Update | PATCH | `/resource` | `PATCH /api/v1/account` |
| Delete | DELETE | `/resource?id=X` | `DELETE /api/v1/account?id=1` |

### Path Prefixes

```python
API_VERSION_PREFIX = "/api/v1"
ADMIN_API_VERSION_PREFIX = "/api/v1/admin"

# Standard endpoints: /api/v1/resource
# Admin endpoints: /api/v1/admin/resource
# Public endpoints: /api/v1/public/resource
# Webhook endpoints: /api/v1/webhooks/provider
```

### Response Model Pattern

Always use `response_model` for type safety and automatic OpenAPI documentation:

```python
@router.get("/account", response_model=AccountResponse)
async def get_account(id: int, ...):
    account = await company_access.get_account(id)
    return account  # Automatically serialized to AccountResponse

@router.get("/accounts", response_model=list[AccountResponse])
async def get_accounts(...):
    return await company_access.get_accounts()
```

### Pagination Pattern

Use `fastapi-pagination` for list endpoints:

```python
from fastapi_pagination import Page, paginate

@router.get("/payment_intents", response_model=Page[PaymentIntentResponse])
async def get_payment_intents(
    filters: PaymentIntentsRequest = Depends(),
    session: AsyncSession = Depends(deps.get_session),
):
    query = select(PaymentIntent).where(...)
    results = await session.execute(query)
    return paginate(results.scalars().all())
```

---

## Authentication & Authorization

### Descope Integration Flow

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Client    │────▶│ AuthMiddleware   │────▶│  DescopeVerify  │
│             │     │                  │     │                 │
│ Bearer Token│     │ Extract token    │     │ Validate JWT or │
│             │     │ Set scope vars   │     │ Access Key      │
└─────────────┘     └──────────────────┘     └─────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │ request.scope    │
                    │ - tenant_id      │
                    │ - permissions    │
                    │ - descope_user_id│
                    └──────────────────┘
```

### Token Types

1. **Session Tokens (JWT)**: For dashboard/web users
   - Format: `eyJhbGciOiJSUzI1NiIs...` (3 dot-separated parts)
   - Contains user info, permissions, tenant

2. **Access Keys**: For API integrations
   - Format: Opaque string (no dots)
   - Associated with specific tenant and role

### Permission Checking

```python
# app/api/deps.py
def check_permissions(allow: list[str] = None):
    """Dependency that enforces permissions."""
    always_allow = [
        constants.COMPANY_ACCESS_PERMISSION,
        constants.DESCOPE_USER_ADMIN_PERMISSION,
    ]
    
    async def permissions_checker(
        request: Request, 
        permissions: list[str] = Depends(get_permissions)
    ):
        allowable = always_allow + (allow or [])
        if not set(allowable).intersection(set(permissions)):
            raise HTTPException(status_code=403, detail="Insufficient permissions")
        return permissions
    
    return permissions_checker

# Usage in endpoint
@router.post("/refund", dependencies=[Depends(check_permissions(["Dashboard Refund"]))])
async def create_refund(...):
    pass
```

### Admin vs Regular Endpoints

```python
# Regular endpoint - company tenant access
@router.get("/accounts", response_model=list[AccountResponse])
async def get_accounts(
    company_access: deps.CompanyAccess = Depends(deps.get_company_access),
):
    return await company_access.get_accounts()

# Admin endpoint - requires admin permissions
@router.get("/admin/companies", response_model=list[CompanyResponse])
async def get_all_companies(
    session: AsyncSession = Depends(deps.get_session),
    _: list[str] = Depends(deps.check_permissions_admin()),
):
    # Full database access, no tenant scoping
    result = await session.execute(select(Company))
    return result.scalars().all()
```

---

## Database Access Patterns

### CompanyAccess Pattern (Application-Level RLS)

The `CompanyAccess` class provides tenant-scoped data access:

```python
# app/api/deps.py
class CompanyAccess:
    """Company-scoped data access layer.
    
    Replaces database-level RLS with application-level filtering.
    All queries are automatically scoped to the requesting company.
    """
    
    def __init__(
        self,
        session: AsyncSession,
        company: Company,
        allowed_account_ids: set[int] | None = None,
    ):
        self.session = session
        self.company = company
        self.company_id = company.id
        self.allowed_account_ids = allowed_account_ids  # For user-account restrictions

    async def get_account(self, account_id: int) -> Account:
        """Get account belonging to this company."""
        return await get_company_account(
            self.session, self.company_id, account_id,
            allowed_account_ids=self.allowed_account_ids
        )
    
    async def get_payment_intent(self, payment_intent_id: int) -> PaymentIntent:
        """Get payment intent belonging to this company."""
        return await get_company_payment_intent(
            self.session, self.company_id, payment_intent_id
        )
```

### Utility Function Pattern

Database queries are centralized in utility files:

```python
# app/api/utils/find_company_scoped_records_util.py
async def get_company_account(
    session: AsyncSession,
    company_id: int,
    account_id: int,
    allowed_account_ids: set[int] | None = None,
) -> Account:
    """Fetch account with company validation."""
    query = select(Account).where(
        Account.id == account_id,
        Account.company_id == company_id,
    )
    
    if allowed_account_ids is not None:
        query = query.where(Account.id.in_(allowed_account_ids))
    
    result = await session.execute(query)
    account = result.scalar_one_or_none()
    
    if account is None:
        raise HTTPException(status_code=404, detail="Account not found")
    
    return account
```

### Database Query Best Practices

```python
# ✅ Good: Use selectin for async-compatible eager loading
class Company(Base):
    accounts: Mapped[list["Account"]] = relationship(
        "Account", back_populates="company", lazy="selectin"
    )

# ✅ Good: Use explicit joins when needed
query = (
    select(PaymentIntent)
    .options(selectinload(PaymentIntent.account))
    .where(PaymentIntent.company_id == company_id)
)

# ❌ Bad: Lazy loading in async context (will fail)
account = await session.get(Account, 1)
print(account.company.name)  # LazyLoad error!

# ✅ Good: Use refresh with specific attributes
await session.refresh(account, ["company"])
print(account.company.name)  # Works!
```

### Refresh and Return Pattern

```python
# app/api/utils/db_utils.py
async def refresh_and_return(session: AsyncSession, obj):
    """Refresh object to load relationships and return."""
    await session.refresh(obj)
    return obj

# Usage
account = Account(name="New", company_id=company.id)
session.add(account)
await session.commit()
return await refresh_and_return(session, account)
```

---

## Schema Design (Request/Response)

### Request Schema Pattern (Pydantic v2)

```python
# app/schemas/requests.py
from pydantic import BaseModel, Field, field_validator, model_validator, EmailStr

class BaseRequest(BaseModel):
    """Base class for all request schemas."""
    pass

class AccountCreateRequest(BaseRequest):
    name: str = Field(..., json_schema_extra={"example": "New Account"})
    currency: str = Field(..., json_schema_extra={"example": "ZAR"})
    country_name: str = Field(..., json_schema_extra={"example": "South Africa"})

class PaymentIntentCreateRequest(BaseRequest):
    account_id: int = Field(..., json_schema_extra={"example": 1})
    billing_amount: int | None = Field(None, json_schema_extra={"example": 450000})
    billing_currency: str = Field(..., json_schema_extra={"example": "ZAR"})
    customer_email: EmailStr | None = Field(None)
    customer_phone_number: str | None = Field("")
    
    @field_validator("customer_phone_number", mode="after")
    @classmethod
    def validate_phone_number(cls, value):
        if value and not value.startswith("+"):
            raise ValueError("Phone number must start with international code")
        return value
    
    @model_validator(mode="before")
    @classmethod
    def check_amounts(cls, values):
        billing = values.get("billing_amount")
        processing = values.get("processing_amount")
        if billing is None and processing is None:
            raise ValueError("Either billing_amount or processing_amount required")
        return values
```

### Response Schema Pattern

```python
# app/schemas/responses.py
from pydantic import BaseModel, Field

class BaseResponse(BaseModel):
    """Base class for all response schemas."""
    model_config = {"from_attributes": True}  # Enable ORM mode

class ObjectName(BaseResponse):
    """Lightweight response for related objects."""
    name: str

class CurrencyResponseShort(BaseResponse):
    code: str
    name: str
    symbol: str

class AccountResponse(BaseResponse):
    id: int
    name: str
    display_name: str | None = None
    company: ObjectName  # Nested relationship
    currency: CurrencyResponseShort
    payout_currency: CurrencyResponseShort
    terms_and_conditions_url: str | None = None
```

### Patch Request Pattern

For PATCH endpoints, use optional fields:

```python
class PatchAccountRequest(BaseModel):
    id: int = Field(..., json_schema_extra={"example": 1})  # Required identifier
    name: str | None = Field(None)  # Optional update fields
    display_name: str | None = Field(None)
    terms_and_conditions_url: HttpUrl | None = Field(None)
    
# Endpoint uses exclude_unset to only update provided fields
@router.patch("/account", response_model=AccountResponse)
async def patch_account(request_data: PatchAccountRequest, ...):
    account = await company_access.get_account(request_data.id)
    update_data = request_data.model_dump(exclude_unset=True)
    
    for field, value in update_data.items():
        if field != "id":
            setattr(account, field, value)
    
    await session.commit()
    return account
```

---

## Dependency Injection

### Standard Dependencies

```python
# app/api/deps.py
from fastapi import Depends, Request, HTTPException
from fastapi.security import HTTPBearer

oauth_schema = HTTPBearer(auto_error=False)

def get_token(request: Request, token = Depends(oauth_schema)):
    """Extract token from request."""
    token = get_token_from_request(request)
    if token is None:
        raise HTTPException(status_code=401, detail="Token not found")
    return token

def get_tenant_id(request: Request) -> str:
    """Get tenant ID from request scope (set by middleware)."""
    return request.scope.get("tenant_id")

def get_permissions(request: Request) -> list[str]:
    """Get permissions from request scope."""
    return request.scope.get("permissions", [])

async def get_session(
    request: Request,
    tenant_id: str = Depends(get_tenant_id),
    token: str = Depends(get_token),
) -> AsyncSession:
    """Get database session from request state."""
    if hasattr(request.state, "db"):
        yield request.state.db
    else:
        raise HTTPException(status_code=500, detail="DB session not available")

def get_company(request: Request) -> Company:
    """Get company from request state (set by middleware)."""
    if not hasattr(request.state, "company"):
        raise HTTPException(status_code=400, detail="Cannot find company")
    return request.state.company

def get_user(request: Request) -> User | None:
    """Get user from request state (optional)."""
    return getattr(request.state, "user", None)

async def get_company_access(
    request: Request,
    company: Company = Depends(get_company),
    session: AsyncSession = Depends(get_session),
) -> CompanyAccess:
    """Get company-scoped data access layer."""
    user = get_user(request)
    if user is None:
        return CompanyAccess(session, company)
    
    # Restrict to user's allowed accounts
    user_accounts = await find_user_accounts_by_user_id(session, user.id)
    allowed_account_ids = {ua.account_id for ua in user_accounts}
    
    return CompanyAccess(session, company, allowed_account_ids=allowed_account_ids)
```

### Dependency Chain

```
get_company_access
    ├── get_company
    │       └── request.state.company (set by middleware)
    ├── get_session
    │       ├── get_tenant_id
    │       │       └── request.scope["tenant_id"]
    │       └── get_token
    │               └── request headers
    └── get_user
            └── request.state.user (set by middleware)
```

---

## Error Handling

### HTTPException Pattern

```python
from fastapi import HTTPException

# 400 - Bad Request (client error)
raise HTTPException(status_code=400, detail="Invalid account name")

# 401 - Unauthorized (authentication failed)
raise HTTPException(status_code=401, detail="Token expired")

# 403 - Forbidden (insufficient permissions)
raise HTTPException(status_code=403, detail="Insufficient permissions")

# 404 - Not Found
raise HTTPException(status_code=404, detail="Account not found")

# 500 - Internal Server Error (never expose internals)
raise HTTPException(status_code=500, detail="Internal server error")
```

### Exception Handlers

```python
# app/core/handlers/exception_handlers.py
from fastapi import Request
from fastapi.responses import JSONResponse

async def generic_exception_handler(request: Request, exc: Exception):
    """Catch-all exception handler."""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    honeybadger.notify(exc)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"}
    )

# Register in main.py
app.add_exception_handler(Exception, generic_exception_handler)
```

### Error Response Format

All error responses follow this structure:

```json
{
    "detail": "Human-readable error message"
}
```

For validation errors (422):

```json
{
    "detail": [
        {
            "loc": ["body", "customer_email"],
            "msg": "value is not a valid email address",
            "type": "value_error.email"
        }
    ]
}
```

---

## Testing Patterns

### Test File Organization

```
app/tests/
├── conftest.py              # Global fixtures
├── fixtures/
│   ├── add_fixtures_to_db.py    # Database fixture helpers
│   ├── company_fixtures.py      # Company test data
│   ├── account_fixtures.py      # Account test data
│   ├── mocks/
│   │   ├── auth_mocks.py        # Authentication mocks
│   │   ├── ledger_mocks.py      # External service mocks
│   │   └── sendgrid_mocks.py    # Email service mocks
│   └── descope_auth_fixtures.py # Auth header fixtures
├── endpoints/
│   ├── test_accounts.py
│   ├── test_payment_intents.py
│   └── admin/
│       └── test_admin_company.py
└── utils/
    └── test_currency_utils.py
```

### Test Function Pattern

```python
# app/tests/endpoints/test_accounts.py
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.tests.fixtures.mocks.auth_mocks import mock_auth_success
from app.tests.fixtures.add_fixtures_to_db import add_company_to_db, add_account_to_db

async def test_create_account(
    client: AsyncClient,       # HTTP client fixture
    session: AsyncSession,      # Database session fixture
    mock_auth_success,         # Mocked authentication
):
    """Test account creation endpoint."""
    # Arrange: Set up test data
    company = await add_company_to_db(session)
    
    # Act: Make request
    response = await client.post(
        "/api/v1/account",
        json={
            "name": "New Account",
            "currency": "ZAR",
            "country_name": "South Africa",
        },
        headers={"Authorization": "Bearer test_token"}
    )
    
    # Assert: Verify response
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "New Account"
    assert data["company"]["name"] == company.name

async def test_create_account_duplicate_name_fails(
    client: AsyncClient,
    session: AsyncSession,
    mock_auth_success,
):
    """Test that duplicate account names are rejected."""
    company = await add_company_to_db(session)
    existing = await add_account_to_db(session)
    
    response = await client.post(
        "/api/v1/account",
        json={"name": existing.name, "currency": "ZAR"},
        headers={"Authorization": "Bearer test_token"}
    )
    
    assert response.status_code == 400
    assert "already exists" in response.json()["detail"]
```

### Mock Fixture Pattern

```python
# app/tests/fixtures/mocks/auth_mocks.py
import pytest

@pytest.fixture
def mock_auth_success(mocker):
    """Mock successful authentication."""
    mock_verify = mocker.patch("app.core.auth.descope.DescopeVerify.verify")
    mock_verify.return_value = {
        "tenants": {"test_tenant_id": {"permissions": ["User Admin"]}},
        "userId": "test_user_id",
    }
    return mock_verify

@pytest.fixture
def mock_auth_success_tenant_2(mocker):
    """Mock auth for different tenant (for isolation tests)."""
    mock_verify = mocker.patch("app.core.auth.descope.DescopeVerify.verify")
    mock_verify.return_value = {
        "tenants": {"tenant_2": {"permissions": ["User Admin"]}},
        "userId": "test_user_2",
    }
    return mock_verify
```

### Database Fixture Pattern

```python
# app/tests/fixtures/add_fixtures_to_db.py
from app.models import Company, Account, Currency

async def add_company_to_db(
    session: AsyncSession,
    company_json: dict = None,
) -> Company:
    """Add a company to the test database."""
    if company_json is None:
        company_json = get_company_1()  # Default test company
    
    # Add required related records
    status = await add_company_status_to_db(session)
    
    company = Company(**company_json, status_id=status.id)
    session.add(company)
    await session.commit()
    await session.refresh(company)
    
    return company

async def add_account_to_db(
    session: AsyncSession,
    company: Company = None,
) -> Account:
    """Add an account to the test database."""
    if company is None:
        company = await add_company_to_db(session)
    
    currency = await add_zar_to_db(session)
    
    account = Account(
        name="Test Account",
        company_id=company.id,
        currency_id=currency.id,
    )
    session.add(account)
    await session.commit()
    await session.refresh(account)
    
    return account
```

---

## Middleware Architecture

### Middleware Execution Order

```python
# app/main.py
# Middleware executes bottom-to-top on REQUEST, top-to-bottom on RESPONSE

app.add_middleware(ExceptionHandlingMiddleware)     # 1st on request, last on response
app.add_middleware(LoggingMiddleware)               # 2nd on request
app.add_middleware(DatabaseSessionMiddleware)       # 3rd on request
app.add_middleware(AuthenticationMiddleware)        # 4th on request
app.add_middleware(SessionMiddleware, secret_key=...) # 5th on request (session cookie)
app.add_middleware(CORSMiddleware, ...)             # Last on request
```

### Database Session Middleware

```python
# app/core/middleware/database_session_middleware.py
class DatabaseSessionMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        # Skip for health check
        if request.url.path == "/health":
            return await call_next(request)
        
        # Create session with automatic cleanup
        async with get_fresh_session_with_context() as session:
            request.state.db = session
            
            # Set tenant context based on authenticated user
            await self._handle_tenant_context(request)
            await self._handle_user_context(request)
            
            response = await call_next(request)
            return response
    
    async def _handle_tenant_context(self, request):
        tenant_id = request.scope.get("tenant_id")
        if tenant_id and tenant_id not in ["admin", "static", "public"]:
            company = await find_company_by_tenant_id(request.state.db, tenant_id)
            request.state.company = company
            
            # Apply Row-Level Security
            await request.state.db.execute(text(f"SET app.current_tenant = {company.id}"))
            await request.state.db.execute(text("SET SESSION ROLE tenant_user"))
```

### Custom Middleware Template

```python
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

class CustomMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # Pre-processing
        start_time = time.time()
        
        # Call next middleware/endpoint
        response = await call_next(request)
        
        # Post-processing
        duration = time.time() - start_time
        response.headers["X-Process-Time"] = str(duration)
        
        return response
```

---

## Migration Workflow

### Creating Migrations

1. **Modify models.py**:
```python
# Add new column
class Account(Base):
    new_field: Mapped[str | None] = mapped_column(String(255), nullable=True)
```

2. **Generate migration**:
```bash
alembic revision --autogenerate -m "add_new_field_to_accounts"
```

3. **Review generated migration**:
```python
# alembic/versions/xxxx_add_new_field_to_accounts.py
def upgrade():
    op.add_column('accounts', sa.Column('new_field', sa.String(255), nullable=True))

def downgrade():
    op.drop_column('accounts', 'new_field')
```

4. **Apply migration**:
```bash
alembic upgrade head
```

### Migration Best Practices

```python
# ✅ Good: Make new columns nullable initially
op.add_column('accounts', sa.Column('new_field', sa.String(255), nullable=True))

# ✅ Good: Backfill data in separate migration
def upgrade():
    # Migration 1: Add nullable column
    op.add_column('accounts', sa.Column('status', sa.String(50), nullable=True))
    
def upgrade():
    # Migration 2: Backfill data
    op.execute("UPDATE accounts SET status = 'ACTIVE' WHERE status IS NULL")
    
def upgrade():
    # Migration 3: Make non-nullable
    op.alter_column('accounts', 'status', nullable=False)

# ❌ Bad: Add non-nullable column without default
op.add_column('accounts', sa.Column('required_field', sa.String(255), nullable=False))
```

---

## Code Organization Rules

### File Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Endpoints | Plural resource name | `accounts.py`, `payment_intents.py` |
| Utils | `{domain}_utils.py` | `currency_utils.py`, `db_utils.py` |
| Tests | `test_{resource}.py` | `test_accounts.py` |
| Fixtures | `{domain}_fixtures.py` | `account_fixtures.py` |
| Mocks | `{service}_mocks.py` | `auth_mocks.py`, `ledger_mocks.py` |

### Import Organization

```python
# Standard library
import datetime
from collections.abc import AsyncGenerator

# Third-party packages (alphabetical)
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

# Local imports - core modules
from app import constants, settings
from app.core.auth.descope import get_token_from_request

# Local imports - API modules
from app.api import deps
from app.api.utils.db_utils import refresh_and_return

# Local imports - models and schemas
from app.models import Account, Company
from app.schemas.requests import AccountCreateRequest
from app.schemas.responses import AccountResponse
```

### Constants Usage

```python
# app/constants.py
PAYMENT_INTENT_PROCESSED_STATUS = "PROCESSED"
PAYMENT_INTENT_INITIALIZED_STATUS = "INITIALIZED"

# Usage in code
from app import constants

if payment_intent.status.name == constants.PAYMENT_INTENT_PROCESSED_STATUS:
    # Handle processed payment
    pass
```

### Configuration Access

```python
# app/settings.py (or app/core/config.py)
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    DATABASE_URL: str
    DESCOPE_PROJECT_ID: str
    ENVIRONMENT: str = "development"
    
    class Config:
        env_file = ".env"

settings = Settings()

# Usage
from app import settings

if settings.ENVIRONMENT == "production":
    # Production-specific logic
    pass
```

---

## Quick Reference Checklist

### New Endpoint Checklist

- [ ] Create request schema in `schemas/requests.py`
- [ ] Create response schema in `schemas/responses.py`
- [ ] Add router file in `api/endpoints/`
- [ ] Use `CompanyAccess` for tenant-scoped data
- [ ] Add response_model to endpoint decorator
- [ ] Include proper dependencies (session, company, permissions)
- [ ] Add endpoint to router in `api/api.py`
- [ ] Write tests in `tests/endpoints/`

### New Model Checklist

- [ ] Add model class to `models.py`
- [ ] Include `created_at` and `updated_at` from Base
- [ ] Define proper indexes
- [ ] Use `lazy="selectin"` for relationships
- [ ] Generate Alembic migration
- [ ] Review migration before applying
- [ ] Update relevant schemas if needed

### Pull Request Checklist

- [ ] All tests pass (`poetry run pytest`)
- [ ] Linting passes (`poetry run ruff check .`)
- [ ] Formatting correct (`poetry run black --check .`)
- [ ] Migration reviewed if applicable
- [ ] No secrets or sensitive data in code
- [ ] API documentation updated if needed
