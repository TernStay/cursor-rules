# Next.js Frontend Development Agent Instructions

## Project Context

This project uses Next.js for frontend development with modern React patterns. The specific technology stack may vary by project, but common patterns include:

- **Next.js 14+** with App Router
- **React 18** with Server Components
- **TypeScript** for type safety
- **Tailwind CSS** or similar styling solutions
- **Component libraries** (shadcn/ui, etc.)
- **Data fetching** libraries (Tanstack Query, SWR, etc.)

## Core Principles

1. **Search before writing** - Look for existing components/hooks before creating new ones
2. **Minimal changes** - Make the smallest effective change; avoid over-engineering
3. **Server-first** - Default to Server Components; use 'use client' only when needed
4. **Type everything** - Never use `any`; define proper interfaces
5. **Accessibility** - Build inclusive components from the start

## Key Patterns

### Components
- Use Server Components by default for better performance
- Add 'use client' only for interactivity (hooks, events, browser APIs)
- Keep components focused on single responsibilities
- Use composition over complex prop drilling

### Data Fetching
- Server Components: Use `fetch` with appropriate caching strategies
- Client Components: Use data fetching libraries for mutations and real-time data
- Avoid fetching in useEffect for initial page data
- Handle loading and error states consistently

### Styling
- Use utility-first CSS frameworks (Tailwind, etc.)
- Maintain consistent design tokens and spacing
- Consider responsive design from the start
- Use CSS variables for theming when needed

### State Management
- URL state for shareable/filterable state (searchParams)
- React state for UI-only state
- Data fetching libraries for server state
- Context providers for cross-component state when necessary

## Commands

Common development commands (may vary by project):

```bash
npm run dev      # Start dev server
npm run build    # Production build
npm run lint     # Run ESLint
npm run test     # Run tests
npm run type-check # TypeScript checking
```

## Detailed Rules

See `.cursor/rules/` for comprehensive guidelines on specific topics and patterns.
