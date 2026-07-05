import { mount } from 'svelte'
import '@fontsource-variable/geist/index.css'
import './app.css'
import App from './App.svelte'
import { installDevErrorCapture } from './lib/devErrors'

// Installed before mount so even first-render crashes are captured.
if (import.meta.env.DEV) {
  installDevErrorCapture()
}

const app = mount(App, {
  target: document.getElementById('app')!,
})

export default app
