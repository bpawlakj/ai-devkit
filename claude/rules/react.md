---
paths:
  - "**/*.tsx"
  - "**/*.jsx"
---
# React Standards

## Component Patterns

- **Composition over inheritance** — use children, render props, compound components
- Compound components with Context for related UI groups
- Named interfaces for props — avoid inline types and `React.FC` without reason

```typescript
interface ButtonProps {
    variant: "primary" | "secondary";
    onClick: () => void;
    children: React.ReactNode;
}
```

## Custom Hooks

Extract reusable logic into hooks:

```typescript
function useDebounce<T>(value: T, delay: number): T {
    const [debounced, setDebounced] = useState(value);
    useEffect(() => {
        const timer = setTimeout(() => setDebounced(value), delay);
        return () => clearTimeout(timer);
    }, [value, delay]);
    return debounced;
}
```

## State Management

- Local state: `useState` for simple, `useReducer` for complex
- Shared state: Context + `useReducer` — define clear action types
- Avoid prop drilling beyond 3 levels — use Context or composition
- Server state: React Query / SWR for data fetching + caching

## Performance

- `useMemo` / `useCallback` only for genuinely expensive computations — don't wrap everything
- `React.lazy` + `Suspense` for code splitting
- Virtualization (`@tanstack/react-virtual`) for lists >100 items
- Avoid creating objects/functions inline in JSX when they cause re-renders

## Forms

- Controlled components with validation logic
- Track form state and errors, prevent submission until valid
- Consider React Hook Form or Formik for complex forms

## Error Boundaries

Class components that catch render errors and show fallback UI:

```typescript
class ErrorBoundary extends Component<Props, State> {
    static getDerivedStateFromError(error: Error) {
        return { hasError: true, error };
    }
    render() {
        if (this.state.hasError) return <ErrorFallback error={this.state.error} />;
        return this.props.children;
    }
}
```

## Accessibility

- Semantic HTML elements (`<button>`, `<nav>`, `<main>`, `<dialog>`)
- ARIA attributes when semantic HTML isn't sufficient
- Keyboard navigation for interactive components (dropdowns, modals)
- Focus management: trap focus in modals, restore on close
- All images need `alt` text

## Key Rules

- Always provide stable `key` props on list items — never use array index for dynamic lists
- Clean up effects: return cleanup functions from `useEffect`
- Check dependency arrays — include all values used inside the effect
- Keep components focused: split when >200 lines or >3 responsibilities
