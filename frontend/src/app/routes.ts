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
  | 'item-types'

export type RouteParams = Record<string, string>

export type RouteLocation = {
  route: AppRoute
  params: RouteParams
}

export type RouteInfo = {
  id: AppRoute
  path: string
  label: string
  title: string
}

// Path segments starting with ':' are params, e.g. '/items/:id'.
export const routes: RouteInfo[] = [
  {
    id: 'today',
    path: '/today',
    label: 'Today',
    title: 'Today',
  },
  {
    id: 'journal',
    path: '/journal',
    label: 'Journal',
    title: 'Journal',
  },
  {
    id: 'calendar',
    path: '/calendar',
    label: 'Calendar',
    title: 'Calendar',
  },
  {
    id: 'plan',
    path: '/plan',
    label: 'Plan',
    title: 'Plan',
  },
  {
    id: 'progress',
    path: '/progress',
    label: 'Progress',
    title: 'Progress',
  },
  {
    id: 'sessions',
    path: '/sessions',
    label: 'Sessions',
    title: 'Sessions',
  },
  {
    id: 'inventory',
    path: '/inventory',
    label: 'Inventory',
    title: 'Inventory',
  },
  {
    id: 'event-types',
    path: '/event-types',
    label: 'Event Types',
    title: 'Event Types',
  },
  {
    id: 'item-types',
    path: '/item-types',
    label: 'Item Types',
    title: 'Item Types',
  },
]

export const activeRoute = writable<RouteLocation>(locationFromPath(window.location.pathname))

window.addEventListener('popstate', () => {
  activeRoute.set(locationFromPath(window.location.pathname))
})

export function navigate(route: AppRoute, params: RouteParams = {}): void {
  window.history.pushState({}, '', buildPath(route, params))
  activeRoute.set({ route, params })
}

export function routeInfo(route: AppRoute): RouteInfo {
  return routes.find((candidate) => candidate.id === route) ?? routes[0]
}

export function buildPath(route: AppRoute, params: RouteParams = {}): string {
  return routeInfo(route)
    .path.split('/')
    .map((segment) =>
      segment.startsWith(':') ? encodeURIComponent(params[segment.slice(1)] ?? '') : segment,
    )
    .join('/')
}

function locationFromPath(pathname: string): RouteLocation {
  const normalized = pathname === '/' || pathname === '/dashboard' ? '/today' : pathname

  for (const route of routes) {
    const params = matchPath(route.path, normalized)

    if (params) {
      return { route: route.id, params }
    }
  }

  return { route: 'today', params: {} }
}

function matchPath(pattern: string, pathname: string): RouteParams | null {
  const patternSegments = pattern.split('/').filter(Boolean)
  const pathSegments = pathname.split('/').filter(Boolean)

  if (patternSegments.length !== pathSegments.length) {
    return null
  }

  const params: RouteParams = {}

  for (let index = 0; index < patternSegments.length; index++) {
    const expected = patternSegments[index]

    if (expected.startsWith(':')) {
      params[expected.slice(1)] = decodeURIComponent(pathSegments[index])
    } else if (expected !== pathSegments[index]) {
      return null
    }
  }

  return params
}
