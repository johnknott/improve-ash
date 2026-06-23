export function listField(value: Record<string, unknown> | undefined, key: string): string[] {
  const list = value?.[key]
  return Array.isArray(list) ? list.filter((item): item is string => typeof item === 'string') : []
}

export function roleList(value: Record<string, unknown> | undefined) {
  const roles = value?.roles

  if (!Array.isArray(roles)) {
    return []
  }

  return roles
    .filter((role): role is Record<string, unknown> => typeof role === 'object' && role !== null)
    .map((role) => ({
      role: String(role.role ?? ''),
      itemTypeKey: typeof role.item_type_key === 'string' ? role.item_type_key : null,
      required: role.required === true,
    }))
    .filter((role) => role.role)
}

export function ruleList(value: Record<string, unknown> | undefined) {
  const rules = value?.rules
  return Array.isArray(rules) ? rules.filter((rule): rule is Record<string, unknown> => isRecord(rule)) : []
}

export function hasEntries(value: Record<string, unknown> | undefined | null): boolean {
  return !!value && Object.keys(value).length > 0
}

export function formatKey(value: string): string {
  return value.replaceAll('_', ' ')
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null
}
