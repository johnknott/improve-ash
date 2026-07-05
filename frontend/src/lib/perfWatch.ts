// Dev-only main-thread stall attribution. When a frame blocks long enough
// to feel (>200ms), Chrome's Long Animation Frames API tells us which
// scripts were responsible — our modules (localhost), a browser extension
// (chrome-extension://...), or nothing attributable (GC / browser / system
// pressure). The warn lands in the dev error badge via the console tee.

type LoafScript = {
  name?: string
  sourceURL?: string
  invoker?: string
  duration: number
}

type LoafEntry = PerformanceEntry & {
  scripts?: LoafScript[]
}

const THRESHOLD_MS = 200

export function installPerfWatch(): void {
  if (!('PerformanceObserver' in window)) {
    return
  }

  try {
    const observer = new PerformanceObserver((list) => {
      for (const entry of list.getEntries() as LoafEntry[]) {
        if (entry.duration < THRESHOLD_MS) {
          continue
        }

        const attribution = (entry.scripts ?? [])
          .filter((script) => script.duration >= 50)
          .sort((a, b) => b.duration - a.duration)
          .slice(0, 3)
          .map(
            (script) =>
              `${Math.round(script.duration)}ms ${shortSource(script.sourceURL || script.name || script.invoker || '?')}`,
          )
          .join('; ')

        console.warn(
          `[perf] main thread blocked ${Math.round(entry.duration)}ms — ${
            attribution || 'no script attribution (GC, extension isolate, or system pressure)'
          }`,
        )
      }
    })

    // long-animation-frame is Chrome 123+; other browsers throw and we
    // simply run without attribution there.
    observer.observe({ type: 'long-animation-frame', buffered: true })
  } catch {
    // Not supported in this browser — nav/request marks still apply.
  }
}

function shortSource(source: string): string {
  if (source.startsWith('chrome-extension://')) {
    return `EXTENSION ${source.slice(0, 60)}`
  }

  try {
    const url = new URL(source)
    return url.pathname.split('/').slice(-2).join('/') || source
  } catch {
    return source.slice(0, 60)
  }
}
