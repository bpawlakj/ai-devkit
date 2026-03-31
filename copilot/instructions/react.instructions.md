---
applyTo: "**/*.tsx,**/*.jsx"
---

# React Standards

## Components
- Composition over inheritance. Compound components with Context. Named interfaces for props.
- Extract reusable logic into custom hooks (`useDebounce`, `useToggle`).

## State
- `useState` for simple, `useReducer` for complex. Avoid prop drilling >3 levels.
- Server state: React Query / SWR for data fetching + caching.

## Performance
- `useMemo`/`useCallback` for expensive ops. `React.lazy` + Suspense for code splitting.
- Virtualization for lists >100 items. Avoid inline objects/functions causing re-renders.

## Forms
- Controlled components with validation. React Hook Form for complex forms.

## Error Boundaries
- Class components catching render errors with fallback UI.

## Accessibility
- Semantic HTML, ARIA attributes, keyboard navigation, focus management.
- All images need `alt` text. Trap focus in modals.

## Key Rules
- Stable `key` props (never array index for dynamic lists). Clean up effects.
- Check dependency arrays. Split components >200 lines or >3 responsibilities.
