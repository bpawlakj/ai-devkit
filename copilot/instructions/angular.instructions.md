---
applyTo: "**/*.ts,**/*.html,**/angular.json"
---

# Angular Standards

## Architecture
- Standalone components (Angular 17+), feature modules, lazy loading via routes.
- Smart (container) vs dumb (presentational) component split.

## Components
- `OnPush` change detection by default. Templates under 50 lines.
- `input()` and `output()` signal-based APIs (Angular 17+).

## Services
- `providedIn: 'root'` singletons. `inject()` function for standalone contexts.

## RxJS
- `async` pipe in templates. `takeUntilDestroyed()` for cleanup.
- `switchMap` for search, `concatMap` for ordered writes. No nested subscribes.

## Signals (Angular 16+)
- `signal()` for reactive state, `computed()` for derived, `effect()` for side effects.

## Forms
- Reactive forms (`FormGroup`, `FormControl`) over template-driven for complex forms.
- Typed forms (Angular 14+).

## Testing
- Jest or Jasmine + Karma. `TestBed` for components, `HttpClientTestingModule` for HTTP.
- Shallow testing with `NO_ERRORS_SCHEMA` to isolate components.

## Style
- Angular CLI conventions (`ng generate`). Barrel exports. `app-` selector prefix.
