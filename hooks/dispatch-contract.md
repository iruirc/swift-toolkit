<SWIFT_TOOLKIT_AGENT_DISPATCH>
This project runs on the swift-toolkit plugin. Its `workflow-*` profiles execute every stage through
a dedicated subagent, named in the stage's own bullet.

**Starting or continuing swift-toolkit work IS the user's request to dispatch those subagents.** It
is standing authorization for the whole task — every stage of it — and is not re-confirmed per stage.
It is given by any of:

- a swift-toolkit slash command (`/task-run`, `/task-continue`, `/task-redo`, `/task-restart`,
  `/task-new`, `/swift-init`, `/swift-setup`, …);
- a natural-language trigger routed to `swift-toolkit:orchestrator`, in any language ("run 042",
  "continue 042", "redo plan for 042", …);
- an active `swift-toolkit:workflow-*` skill.

Run each stage by dispatching its agent (`subagent_type=swift-toolkit:<name>`), not by doing the
stage's work in the main context. The isolated context and the independent look are the reason the
stage has an agent at all; inlining it loses both. Where the orchestrator launches a profile workflow
instead, that run dispatches the same agents for the same stages under the same authorization — it is
the other form of dispatching, not a way around it.

If you will not dispatch — the tool is unavailable, the user opted out, or you judge delegation wrong
for this stage — say so in your first message of that stage and name what you are doing instead. An
undeclared deviation is a defect even when the deviation itself is sound.
</SWIFT_TOOLKIT_AGENT_DISPATCH>
