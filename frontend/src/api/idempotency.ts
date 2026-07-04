// Every write submission carries a fresh client_operation_id plus a stable
// per-browser client_device_id, so flaky-network retries and replays dedupe
// server-side. This is the same contract the mobile client will use.

const DEVICE_ID_KEY = 'improve-device-id'

export function deviceId(): string {
  let id = localStorage.getItem(DEVICE_ID_KEY)

  if (!id) {
    id = crypto.randomUUID()
    localStorage.setItem(DEVICE_ID_KEY, id)
  }

  return id
}

export function operationIdempotency(): {
  client_operation_id: string
  client_device_id: string
} {
  return {
    client_operation_id: crypto.randomUUID(),
    client_device_id: deviceId(),
  }
}
