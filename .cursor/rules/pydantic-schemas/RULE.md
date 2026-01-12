---
description: "Pydantic schema patterns for request/response validation in TurnStay"
globs:
  - "app/schemas/**/*.py"
alwaysApply: false
---

# Pydantic Schema Patterns

## Request Schema (Pydantic v2)

```python
from pydantic import BaseModel, Field, field_validator, model_validator

class ResourceCreateRequest(BaseModel):
    name: str = Field(..., json_schema_extra={"example": "Example"})
    email: EmailStr | None = Field(None)
    
    @field_validator("name", mode="after")
    @classmethod
    def validate_name(cls, v):
        return v.strip()
```

## Response Schema

```python
class ResourceResponse(BaseModel):
    id: int
    name: str
    company: ObjectName  # Reuse nested schemas
    
    model_config = {"from_attributes": True}  # Enable ORM mode
```

## Pydantic Version Note

- **New projects**: Use Pydantic v2 (`@field_validator`, `model_config`)
- **Legacy projects**: Use Pydantic v1 (`@validator`, `class Config`)
- Check `pyproject.toml` to determine which version

### Pydantic v1 Style (Legacy)

```python
from pydantic import BaseModel, validator

class ResourceCreateRequest(BaseModel):
    name: str
    
    @validator("name")
    def validate_name(cls, v):
        return v.strip()
    
    class Config:
        orm_mode = True
```

### Pydantic v2 Style (Preferred)

```python
from pydantic import BaseModel, field_validator, ConfigDict

class ResourceCreateRequest(BaseModel):
    name: str
    
    model_config = ConfigDict(from_attributes=True)
    
    @field_validator("name", mode="after")
    @classmethod
    def validate_name(cls, v):
        return v.strip()
```

## Optional vs Required Fields

For create requests, use required fields:
```python
class CreateRequest(BaseModel):
    name: str  # Required
    description: str  # Required
```

For patch/update requests, use optional fields:
```python
class PatchRequest(BaseModel):
    name: str | None = None
    description: str | None = None
```

Use `model_dump(exclude_unset=True)` for partial updates.

## Nested Schema Reuse

Create small reusable schemas for common nested objects:

```python
class ObjectName(BaseModel):
    id: int
    name: str
    
    model_config = {"from_attributes": True}

class AccountResponse(BaseModel):
    id: int
    name: str
    company: ObjectName  # Reused
    currency: ObjectName  # Reused
```

## Field Examples for OpenAPI

Always provide examples for documentation:

```python
class PaymentIntentCreateRequest(BaseModel):
    amount: int = Field(..., json_schema_extra={"example": 10000})
    currency: str = Field(..., json_schema_extra={"example": "ZAR"})
    description: str | None = Field(None, json_schema_extra={"example": "Payment for order #123"})
```
