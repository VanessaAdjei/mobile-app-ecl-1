# Project Architecture: Route → Controller → Service → Repository → Model → Database

This document defines the standard architecture for the ECL ecommerce app. All new code and incremental refactors should follow this flow.

## Data flow (top to bottom)

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌──────────────┐     ┌────────┐     ┌──────────┐
│   Route     │ ──► │ Controller  │ ──► │   Service   │ ──► │  Repository  │ ──► │ Model  │     │ Database │
│  (Screen)   │     │  (Provider) │     │ (use cases) │     │ (data layer) │     │ (DTO)  │     │ (storage)│
└─────────────┘     └─────────────┘     └─────────────┘     └──────────────┘     └────────┘     └──────────┘
       │                    │                    │                    │                │                │
       │                    │                    │                    │                │                │
       ▼                    ▼                    ▼                    ▼                ▼                ▼
  UI only            State & UI           Business logic      Single source      Entities        API + local
  No business        Calls Service        Orchestrates         of truth          & DTOs          persistence
  logic              only                 Repositories        for data
```

## Layer responsibilities

| Layer       | Role | Location | Rules |
|------------|------|----------|--------|
| **Route**  | Screen / page widget. Handles UI only; gets state from Controller and calls Controller methods on actions. | `lib/pages/` or `lib/screens/` | No direct Service or Repository calls. No business logic. |
| **Controller** | Presentation state. Listens to user actions, calls Service, updates UI state (loading, error, success). | `lib/controllers/` or `lib/providers/` | Calls Service only. Does not call Repository or Database. |
| **Service** | Application / use-case logic. Orchestrates one or more Repositories, applies business rules, transactions. | `lib/services/` | Calls Repository only. No direct API or DB access. |
| **Repository** | Data access abstraction. Single API for reading/writing a domain entity (e.g. auth, cart, products). | `lib/repositories/` | Uses Database (API client, local storage). Returns/accepts Models. |
| **Model** | Data structures: entities, DTOs, request/response shapes. | `lib/models/` | Plain classes, fromJson/toJson. No logic. |
| **Database** | Actual persistence: remote (API client) and/or local (SharedPreferences, SecureStorage, SQLite). | `lib/database/` | Low-level read/write. Used only by Repository. |

## Folder structure

```
lib/
├── config/           # App config, route names (no business logic)
├── core/             # Shared utilities, constants, base classes
├── database/         # Data sources (API clients, local storage)
│   ├── auth/
│   ├── cart/
│   └── ...
├── models/           # Entities and DTOs
├── repositories/     # Data access layer (one per domain)
├── services/         # Use cases / application logic
├── controllers/      # Or providers/ — UI state, calls Service
├── pages/            # Route screens (UI only)
├── widgets/          # Reusable UI components
└── routes/           # Optional: route list + page mapping
```

## Dependency rules

- **Route** → Controller only.
- **Controller** → Service only.
- **Service** → Repository only.
- **Repository** → Model + Database only.
- **Database** → Model (and external APIs/storage).
- **Model** → nothing (plain data).

No layer should skip another (e.g. Controller must not call Repository; Service must not call API directly).

## Naming conventions

- **Route/Page:** `*_page.dart` or `*screen.dart` (e.g. `sign_in_page.dart`).
- **Controller:** `*_controller.dart` or keep existing `*_provider.dart`.
- **Service:** `*_service.dart` (e.g. `auth_service.dart`).
- **Repository:** `*_repository.dart` (e.g. `auth_repository.dart`).
- **Model:** `*_model.dart` or entity name (e.g. `user.dart`, `cart_item.dart`).
- **Database:** `*_api_client.dart` (remote), `*_local_storage.dart` (local).

## Example: Auth flow

1. **Route:** `SignInScreen` — shows form, calls `AuthController.signIn(email, password)`.
2. **Controller:** `AuthProvider` / `AuthController` — sets loading, calls `AuthService.signIn()`, then updates state and notifies listeners.
3. **Service:** `AuthService` — validates input, calls `AuthRepository.signIn()`, then may call `AuthRepository.saveToken()` etc.
4. **Repository:** `AuthRepository` — uses `AuthApiClient.login()` and `AuthLocalStorage.saveToken()` / `saveUser()`.
5. **Model:** `User`, `AuthTokens` (or existing user data structures).
6. **Database:** `AuthApiClient` (HTTP login/signup), `AuthLocalStorage` (SecureStorage + SharedPreferences for tokens and user).

## Migration strategy

- **New features:** Implement with the full stack (Route → Controller → Service → Repository → Model → Database).
- **Existing code:** Refactor one flow at a time (e.g. Auth first, then Cart, then Products). Introduce Repository and Database layers, then make Service use Repository, then ensure Controller only talks to Service and Route only to Controller.
