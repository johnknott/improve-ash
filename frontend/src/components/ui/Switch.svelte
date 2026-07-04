<script lang="ts">
  import { Switch } from 'bits-ui'

  let {
    checked = $bindable(false),
    disabled = false,
    label = '',
  }: {
    checked?: boolean
    disabled?: boolean
    label?: string
  } = $props()
</script>

<Switch.Root bind:checked class="switch-root" {disabled} aria-label={label || undefined}>
  <Switch.Thumb class="switch-thumb" />
</Switch.Root>
