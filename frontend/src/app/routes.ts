import { writable } from 'svelte/store'

export type AppRoute =
  | 'today'
  | 'journal'
  | 'calendar'
  | 'plan'
  | 'progress'
  | 'sessions'
  | 'inventory'
  | 'event-types'
  | 'resource-types'

export type RouteInfo = {
  id: AppRoute
  path: string
  label: string
  title: string
  subtitle: string
}

export const routes: RouteInfo[] = [
  {
    id: 'today',
    path: '/today',
    label: 'Today',
    title: 'Today',
    subtitle: 'What is due, what happened, and what comes next.',
  },
  {
    id: 'journal',
    path: '/journal',
    label: 'Journal',
    title: 'Journal',
    subtitle: 'The record of what actually happened.',
  },
  {
    id: 'calendar',
    path: '/calendar',
    label: 'Calendar',
    title: 'Calendar',
    subtitle: 'A dated view of plan work.',
  },
  {
    id: 'plan',
    path: '/plan',
    label: 'Plan',
    title: 'Plan',
    subtitle: 'Inspect the current plan and its working parts.',
  },
  {
    id: 'progress',
    path: '/progress',
    label: 'Progress',
    title: 'Progress',
    subtitle: 'Signals, trends, and progress checks.',
  },
  {
    id: 'sessions',
    path: '/sessions',
    label: 'Sessions',
    title: 'Sessions',
    subtitle: 'Session templates and recent session history.',
  },
  {
    id: 'inventory',
    path: '/inventory',
    label: 'Inventory',
    title: 'Inventory',
    subtitle: 'Stateful plan resources and current quantities.',
  },
  {
    id: 'event-types',
    path: '/event-types',
    label: 'Event Types',
    title: 'Event Types',
    subtitle: 'The event shapes this plan can log.',
  },
  {
    id: 'resource-types',
    path: '/resource-types',
    label: 'Resource Types',
    title: 'Resource Types',
    subtitle: 'The kinds of things this plan tracks.',
  },
]

export const activeRoute = writable<AppRoute>(routeFromPath(window.location.pathname))

window.addEventListener('popstate', () => {
  activeRoute.set(routeFromPath(window.location.pathname))
})

export function navigate(route: AppRoute): void {
  const info = routeInfo(route)
  window.history.pushState({}, '', info.path)
  activeRoute.set(route)
}

export function routeInfo(route: AppRoute): RouteInfo {
  return routes.find((candidate) => candidate.id === route) ?? routes[0]
}

function routeFromPath(pathname: string): AppRoute {
  const normalized = pathname === '/' || pathname === '/dashboard' ? '/today' : pathname
  return routes.find((route) => route.path === normalized)?.id ?? 'today'
}
