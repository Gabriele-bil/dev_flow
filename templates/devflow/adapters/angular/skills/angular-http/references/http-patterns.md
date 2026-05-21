# Angular HTTP Patterns

## Table of Contents
- [Service Layer Pattern](#service-layer-pattern)
- [Caching Strategies](#caching-strategies)
- [Pagination](#pagination)
- [File Upload](#file-upload)
- [Request Cancellation](#request-cancellation)
- [Debounced Search](#debounced-search)
- [Testing HTTP](#testing-http)

## Service Layer Pattern

Keep HTTP orchestration inside services.

```typescript
import { Injectable, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { httpResource } from '@angular/common/http';

export interface User {
  id: string;
  name: string;
  email: string;
}

@Injectable({ providedIn: 'root' })
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
import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, of, tap } from 'rxjs';

@Injectable({ providedIn: 'root' })
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
import { Injectable, computed, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';

@Injectable({ providedIn: 'root' })
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
