import { mount } from 'svelte'
import '@fontsource-variable/geist/index.css'
import './app.css'
import App from './App.svelte'
import { installDevErrorCapture } from './lib/devErrors'
import { installPerfWatch } from './lib/perfWatch'

// Installed before mount so even first-render crashes are captured.
if (import.meta.env.DEV) {
  installDevErrorCapture()
  installPerfWatch()
}

const app = mount(App, {
  target: document.getElementById('app')!,
})

export default app
