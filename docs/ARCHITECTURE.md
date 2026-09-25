# Architecture and Database Documentation

## Components

### Flutter
The mobile application uses a small service/repository layer around Supabase. Screens are role-aware but backend authorization remains authoritative.

### React Admin
The admin portal uses Supabase Auth and direct database queries protected by RLS. It provides dashboard statistics, request assignment/status management, customer/agent views and audit information.

### Supabase
Supabase provides:
- PostgreSQL
- Auth
- RLS
- SQL functions/triggers
- Realtime-ready infrastructure

## Data model

```mermaid
erDiagram
    AUTH_USERS ||--|| PROFILES : has
    PROFILES ||--o{ SERVICE_REQUESTS : creates
    SERVICES ||--o{ SERVICE_REQUESTS : requested_for
    PROFILES ||--o{ SERVICE_REQUESTS : assigned_to
    SERVICE_REQUESTS ||--o{ REQUEST_STATUS_HISTORY : has
    PROFILES ||--o{ REQUEST_STATUS_HISTORY : changes
    PROFILES ||--o{ AUDIT_LOGS : performs
    SERVICE_REQUESTS ||--o{ AUDIT_LOGS : references

    PROFILES {
      uuid id PK
      text full_name
      text phone
      text role
      timestamptz created_at
    }

    SERVICES {
      uuid id PK
      text name
      text description
      boolean active
    }

    SERVICE_REQUESTS {
      uuid id PK
      text request_code UK
      uuid customer_id FK
      uuid service_id FK
      uuid assigned_agent_id FK
      text description
      timestamptz preferred_at
      text address
      text priority
      text status
      text notes
      timestamptz created_at
      timestamptz updated_at
    }

    REQUEST_STATUS_HISTORY {
      bigint id PK
      uuid request_id FK
      text old_status
      text new_status
      uuid changed_by FK
      text note
      timestamptz created_at
    }

    AUDIT_LOGS {
      bigint id PK
      uuid actor_id FK
      uuid request_id FK
      text event_type
      jsonb metadata
      timestamptz created_at
    }
```

## Indexes

Indexes are provided for:
- request code
- customer ID
- assigned agent ID
- request status
- created date
- audit actor/date

These support common dashboard and role-specific queries.
