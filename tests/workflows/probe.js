export const meta = {
  name: 'probe',
  description: 'Smoke test for the runtime facts a swift-toolkit profile workflow depends on: args delivery, the budget global, and plugin-namespaced agentType resolution',
  whenToUse: 'Manual smoke test only, run by a maintainer via Workflow({scriptPath}). It lives under tests/ rather than workflows/ so it is never registered as /swift-toolkit:probe in a user session.',
  phases: [
    { title: 'Echo', detail: 'one bounded agent; proves agentType resolves and a schema is enforced' },
  ],
}

// U2 (issue #86156): args has been observed not reaching the sandbox. Report what arrived
// rather than assuming, and normalize both delivery shapes the way the profile scripts will.
const typeOfArgs = typeof args
let parsed = typeof args === 'undefined' ? null : args
let parseNote = 'object delivered directly'

if (typeof args === 'string') {
  try {
    parsed = JSON.parse(args)
    parseNote = 'string delivered, parsed as JSON'
  } catch {
    parsed = null
    parseNote = 'string delivered, NOT valid JSON'
  }
} else if (typeof args === 'undefined') {
  parseNote = 'args is undefined — bug #86156 reproduces on this version'
}

const keys = parsed && typeof parsed === 'object' ? Object.keys(parsed).sort() : null
log(`args: ${typeOfArgs} — ${parseNote}; keys: ${keys ? keys.join(',') : 'none'}`)

const budgetVisible = typeof budget !== 'undefined'
log(`budget global: ${budgetVisible ? 'visible' : 'absent'}`)

// Does a plugin-namespaced agentType resolve? The whole profile design rests on this.
const echo = await agent(
  'Reply only with the JSON object your schema requires: set ok to true and name your own agent role in one short phrase. Do not read files, do not run commands, do not inspect the repository.',
  {
    label: 'echo',
    phase: 'Echo',
    agentType: 'swift-toolkit:swift-architect',
    schema: {
      type: 'object',
      additionalProperties: false,
      required: ['ok', 'role'],
      properties: {
        ok: { type: 'boolean' },
        role: { type: 'string' },
      },
    },
  },
)

return {
  typeOfArgs,
  parseNote,
  keys,
  echoedArgs: parsed,
  budgetVisible,
  budgetTotal: budgetVisible ? budget.total : null,
  agentTypeResolved: echo !== null,
  agentReply: echo,
}
