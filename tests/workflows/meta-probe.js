export const meta = {
  name: 'meta-probe',
  description: 'Probe: is the meta binding readable from inside the script body?',
  whenToUse: 'Run by hand while implementing the progress-visibility plan. Not a profile.',
  phases: [
    { title: 'Alpha', detail: 'first', agent: 'swift-architect' },
    { title: 'Beta', detail: 'second', agent: 'swift-refactorer / swift-tester' },
  ],
}

let visible = false
let map = null
let error = null

try {
  map = Object.fromEntries(meta.phases.map((p) => [p.title, p.agent]))
  visible = true
} catch (e) {
  error = e && e.message ? e.message : String(e)
}

return { visible, map, error, phaseCount: visible ? meta.phases.length : null }
