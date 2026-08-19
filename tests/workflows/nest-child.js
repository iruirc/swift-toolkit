export const meta = {
  name: 'nest-child',
  description: 'U5 probe, inner half: reports the args it received and whether a second level of workflow() nesting is possible',
  whenToUse: 'Manual smoke test only, launched by tests/workflows/nest-parent.js. Never run directly.',
  phases: [],
}

// Spawns no agent — the question is whether the runtime delivers args and a return value
// across a workflow() boundary, not whether an agent can be dispatched from inside one.
let grandchild = 'not attempted'
if (args && args.grandchild) {
  try {
    const r = await workflow({ scriptPath: args.grandchild }, { depth: 3 })
    grandchild = `succeeded: ${JSON.stringify(r)}`
  } catch (e) {
    grandchild = `threw: ${e && e.message ? e.message : String(e)}`
  }
}

return { child: true, argsSeen: args ? Object.keys(args).sort() : null, depth: args ? args.depth : null, grandchild }
