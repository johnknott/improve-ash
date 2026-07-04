export function formatDate(value: string, options: Intl.DateTimeFormatOptions = {}): string {
  return new Intl.DateTimeFormat('en-GB', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    ...options,
  }).format(new Date(`${value}T12:00:00`))
}

export function formatDateTime(value: string): string {
  return new Intl.DateTimeFormat('en-GB', {
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value))
}

export function greeting(date = new Date()): string {
  const hour = date.getHours()

  if (hour < 12) return 'Good morning'
  if (hour < 18) return 'Good afternoon'
  return 'Good evening'
}

// Date-only math for ISO `YYYY-MM-DD` strings. Everything runs at UTC noon
// so DST shifts can never move a date-only value across midnight.

export function todayIso(): string {
  return new Date().toISOString().slice(0, 10)
}

export function utcDate(date: string): Date {
  const [year, month, day] = date.split('-').map(Number)
  return new Date(Date.UTC(year, month - 1, day, 12))
}

export function isoDate(date: Date): string {
  return [
    date.getUTCFullYear(),
    String(date.getUTCMonth() + 1).padStart(2, '0'),
    String(date.getUTCDate()).padStart(2, '0'),
  ].join('-')
}

export function addDays(date: string, days: number): string {
  const next = utcDate(date)
  next.setUTCDate(next.getUTCDate() + days)
  return isoDate(next)
}

export function addMonths(date: string, months: number): string {
  const next = utcDate(date)
  const day = next.getUTCDate()

  next.setUTCMonth(next.getUTCMonth() + months)

  if (next.getUTCDate() !== day) {
    next.setUTCDate(0)
  }

  return isoDate(next)
}

export function daysBetweenInclusive(startsOn: string, endsOn: string): number {
  const start = utcDate(startsOn).getTime()
  const end = utcDate(endsOn).getTime()

  return Math.floor((end - start) / 86_400_000) + 1
}
