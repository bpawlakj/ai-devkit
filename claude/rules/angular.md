---
paths:
  - "**/*.ts"
  - "**/*.html"
  - "**/angular.json"
---
# Angular Standards

## Architecture

- **Standalone components** (Angular 17+) as default — `standalone: true`
- Feature modules for logical grouping when needed
- Lazy loading via route-based code splitting (`loadComponent` / `loadChildren`)
- Shared module for reusable pipes, directives, and utility components

## Components

- **Smart (container)** components: handle data fetching, state, and orchestration
- **Dumb (presentational)** components: receive data via `@Input()`, emit events via `@Output()`
- **`OnPush` change detection** by default for better performance
- Keep templates under 50 lines — extract into sub-components when larger

```typescript
@Component({
    selector: "app-order-list",
    standalone: true,
    changeDetection: ChangeDetectionStrategy.OnPush,
    imports: [CommonModule, OrderCardComponent],
    templateUrl: "./order-list.component.html",
})
export class OrderListComponent {
    orders = input.required<Order[]>();
    orderSelected = output<Order>();
}
```

## Services

- Singleton services via `providedIn: 'root'`
- Inject via constructor — prefer `inject()` function (Angular 14+) for standalone contexts
- Services handle business logic and API calls — components stay thin

## RxJS

- Use `async` pipe in templates — avoid manual `.subscribe()` in components
- `takeUntilDestroyed()` (Angular 16+) for automatic cleanup in services
- Prefer `switchMap` for search, `concatMap` for ordered writes, `mergeMap` for parallel
- Avoid nested subscribes — compose with operators

```html
<!-- GOOD — async pipe handles subscribe/unsubscribe -->
<div *ngFor="let order of orders$ | async">{{ order.name }}</div>
```

## Signals (Angular 16+)

- Prefer `signal()` for reactive state over `BehaviorSubject` where possible
- Use `computed()` for derived values
- Use `effect()` for side effects reacting to signal changes
- `input()` and `output()` signal-based APIs for component I/O (Angular 17+)

## Forms

- **Reactive forms** (`FormGroup`, `FormControl`, `Validators`) for complex forms
- Template-driven forms only for simple cases (login, search)
- Typed forms (Angular 14+): `FormGroup<{ name: FormControl<string> }>`

## Testing

- **Jest** or Jasmine + Karma for unit tests
- `TestBed.configureTestingModule()` for component/service setup
- `HttpClientTestingModule` / `provideHttpClientTesting()` for HTTP mocking
- Test smart components with service mocks, dumb components with direct input binding
- Shallow testing with `NO_ERRORS_SCHEMA` to isolate component under test

## Style Guide

- Follow Angular CLI conventions: `ng generate component/service/pipe`
- File naming: `order-list.component.ts`, `order.service.ts`, `order.model.ts`
- Barrel exports (`index.ts`) for public API of feature modules
- Prefix selectors: `app-` for application, feature prefix for libraries
