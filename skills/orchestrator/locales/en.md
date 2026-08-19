# orchestrator — en

## error_no_task_id
Specify task number, e.g. `запусти 026` / `/task-run 026`.

## error_task_not_found
Task `{task_id}` not found in `Tasks/`.

## fallback_profile_question
Which profile? (1) FEATURE (2) BUG (3) REFACTOR (4) TEST (5) REVIEW (6) EPIC (7) RESEARCH

## confirm_dispatch
Profile: `{profile}`, mode: `{mode}`, stack: `{stack}`, start: `{start_stage}`. Correct?

## error_research_required
Stage `{stage}` requires `Research.md` first. Run Research, or use `--skip-research`.

## error_redo_no_artifact
Cannot `redo` `{stage}` — its artifact does not exist. Use `run --from {stage}` instead.

## stage_done_prompt
`{stage}` complete. Continue to next? [Yes / Edit / No]

## stage_done_prompt_with_questions
`{stage}` complete, but the artifact still has open questions:

{questions}

What now?

## stage_done_option_continue
Continue to next stage

## stage_done_option_resolve
Resolve open questions now

## stage_done_option_edit
Edit artifact manually

## stage_done_dialog_question
Question {n}/{total} — `{section}`: {text}

## stage_done_dialog_answer
Answer

## stage_done_dialog_defer
Defer (DEFERRED)

## stage_done_dialog_skip
Skip (return later)

## auq_stage_recovery_question
Stage `{invalid_stage}` is not part of profile `{profile}`. Allowed: {profile_stages_list}. Pick one:

## auq_stage_override_question
Pick a different starting stage for profile `{profile}`:

## auq_stage_recovery_recommended_suffix
(Recommended)

## auq_confirm_dispatch_pick_stage
No, pick a different stage

## error_stage_not_in_profile
`{invalid_stage}` is not a valid stage of profile `{profile}`. Allowed: {profile_stages_list}.

## confirm_dispatch_yes
Yes

## confirm_dispatch_cancel
Cancel

## auq_axis_ui_question
Which UI framework does this task use?

## auq_axis_async_question
Which async approach does this task use?

## auq_axis_di_question
Which Dependency Injection approach does this task use?

## auq_axis_architecture_question
Which architecture does this task use?

## auq_axis_platform_question
Which target platform does this task use?

## auq_axis_tests_question
Which test framework does this task use?

## auq_research_agent_question
Which agent should run the Research stage?

## auq_research_agent_architect
Architect — feasibility, comparative analysis, domain investigation

## auq_research_agent_diagnostics
Diagnostics — audit, inventory, pattern hunt

## auq_research_agent_security
Security — OWASP, vulnerability, pinning audit

## research_agent_diagnostics_keywords
audit; inventory; grep all

## research_agent_security_keywords
security; OWASP; vulnerability; pinning

## dispatch_method_a
Stages of the {profile} profile run through the workflow pipeline — the runtime holds the sequence, one agent per stage.

## dispatch_method_b
The Workflow tool is not available in this session, so the {profile} profile runs through its skill. Same stages and same agents; the sequence is held by the assistant rather than by code.
