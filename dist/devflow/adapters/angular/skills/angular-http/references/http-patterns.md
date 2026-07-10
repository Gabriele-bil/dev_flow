# Angular HTTP Patterns

## Table of Contents

- [`httpResource()` - Signal-Based HTTP](#httpresource---signal-based-http)
- [`resource()` - Generic Async Data](#resource---generic-async-data)
- [`HttpClient` - Traditional Path](#httpclient---traditional-path)
- [Interceptors](#interceptors)
- [Error Handling](#error-handling)
- [Loading State Pattern](#loading-state-pattern)
- [DI Patterns Baseline](#di-patterns-baseline)
- [Notes from Angular HTTP Docs](#notes-from-angular-http-docs)
- [Service Layer Pattern](#service-layer-pattern)
- [Caching Strategies](#caching-strategies)
- [Pagination](#pagination)
- [File Upload](#file-upload)
- [Request Cancellation](#request-cancellation)
- [Debounced Search](#debounced-search)
- [Advanced DI Patterns](#advanced-di-patterns)
- [Testing HTTP](#testing-http)

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

Use `@Service()` decorator for global singleton services in v22 — replaces
`@Injectable({ providedIn: 'root' })`.

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

## DI Patterns Baseline

Extends `@Service`/`inject()` baseline for cases needing token-based config, multi-provider arrays, or scoped overrides.

### `InjectionToken` + Factory

Use for non-class dependencies (config objects, primitives, third-party instances) — type-safe, tree-shakable.

```typescript
export const API_BASE_URL = new InjectionToken<string>("API_BASE_URL", {
  providedIn: "root",
  factory: () => "/api",
});

// inject(API_BASE_URL) anywhere in the tree
```

### Provider Strategies

```typescript
providers: [
  { provide: Logger, useClass: ConsoleLogger },           // swap implementation
  { provide: API_BASE_URL, useValue: "/api/v2" },         // static value
  { provide: UserService, useFactory: () => new UserService(inject(HttpClient)) },
  { provide: LegacyLogger, useExisting: Logger },         // alias
  { provide: HTTP_INTERCEPTORS, useClass: AuthInterceptor, multi: true }, // array registration
]
```

`multi: true` collects all matching providers into an array — standard pattern for interceptor/validator-style extension points.

### Hierarchical Injector Modifiers

```typescript
inject(ParentService, { optional: true });  // null if not found, no error
inject(ParentService, { self: true });      // only this injector, not ancestors
inject(ParentService, { skipSelf: true });  // skip this injector, search ancestors
inject(ParentService, { host: true });      // stop search at host component boundary
```

Combine to express precise lookup intent (e.g. `{ optional: true, skipSelf: true }`).

### `providers` vs `viewProviders`

`providers`: visible to component + content-projected children. `viewProviders`: visible to component + view children only — content children can't see/override them. Use `viewProviders` to isolate internal collaborators from consumer-projected content.

### Injection Context

`inject()` requires an injection context (constructor, field initializer, factory function). Outside these, use:

```typescript
runInInjectionContext(injector, () => inject(MyService));
assertInInjectionContext(myFunction); // throws if called outside injection context
```

Common need: calling `inject()`-based APIs (`takeUntilDestroyed`, signal helpers) from callbacks/timers outside constructors.

For deeper examples, see [references/http-patterns.md](references/http-patterns.md#advanced-di-patterns).

## Notes from Angular HTTP Docs

- Configure once with `provideHttpClient`.
- Prefer typed request/response models.
- Use interceptors for cross-cutting concerns (auth, logging, error mapping).
- Test HTTP with `provideHttpClientTesting` + `HttpTestingController`.

For advanced patterns, see [references/http-patterns.md](references/http-patterns.md).

## Advanced DI Patterns

### Config Token with Environment Override

```typescript
export const API_CONFIG = new InjectionToken<{ baseUrl: string; timeout: number }>("API_CONFIG", {
  providedIn: "root",
  factory: () => ({ baseUrl: "/api", timeout: 30_000 }),
});

// Override per-environment in app.config.ts
providers: [
  { provide: API_CONFIG, useValue: { baseUrl: "https://api.staging.example.com", timeout: 10_000 } },
]
```

### Multi-Provider Interceptor Registration

```typescript
export const HTTP_RETRY_STRATEGIES = new InjectionToken<RetryStrategy[]>("HTTP_RETRY_STRATEGIES");

providers: [
  { provide: HTTP_RETRY_STRATEGIES, useClass: ExponentialBackoff, multi: true },
  { provide: HTTP_RETRY_STRATEGIES, useClass: FixedDelay, multi: true },
]

// Consume as array
private strategies = inject(HTTP_RETRY_STRATEGIES);
```

### `useFactory` with Dependencies

```typescript
export function loggerFactory(http: HttpClient, config: AppConfig) {
  return config.remoteLogging ? new RemoteLogger(http) : new ConsoleLogger();
}

providers: [
  { provide: Logger, useFactory: loggerFactory, deps: [HttpClient, AppConfig] },
]
```

### `viewProviders` — Isolating Internal Collaborators

```typescript
@Component({
  selector: "app-data-grid",
  viewProviders: [GridStateService], // own template can inject it; projected content cannot override
  template: `<ng-content />`,
})
export class DataGrid {
  private state = inject(GridStateService);
}
```

Use when a component's internal state service must stay opaque to consumers projecting custom templates into it.

### Optional Dependency with Fallback

```typescript
export class WidgetHost {
  private analytics = inject(AnalyticsService, { optional: true });

  track(event: string) {
    this.analytics?.track(event); // no-op if analytics not provided in this subtree
  }
}
```

### Running `inject()` Outside Injection Context

```typescript
export class PollingService {
  private injector = inject(Injector);

  startPolling() {
    setInterval(() => {
      runInInjectionContext(this.injector, () => {
        const http = inject(HttpClient);
        http.get("/api/status").subscribe();
      });
    }, 5000);
  }
}
```

Prefer restructuring to call `inject()` at construction time when possible — `runInInjectionContext` is an escape hatch for genuinely dynamic call sites (timers, event callbacks holding long-lived references).

## Service Layer Pattern

Keep HTTP orchestration inside services.

```typescript
import { Service, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { httpResource } from '@angular/common/http';

export interface User {
  id: string;
  name: string;
  email: string;
}

@Service()
export class UserService {
  private http = inject(HttpClient);
  private baseUrl = '/api/users';
  private currentUserId = signal<string | null>(null);

  currentUser = httpResource<User>(() => {
    const id = this.currentUserId();
    return id ? `${this.baseUrl}/${id}` : undefined;
  });

  selectUser(id: string) {
    this.currentUserId.set(id);
  }

  getAll() {
    return this.http.get<User[]>(this.baseUrl);
  }

  getById(id: string) {
    return this.http.get<User>(`${this.baseUrl}/${id}`);
  }

  create(user: Omit<User, 'id'>) {
    return this.http.post<User>(this.baseUrl, user);
  }

  update(id: string, user: Partial<User>) {
    return this.http.patch<User>(`${this.baseUrl}/${id}`, user);
  }

  delete(id: string) {
    return this.http.delete<void>(`${this.baseUrl}/${id}`);
  }
}
```

## Caching Strategies

### Simple In-Memory Cache

```typescript
import { Service, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, of, tap } from 'rxjs';

@Service()
export class CachedUserService {
  private http = inject(HttpClient);
  private cache = new Map<string, { data: User; timestamp: number }>();
  private cacheDurationMs = 5 * 60 * 1000;

  getUser(id: string): Observable<User> {
    const cached = this.cache.get(id);
    if (cached && Date.now() - cached.timestamp < this.cacheDurationMs) {
      return of(cached.data);
    }

    return this.http.get<User>(`/api/users/${id}`).pipe(
      tap(user => this.cache.set(id, { data: user, timestamp: Date.now() }))
    );
  }

  invalidateCache(id?: string) {
    if (id) this.cache.delete(id);
    else this.cache.clear();
  }
}
```

### Signal Cache

```typescript
import { Service, computed, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';

@Service()
export class UserCacheService {
  private http = inject(HttpClient);
  private usersCache = signal<Map<string, User>>(new Map());

  users = computed(() => Array.from(this.usersCache().values()));

  getUser(id: string): User | undefined {
    return this.usersCache().get(id);
  }

  async fetchUser(id: string): Promise<User> {
    const cached = this.getUser(id);
    if (cached) return cached;

    const user = await firstValueFrom(this.http.get<User>(`/api/users/${id}`));
    this.usersCache.update(cache => {
      const next = new Map(cache);
      next.set(id, user);
      return next;
    });
    return user;
  }
}
```

## Pagination

### Paginated Resource

```typescript
interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

@Component({
  template: `
    @if (usersResource.isLoading()) {
      <app-spinner />
    } @else if (usersResource.hasValue()) {
      <ul>
        @for (user of usersResource.value().data; track user.id) {
          <li>{{ user.name }}</li>
        }
      </ul>
    }
  `,
})
export class UsersListComponent {
  page = signal(1);
  pageSize = signal(10);

  usersResource = httpResource<PaginatedResponse<User>>(() => ({
    url: '/api/users',
    params: {
      page: this.page().toString(),
      pageSize: this.pageSize().toString(),
    },
  }));
}
```

### Infinite Scroll

```typescript
import { Component, computed, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';

@Component({
  template: `...`,
})
export class InfiniteUsersComponent {
  private http = inject(HttpClient);
  private page = signal(1);
  private users = signal<User[]>([]);
  private totalPages = signal(1);

  allUsers = this.users.asReadonly();
  isLoading = signal(false);
  hasMore = computed(() => this.page() < this.totalPages());

  async loadMore() {
    await this.loadPage(this.page() + 1);
  }

  private async loadPage(page: number) {
    this.isLoading.set(true);
    try {
      const response = await firstValueFrom(
        this.http.get<PaginatedResponse<User>>('/api/users', {
          params: { page: page.toString(), pageSize: '20' },
        })
      );
      this.users.update(v => [...v, ...response.data]);
      this.page.set(page);
      this.totalPages.set(response.totalPages);
    } finally {
      this.isLoading.set(false);
    }
  }
}
```

## File Upload

### Single File

```typescript
import { Component, inject, signal } from '@angular/core';
import { HttpClient, HttpEventType } from '@angular/common/http';

@Component({
  template: `
    <input type="file" (change)="onFileSelected($event)" />
    @if (uploadProgress() !== null) {
      <progress [value]="uploadProgress()" max="100"></progress>
    }
  `,
})
export class FileUploadComponent {
  private http = inject(HttpClient);
  uploadProgress = signal<number | null>(null);

  onFileSelected(event: Event) {
    const file = (event.target as HTMLInputElement).files?.[0];
    if (!file) return;

    const formData = new FormData();
    formData.append('file', file);

    this.http.post('/api/upload', formData, {
      reportProgress: true,
      observe: 'events',
    }).subscribe(evt => {
      if (evt.type === HttpEventType.UploadProgress && evt.total) {
        this.uploadProgress.set(Math.round((100 * evt.loaded) / evt.total));
      } else if (evt.type === HttpEventType.Response) {
        this.uploadProgress.set(null);
      }
    });
  }
}
```

### Multiple Files

```typescript
uploadFiles(files: FileList) {
  const formData = new FormData();
  for (let i = 0; i < files.length; i++) {
    formData.append('files', files[i]);
  }
  return this.http.post<{ urls: string[] }>('/api/upload-multiple', formData);
}
```

## Request Cancellation

### With `resource()`

```typescript
searchResource = resource({
  params: () => ({ q: this.query() }),
  loader: async ({ params, abortSignal }) => {
    const response = await fetch(`/api/search?q=${params.q}`, {
      signal: abortSignal,
    });
    return response.json();
  },
});
```

### With `HttpClient`

```typescript
import { Component, DestroyRef, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Subscription } from 'rxjs';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';

@Component({
  template: `...`,
})
export class SearchComponent {
  private http = inject(HttpClient);
  private destroyRef = inject(DestroyRef);
  private searchSubscription?: Subscription;

  query = signal('');
  results = signal<Result[]>([]);

  search() {
    this.searchSubscription?.unsubscribe();
    this.searchSubscription = this.http
      .get<Result[]>(`/api/search?q=${this.query()}`)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe(results => this.results.set(results));
  }
}
```

## Debounced Search

```typescript
import { toSignal, toObservable } from '@angular/core/rxjs-interop';
import { catchError, debounceTime, distinctUntilChanged, filter, of, switchMap } from 'rxjs';

results = toSignal(
  toObservable(this.query).pipe(
    debounceTime(300),
    distinctUntilChanged(),
    filter(q => q.length >= 2),
    switchMap(q => this.http.get<Result[]>(`/api/search?q=${q}`)),
    catchError(() => of([]))
  ),
  { initialValue: [] }
);
```

## Testing HTTP

### Testing `httpResource`

```typescript
import { TestBed } from '@angular/core/testing';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';

describe('UserComponent', () => {
  let component: UserComponent;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [UserComponent],
      providers: [provideHttpClientTesting()],
    });
    component = TestBed.createComponent(UserComponent).componentInstance;
    httpMock = TestBed.inject(HttpTestingController);
  });

  it('loads user', () => {
    component.userId.set('123');
    const req = httpMock.expectOne('/api/users/123');
    req.flush({ id: '123', name: 'Test User' });
    expect(component.userResource.value()?.name).toBe('Test User');
  });
});
```

### Testing Services

```typescript
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';

describe('UserService', () => {
  let service: UserService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [UserService, provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(UserService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  it('creates user', () => {
    const input = { name: 'Test', email: 'test@example.com' };
    service.create(input).subscribe(user => {
      expect(user.id).toBeDefined();
      expect(user.name).toBe('Test');
    });

    const req = httpMock.expectOne('/api/users');
    expect(req.request.method).toBe('POST');
    req.flush({ id: '1', ...input });
  });
});
```
