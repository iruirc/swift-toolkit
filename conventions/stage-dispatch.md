# Stage Dispatch

A `workflow-*` stage that names an agent names its owner. That name is an execution contract, not a
hint: the stage runs inside that agent, dispatched with the host's subagent mechanism
(`subagent_type=swift-toolkit:<name>` in Claude Code). Stage work performed in the main context
loses the two things the stage has an agent for — an isolated context and an independent look.

The same contract holds when the profile runs as a workflow script (`workflows/profile-*.js`): the
script dispatches the stage's agent through `agent({agentType: 'swift-toolkit:<name>'})`. Which of the
two forms a task takes is the orchestrator's choice; that a stage runs inside its own agent is not.

## Standing authorization

Hosts may carry a standing instruction not to spawn subagents unless the user asked. A user who
starts or continues swift-toolkit work HAS asked, for the whole task:

- a swift-toolkit slash command (`/task-run`, `/task-continue`, `/task-redo`, `/task-restart`,
  `/task-new`, `/swift-init`, `/swift-setup`, …);
- a natural-language trigger routed to `swift-toolkit:orchestrator`, in any language;
- an active `swift-toolkit:workflow-*` skill, or a running `profile-*` workflow.

The authorization covers every stage of that task and is not re-confirmed per stage.

## Declared deviation

Delegation may be skipped — the host exposes no subagent mechanism, the user opted out, or a stage
is small enough that the round trip costs more than it buys. In every such case the deviation is
announced in the first message of the stage, naming what runs instead. An undeclared deviation is a
defect even when the deviation itself is sound.

A panel stage (two agents on one stage) may run its agents in parallel or sequentially — that choice
is the orchestrator's and needs no announcement.
