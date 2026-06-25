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
    subtitle: 'Queued while the backend model is being clarified.',
  },
  {
    id: 'journal',
    path: '/journal',
    label: 'Journal',
    title: 'Journal',
    subtitle: 'Queued while the backend model is being clarified.',
  },
  {
    id: 'calendar',
    path: '/calendar',
    label: 'Calendar',
    title: 'Calendar',
    subtitle: 'Queued while the backend model is being clarified.',
  },
  {
    id: 'plan',
    path: '/plan',
    label: 'Plan',
    title: 'Plan',
    subtitle: 'Queued while the backend model is being clarified.',
  },
  {
    id: 'progress',
    path: '/progress',
    label: 'Progress',
    title: 'Progress',
    subtitle: 'Queued while the backend model is being clarified.',
  },
  {
    id: 'sessions',
    path: '/sessions',
    label: 'Sessions',
    title: 'Sessions',
    subtitle: 'Queued while the backend model is being clarified.',
  },
  {
    id: 'inventory',
    path: '/inventory',
    label: 'Inventory',
    title: 'Inventory',
    subtitle: 'Queued while the backend model is being clarified.',
  },
  {
    id: 'event-types',
    path: '/event-types',
    label: 'Event Types',
    title: 'Event Types',
    subtitle: 'Queued while the backend model is being clarified.',
  },
  {
    id: 'resource-types',
    path: '/resource-types',
    label: 'Resource Types',
    title: 'Resource Types',
    subtitle: 'Queued while the backend model is being clarified.',
  },
]

export const activeRoute = writable<AppRoute>(routeFromPath(window.location.pathname))

window.addEventListener('popstate', () => {
  transitionRoute(() => activeRoute.set(routeFromPath(window.location.pathname)))
})

export function navigate(route: AppRoute): void {
  const info = routeInfo(route)
  transitionRoute(() => {
    window.history.pushState({}, '', info.path)
    activeRoute.set(route)
  })
}

export function routeInfo(route: AppRoute): RouteInfo {
  return routes.find((candidate) => candidate.id === route) ?? routes[0]
}

function routeFromPath(pathname: string): AppRoute {
  const normalized = pathname === '/' || pathname === '/dashboard' ? '/today' : pathname
  return routes.find((route) => route.path === normalized)?.id ?? 'today'
}

function transitionRoute(update: () => void): void {
  if (!('startViewTransition' in document)) {
    update()
    return
  }

  document.startViewTransition(update)
}
