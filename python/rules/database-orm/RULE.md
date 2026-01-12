---
description: "SQLAlchemy async ORM patterns, RLS, and database access for TurnStay"
globs:
  - "app/models.py"
  - "app/api/utils/**/*.py"
  - "app/core/session.py"
  - "alembic/**/*.py"
alwaysApply: false
---

# Database & ORM Patterns

## Async SQLAlchemy

- Always use `AsyncSession` from `sqlalchemy.ext.asyncio`
- Never use synchronous database calls
- Use `lazy="selectin"` for relationships (async-compatible eager loading)

## Query Patterns

```python
# ✅ Good: Use CompanyAccess for tenant-scoped queries
account = await company_access.get_account(account_id)

# ✅ Good: Use selectinload for relationships
query = select(PaymentIntent).options(selectinload(PaymentIntent.account))

# ❌ Bad: Direct query without tenant filtering in non-admin endpoint
result = await session.execute(select(Account).where(Account.id == id))

# ❌ Bad: Lazy loading in async context
account = await session.get(Account, 1)
print(account.company.name)  # LazyLoad error!
```

## Row-Level Security (RLS)

PostgreSQL RLS is configured for tenant isolation:
- Middleware sets `SET app.current_tenant = {company_id}`
- Middleware sets `SET SESSION ROLE tenant_user`
- Never bypass RLS in non-admin endpoints
- Admin endpoints query globally after verifying admin rights

## Commit & Refresh Pattern

```python
session.add(new_object)
await session.commit()
return await refresh_and_return(session, new_object)
```

## CompanyAccess Usage

Always use `CompanyAccess` for tenant-scoped queries:

```python
async def get_payment_intent(
    payment_intent_id: int,
    company_access: deps.CompanyAccess = Depends(deps.get_company_access),
):
    payment_intent = await company_access.get_payment_intent(payment_intent_id)
    if not payment_intent:
        raise HTTPException(status_code=404, detail="Payment intent not found")
    return payment_intent
```

## Alembic Migrations

- All schema changes require Alembic migrations
- Make new columns nullable initially, backfill, then set non-nullable
- Command: `alembic revision --autogenerate -m "description"`
- Run with: `./scripts/db_migrate.sh` or `poetry run alembic upgrade head`

## Model Definition Pattern

```python
from sqlalchemy import Column, Integer, String, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from app.models import Base

class NewModel(Base):
    __tablename__ = "new_models"
    
    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False)
    company_id = Column(Integer, ForeignKey("companies.id"), nullable=False)
    created_at = Column(DateTime, server_default=func.now())
    
    # Use selectin for async-safe eager loading
    company = relationship("Company", lazy="selectin")
```
