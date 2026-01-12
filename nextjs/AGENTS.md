# TurnStay Frontend Agent Instructions

## Project Context

This is a TurnStay frontend application using:
- **Next.js 14+** with App Router
- **React 18** with Server Components
- **TypeScript** for type safety
- **Tailwind CSS** for styling
- **shadcn/ui** for component library
- **Tanstack Query** for data fetching

## Core Principles

1. **Search before writing** - Look for existing components/hooks before creating new ones
2. **Minimal changes** - Make the smallest effective change; avoid over-engineering
3. **Server-first** - Default to Server Components; use 'use client' only when needed
4. **Type everything** - Never use `any`; define proper interfaces

## Key Patterns

### Components
- Use Server Components by default
- Add 'use client' only for interactivity (hooks, events, browser APIs)
- Colocate related files (component, styles, tests, types)

### Data Fetching
- Server Components: Use `fetch` with caching
- Client Components: Use Tanstack Query for mutations/real-time data
- Never fetch in useEffect for initial data

### Styling
- Use Tailwind CSS utilities
- Avoid custom CSS except for complex animations
- Use CSS variables for theming

### State Management
- URL state for shareable state (searchParams)
- React state for UI-only state
- Tanstack Query for server state

## Commands

```bash
pnpm dev          # Start dev server
pnpm build        # Production build
pnpm lint         # Run ESLint
pnpm test         # Run tests
```

## Detailed Rules

See `.cursor/rules/` for comprehensive guidelines on specific topics.
