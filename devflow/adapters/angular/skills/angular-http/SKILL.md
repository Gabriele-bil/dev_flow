---
name: angular-http
description: Implement HTTP data fetching in Angular v20+ using resource(), httpResource(), and HttpClient. Use for API calls, data loading with signals, request/response handling, and interceptors. Triggers on data fetching, API integration, loading states, error handling, or converting Observable-based HTTP to signal-based patterns.
---

# Angular HTTP & Data Fetching

Fetch data in Angular with signal-first APIs: `httpResource()`, `resource()`, and `HttpClient`.

## `httpResource()` - Signal-Based HTTP

`httpResource()` wraps `HttpClient` with signal state.

```typescript
import { Component, signal } from "@angular/core";
import { httpResource } from "@angular/common/http";

interface User {
  id: number;
  name: string;
  email: string;
}

@Component({
  selector: "app-user-profile",
  template: `
    @if (userResource.isLoading()) {
      <p>Loading...</p>
    } @else if (userResource.error()) {
      <p>Error: {{ userResource.error()?.message }}</p>
      <button (click)="userResource.reload()">Retry</button>
    } @else if (userResource.hasValue()) {
      <h1>{{ userResource.value().name }}</h1>
      <p>{{ userResource.value().email }}</p>
    }
  `,
})
export class UserProfile {
  userId = signal("123");

  // Refetch when userId changes.
  userResource = httpResource<User>(() => `/api/users/${this.userId()}`);
}
```

### `httpResource()` Options

```typescript
// Simple GET
userResource = httpResource<User>(() => `/api/users/${this.userId()}`);

// Full request object
userResource = httpResource<User>(() => ({
  url: `/api/users/${this.userId()}`,
  method: "GET",
  headers: { Authorization: `Bearer ${this.token()}` },
  params: { include: "profile" },
}));

// Default value
usersResource = httpResource<User[]>(() => "/api/users", {
  defaultValue: [],
});

// Skip request when params not ready
userResource = httpResource<User>(() => {
  const id = this.userId();
  return id ? `/api/users/${id}` : undefined;
});
```

### Resource State

```typescript
// State
userResource.value(); // T | undefined
userResource.hasValue(); // boolean
userResource.error(); // unknown | undefined
userResource.isLoading(); // boolean
userResource.status(); // 'idle' | 'loading' | 'reloading' | 'resolved' | 'error' | 'local'

// Actions
userResource.reload();
userResource.set(value);
userResource.update(fn);
```

## `resource()` - Generic Async Data

Use for non-HTTP async tasks or custom fetch logic.

```typescript
import { Component, resource, signal } from "@angular/core";

@Component({
  selector: "app-search",
  template: `...`,
})
export class SearchComponent {
  query = signal("");

  searchResource = resource({
    params: () => ({ q: this.query() }),
    loader: async ({ params, abortSignal }) => {
      if (!params.q) return [];

      const response = await fetch(`/api/search?q=${params.q}`, {
        signal: abortSignal,
      });
      return response.json() as Promise<SearchResult[]>;
    },
  });
}
```

### `resource()` with Default Value

```typescript
todosResource = resource({
  defaultValue: [] as Todo[],
  params: () => ({ filter: this.filter() }),
  loader: async ({ params }) => {
    const res = await fetch(`/api/todos?filter=${params.filter}`);
    return res.json();
  },
});
```

### Conditional Loading

```typescript
const userId = signal<string | null>(null);

userResource = resource({
  params: () => {
    const id = userId();
    return id ? { id } : undefined;
  },
  loader: async ({ params }) => {
    return fetch(`/api/users/${params.id}`).then((r) => r.json());
  },
});
```

## `HttpClient` - Traditional Path

Use when Observable pipelines/operators are needed.

```typescript
import { Component, inject } from "@angular/core";
import { HttpClient } from "@angular/common/http";
import { toSignal } from "@angular/core/rxjs-interop";

@Component({
  selector: "app-users",
  template: `...`,
})
export class UsersComponent {
  private http = inject(HttpClient);

  users = toSignal(this.http.get<User[]>("/api/users"), { initialValue: [] });
  users$ = this.http.get<User[]>("/api/users");
}
```

### HTTP Methods

```typescript
private http = inject(HttpClient);

getUser(id: string) {
  return this.http.get<User>(`/api/users/${id}`);
}

createUser(user: CreateUserDto) {
  return this.http.post<User>('/api/users', user);
}

updateUser(id: string, user: UpdateUserDto) {
  return this.http.put<User>(`/api/users/${id}`, user);
}

patchUser(id: string, changes: Partial<User>) {
  return this.http.patch<User>(`/api/users/${id}`, changes);
}

deleteUser(id: string) {
  return this.http.delete<void>(`/api/users/${id}`);
}
```

### Request Options

```typescript
this.http.get<User[]>("/api/users", {
  headers: {
    Authorization: "Bearer token",
    "Content-Type": "application/json",
  },
  params: {
    page: "1",
    limit: "10",
    sort: "name",
  },
  observe: "response",
  responseType: "json",
});
```

## Interceptors

Functional interceptors recommended.

```typescript
// auth.interceptor.ts
import { HttpInterceptorFn } from "@angular/common/http";
import { inject } from "@angular/core";

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const authService = inject(AuthService);
  const token = authService.token();

  if (token) {
    req = req.clone({
      setHeaders: { Authorization: `Bearer ${token}` },
    });
  }

  return next(req);
};
```

```typescript
// error.interceptor.ts
import { HttpErrorResponse, HttpInterceptorFn } from "@angular/common/http";
import { inject } from "@angular/core";
import { Router } from "@angular/router";
import { catchError, throwError } from "rxjs";

export const errorInterceptor: HttpInterceptorFn = (req, next) => {
  return next(req).pipe(
    catchError((error: HttpErrorResponse) => {
      if (error.status === 401) {
        inject(Router).navigate(["/login"]);
      }
      return throwError(() => error);
    }),
  );
};
```

```typescript
// app.config.ts
import { ApplicationConfig } from "@angular/core";
import { provideHttpClient, withInterceptors } from "@angular/common/http";

export const appConfig: ApplicationConfig = {
  providers: [
    provideHttpClient(withInterceptors([authInterceptor, errorInterceptor])),
  ],
};
```

## Error Handling

### With `httpResource()`

```typescript
import { HttpErrorResponse } from '@angular/common/http';

getErrorMessage(error: unknown): string {
  if (error instanceof HttpErrorResponse) {
    return error.error?.message || `Error ${error.status}: ${error.statusText}`;
  }
  return 'Unexpected error';
}
```

### With `HttpClient`

```typescript
import { HttpErrorResponse } from '@angular/common/http';
import { catchError, retry, throwError } from 'rxjs';

getUser(id: string) {
  return this.http.get<User>(`/api/users/${id}`).pipe(
    retry(2),
    catchError((error: HttpErrorResponse) => {
      console.error('Error fetching user:', error);
      return throwError(() => new Error('Failed to load user'));
    })
  );
}
```

## Loading State Pattern

```typescript
@Component({
  template: `
    @switch (dataResource.status()) {
      @case ("idle") {
        <p>Enter search term</p>
      }
      @case ("loading") {
        <app-spinner />
      }
      @case ("reloading") {
        <app-data [data]="dataResource.value()" />
        <app-spinner size="small" />
      }
      @case ("resolved") {
        <app-data [data]="dataResource.value()" />
      }
      @case ("error") {
        <app-error
          [error]="dataResource.error()"
          (retry)="dataResource.reload()"
        />
      }
    }
  `,
})
export class DataComponent {
  query = signal("");
  dataResource = httpResource<Data[]>(() =>
    this.query() ? `/api/search?q=${this.query()}` : undefined,
  );
}
```

## Notes from Angular HTTP Docs

- Configure once with `provideHttpClient`.
- Prefer typed request/response models.
- Use interceptors for cross-cutting concerns (auth, logging, error mapping).
- Test HTTP with `provideHttpClientTesting` + `HttpTestingController`.

For advanced patterns, see [references/http-patterns.md](references/http-patterns.md).

## I/O Reference

|            |                                                                   |
| ---------- | ----------------------------------------------------------------- |
| Reads      | Active HTTP/service files, `@devflow/adapters/angular/ADAPTER.md` |
| Writes     | New or refactored Angular HTTP resource and service files         |
| Invoked by | `devflow.implement`, `devflow.beautify`                           |
