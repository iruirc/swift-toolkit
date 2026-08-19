export const meta = {
  name: 'nest-parent',
  description: 'U5 probe, outer half: calls workflow() on a child script path taken from args and reports what came back',
  whenToUse: 'Manual smoke test only, run by a maintainer via Workflow({scriptPath}) to settle whether EPIC can drive its steps by nesting.',
  phases: [],
}

if (!args || !args.child) return { error: 'pass {child: "<abs path to nest-child.js>"} as args' }

let outcome
try {
  const r = await workflow({ scriptPath: args.child }, { depth: 2, grandchild: args.grandchild || null })
  outcome = { nested: true, childReturned: r }
} catch (e) {
  outcome = { nested: false, threw: e && e.message ? e.message : String(e) }
}

return { parentSawArgs: Object.keys(args).sort(), ...outcome }
