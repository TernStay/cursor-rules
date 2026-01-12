# TurnStay Technology Stack Reference

> Comprehensive guide to the technologies used across TurnStay microservices.
> This document serves as the foundation for Cursor rules and development standards.

---

## Table of Contents

1. [Core Technologies](#core-technologies)
2. [Python & Package Management](#python--package-management)
3. [Web Framework - FastAPI](#web-framework---fastapi)
4. [Database & ORM](#database--orm)
5. [Authentication - Descope](#authentication---descope)
6. [Infrastructure & Deployment](#infrastructure--deployment)
7. [Testing Framework](#testing-framework)
8. [Monitoring & Alerting](#monitoring--alerting)
9. [Version Compatibility Matrix](#version-compatibility-matrix)

---

## Core Technologies

| Technology | Version | Purpose |
|------------|---------|---------|
| Python | 3.11+ | Runtime environment |
| FastAPI | 0.111.x / 0.115.x | Web framework |
| SQLAlchemy | 2.0.x | ORM & database toolkit |
| Alembic | 1.13.x | Database migrations |
| PostgreSQL | 14+ | Primary database |
| Poetry | 1.8+ | Dependency management |
| Pydantic | v1 (legacy) / v2 (new) | Data validation |
| Docker | Latest | Containerization |
| Pulumi | Latest | Infrastructure as Code |
| AWS | - | Cloud provider |

---

## Python & Package Management

### Poetry Configuration

All projects use Poetry for dependency management with a standardized `pyproject.toml` structure:

```toml
[tool.poetry]
name = "project-name"
version = "0.1.0"
description = "Service description"
authors = ["TurnStay <dev@turnstay.com>"]

[tool.poetry.dependencies]
python = "^3.11"
fastapi = "^0.111.0"
sqlalchemy = { extras = ["asyncio"], version = "^2.0.29" }
alembic = "^1.13.1"
asyncpg = "^0.29.0"
pydantic = "^2.7.0"  # Or ^1.10.x for legacy projects
httpx = "^0.27.0"

[tool.poetry.group.dev.dependencies]
pytest = "^8.1.1"
pytest-asyncio = "^0.23.6"
ruff = "^0.4.1"
black = "^24.4.0"
mypy = "^1.9.0"

[build-system]
requires = ["poetry-core>=1.0.0"]
build-backend = "poetry.core.masonry.api"
```

### Private Package Repository

Projects use AWS CodeArtifact for private packages:

```bash
# scripts/install_dependencies.sh
#!/bin/bash
export CODEARTIFACT_AUTH_TOKEN=$(aws codeartifact get-authorization-token \
    --domain turnstay \
    --domain-owner ${AWS_ACCOUNT_ID} \
    --query authorizationToken \
    --output text)

poetry config http-basic.codeartifact aws $CODEARTIFACT_AUTH_TOKEN
poetry install
```

### Shared Internal Packages

| Package | Purpose |
|---------|---------|
| `turnstay-ledger-client` | Ledger service client |
| `turnstay-common` | Shared utilities |
| `turnstay-recon-client` | Reconciliation client |

---

## Web Framework - FastAPI

### Application Structure

```
app/
├── __init__.py
├── main.py              # FastAPI app entry point
├── models.py            # SQLAlchemy models
├── constants.py         # Application constants
├── settings.py          # Environment settings
├── api/
│   ├── api.py           # Router aggregation
│   ├── deps.py          # Dependency injection
│   ├── endpoints/       # Route handlers
│   │   ├── account.py
│   │   ├── admin/       # Admin endpoints
│   │   ├── public/      # Public endpoints
│   │   └── webhooks/    # Webhook handlers
│   └── utils/           # Endpoint utilities
├── core/
│   ├── config.py        # Configuration management
│   ├── session.py       # Database sessions
│   ├── auth/            # Authentication
│   │   ├── descope.py
│   │   └── auth_middleware.py
│   └── middleware/      # Custom middleware
├── schemas/
│   ├── requests.py      # Request validation
│   └── responses.py     # Response serialization
└── tests/
    ├── conftest.py      # Test fixtures
    ├── endpoints/       # Endpoint tests
    └── fixtures/        # Test data
```

### Main Application Setup

```python
# app/main.py
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.sessions import SessionMiddleware

from app.api.api import api_router
from app.core.middleware.database_session_middleware import DatabaseSessionMiddleware
from app.core.auth.auth_middleware import AuthenticationMiddleware

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    yield
    # Shutdown

app = FastAPI(
    title="TurnStay API",
    description="Payment processing API",
    version="1.0.0",
    lifespan=lifespan,
)

# Middleware order matters (executed bottom-to-top on request, top-to-bottom on response)
app.add_middleware(DatabaseSessionMiddleware)
app.add_middleware(AuthenticationMiddleware)
app.add_middleware(SessionMiddleware, secret_key=settings.SECRET_KEY)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)
```

### Router Organization

```python
# app/api/api.py
from fastapi import APIRouter

API_VERSION_PREFIX = "/api/v1"
ADMIN_API_VERSION_PREFIX = API_VERSION_PREFIX + "/admin"

api_router = APIRouter()

# Standard routes
api_router.include_router(account.router, tags=["account"], prefix=API_VERSION_PREFIX)
api_router.include_router(payment_intents.router, tags=["payment_intents"], prefix=API_VERSION_PREFIX)

# Admin routes
api_router.include_router(admin_company.router, tags=["admin_company"], prefix=ADMIN_API_VERSION_PREFIX)

# Public routes (no auth required)
api_router.include_router(public_redirect.router, tags=["public"], prefix=API_VERSION_PREFIX)
```

---

## Database & ORM

### SQLAlchemy 2.0 Async Pattern

```python
# app/models.py
from sqlalchemy import ForeignKey, String, Integer, DateTime
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship
from sqlalchemy.sql import func

class Base(DeclarativeBase):
    created_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), server_onupdate=func.now()
    )

class Company(Base):
    __tablename__ = "companies"
    
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False, unique=True, index=True)
    tenant_id: Mapped[str] = mapped_column(String(255), nullable=False, unique=True)
    status_id: Mapped[int] = mapped_column(ForeignKey("company_status.id"))
    
    # Relationships with lazy="selectin" for async compatibility
    status: Mapped["CompanyStatus"] = relationship("CompanyStatus", lazy="selectin")
    accounts: Mapped[list["Account"]] = relationship("Account", back_populates="company", lazy="selectin")
```

### Async Session Management

```python
# app/core/session.py
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from contextlib import asynccontextmanager

async_engine = create_async_engine(database_url, pool_pre_ping=True)
async_session = async_sessionmaker(async_engine, expire_on_commit=False)

@asynccontextmanager
async def get_fresh_session_with_context():
    """Create a database session with automatic cleanup."""
    session = async_session()
    try:
        # Reset RLS context for security
        await session.execute(text("SET app.current_tenant TO DEFAULT"))
        await session.execute(text("RESET ROLE"))
        yield session
    finally:
        await session.close()
```

### Row-Level Security (RLS)

PostgreSQL RLS is used for multi-tenant data isolation:

```python
# Setting tenant context
async def _set_tenant_security(db, company_id: int):
    await db.execute(text(f"SET app.current_tenant = {company_id}"))
    await db.execute(text("SET SESSION ROLE tenant_user"))
```

### Alembic Migrations

```bash
# Create migration
alembic revision --autogenerate -m "add_new_table"

# Apply migrations
alembic upgrade head

# Rollback
alembic downgrade -1
```

Migration script pattern (`scripts/db_migrate.sh`):

```bash
#!/bin/bash
set -e
echo "Running database migrations..."
alembic upgrade head
echo "Migrations complete."
```

---

## Authentication - Descope

### Client Initialization

```python
# app/core/auth/descope.py
from descope import DescopeClient, AuthException

def get_descope_client():
    return DescopeClient(project_id=settings.DESCOPE_PROJECT_ID)

def get_descope_management_client():
    return DescopeClient(
        project_id=settings.DESCOPE_PROJECT_ID,
        management_key=settings.DESCOPE_MANAGEMENT_KEY
    )
```

### Token Verification

```python
class DescopeVerify:
    def __init__(self):
        self.descope_client = get_descope_client()

    def verify(self, token):
        # JWT tokens have 3 parts separated by dots
        if len(token.split(".")) == 3:
            return self.validate_session_token(token)
        else:
            return self.validate_access_key(token)

    def validate_session_token(self, session_token):
        jwt_response = self.descope_client.validate_session(session_token=session_token)
        return jwt_response

    def validate_access_key(self, access_key):
        resp = self.descope_client.exchange_access_key(access_key=access_key)
        return resp["sessionToken"]
```

### Authentication Middleware

```python
# app/core/auth/auth_middleware.py
class AuthenticationMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # Skip auth for public endpoints
        if "/public/" in request.url.path or request.url.path == "/health":
            request.scope["tenant_id"] = "public"
            return await call_next(request)

        # Extract and verify token
        token = get_token_from_request(request)
        if token is None:
            return JSONResponse(content={"detail": "Authorization header not provided"}, status_code=401)

        result = DescopeVerify().verify(token)
        tenant_id = get_tenant_id(result)
        
        # Set request context
        request.scope["tenant_id"] = tenant_id
        request.scope["permissions"] = get_permissions_from_jwt_response(result)
        
        return await call_next(request)
```

### Tenant & Permission Management

```python
# Creating tenants
def create_tenant(name):
    descope_client = get_descope_management_client()
    response = descope_client.mgmt.tenant.create(name=name)
    return response.get("id")

# Creating API keys
def create_descope_access_key(tenant_id, key_name, role_name):
    descope_client = get_descope_management_client()
    key_tenants = AssociatedTenant(tenant_id, [role_name])
    resp = descope_client.mgmt.access_key.create(
        name=key_name,
        expire_time=0,  # Never expires
        key_tenants=[key_tenants],
    )
    return resp["cleartext"], resp["key"]["id"]
```

---

## Infrastructure & Deployment

### Docker Configuration

```dockerfile
# Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Poetry
RUN pip install poetry

# Copy dependency files
COPY pyproject.toml poetry.lock ./

# Install dependencies
RUN poetry config virtualenvs.create false \
    && poetry install --no-dev --no-interaction --no-ansi

# Copy application
COPY . .

# Run migrations and start server
CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000"]
```

### CI/CD Pipeline (GitHub Actions)

```yaml
# .github/workflows/ci-cd.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, staging]
  pull_request:
    branches: [main]

jobs:
  bootstrap:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - name: Configure AWS CodeArtifact
        run: |
          pip install awscli poetry
          export CODEARTIFACT_AUTH_TOKEN=$(aws codeartifact get-authorization-token ...)
          poetry config http-basic.codeartifact aws $CODEARTIFACT_AUTH_TOKEN
      - name: Install dependencies
        run: poetry install

  lint:
    needs: bootstrap
    runs-on: ubuntu-latest
    steps:
      - name: Run Ruff
        run: poetry run ruff check .
      - name: Run Black
        run: poetry run black --check .

  test:
    needs: lint
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:14
        env:
          POSTGRES_PASSWORD: postgres
    steps:
      - name: Run tests
        run: poetry run pytest -v --cov

  deploy:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to AWS
        run: |
          pulumi up --yes --stack prod
```

### Pulumi Infrastructure

```python
# infra/__main__.py
import pulumi
import pulumi_aws as aws

# ECS Service
service = aws.ecs.Service(
    "api-service",
    cluster=cluster.arn,
    task_definition=task_definition.arn,
    desired_count=2,
    launch_type="FARGATE",
)

# RDS Database
database = aws.rds.Instance(
    "database",
    engine="postgres",
    engine_version="14",
    instance_class="db.t3.micro",
    allocated_storage=20,
)
```

---

## Testing Framework

### Pytest Configuration

```python
# app/tests/conftest.py
import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()

@pytest_asyncio.fixture(scope="session")
async def test_db_setup():
    assert config.settings.ENVIRONMENT == "PYTEST"
    async with async_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)

@pytest_asyncio.fixture(autouse=True)
async def session(test_db_setup) -> AsyncSession:
    async with get_fresh_session_with_context() as session:
        yield session
        # Cleanup after each test
        for table in reversed(Base.metadata.sorted_tables):
            await session.execute(delete(table))
        await session.commit()

@pytest_asyncio.fixture(scope="session")
async def client() -> AsyncClient:
    async with AsyncClient(app=app, base_url="http://test") as client:
        yield client
```

### Test Structure

```python
# app/tests/endpoints/test_accounts.py
from app.tests.fixtures.mocks.auth_mocks import mock_auth_success
from app.tests.fixtures.add_fixtures_to_db import add_company_to_db, add_account_to_db

async def test_create_account(
    client: AsyncClient,
    session: AsyncSession,
    mock_auth_success,  # Pytest fixture for mocking auth
):
    company = await add_company_to_db(session)
    
    response = await client.post(
        "/api/v1/account",
        json={"name": "New Account", "currency": "ZAR"},
        headers={"Authorization": "Bearer test_token"}
    )
    
    assert response.status_code == 200
    assert response.json()["name"] == "New Account"
```

---

## Monitoring & Alerting

### Honeybadger Integration

```python
# app/alerts/honeybadger.py
import honeybadger

honeybadger.configure(api_key=settings.HONEYBADGER_API_KEY)

def notify_error(exception, context=None):
    honeybadger.notify(exception, context=context)
```

### Slack Notifications

```python
# app/alerts/slack.py
import httpx

def send_slack_notification(message: str, channel: str = "#alerts"):
    httpx.post(
        settings.SLACK_WEBHOOK_URL,
        json={"channel": channel, "text": message}
    )
```

### Logging

```python
import logging
from app.api.utils.logging import get_logger

logger = get_logger(__name__)

logger.info("Processing payment", extra={"payment_id": 123})
logger.error("Payment failed", exc_info=True)
```

---

## Version Compatibility Matrix

### Pydantic Versions

| Project | Pydantic Version | Notes |
|---------|-----------------|-------|
| turnstay_api | v1.10.x | Legacy, migration planned |
| ledger | v2.7.x | Current |
| recon | v2.7.x | Current |
| treasury | v2.7.x | Current |
| payouts | v2.7.x | Current |
| webhook-service | v2.7.x | Current |
| secure_card_service | v2.7.x | Current |

### Pydantic v1 vs v2 Differences

```python
# Pydantic v1
from pydantic import BaseModel, Field, validator

class Request(BaseModel):
    name: str = Field(..., example="Test")
    
    @validator("name")
    def validate_name(cls, v):
        return v.strip()
    
    class Config:
        orm_mode = True

# Pydantic v2
from pydantic import BaseModel, Field, field_validator, model_validator

class Request(BaseModel):
    name: str = Field(..., json_schema_extra={"example": "Test"})
    
    @field_validator("name", mode="after")
    @classmethod
    def validate_name(cls, v):
        return v.strip()
    
    model_config = {"from_attributes": True}
```

---

## Quick Reference

### Common Commands

```bash
# Install dependencies
./scripts/install_dependencies.sh

# Run migrations
./scripts/db_migrate.sh

# Run tests
poetry run pytest -v

# Run linting
poetry run ruff check .
poetry run black --check .

# Start development server
poetry run uvicorn app.main:app --reload --port 8000

# Generate OpenAPI schema
poetry run python -c "from app.main import app; import json; print(json.dumps(app.openapi()))"
```

### Environment Variables

```bash
# Required
DATABASE_URL=postgresql+asyncpg://user:pass@localhost:5432/dbname
DESCOPE_PROJECT_ID=P2xxx
DESCOPE_MANAGEMENT_KEY=xxx
SECRET_KEY=xxx

# Optional
ENVIRONMENT=development  # development, staging, production, PYTEST
HONEYBADGER_API_KEY=xxx
SLACK_WEBHOOK_URL=xxx
```
