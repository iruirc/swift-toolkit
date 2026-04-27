# orchestrator — en

## error_no_task_id
Specify task number, e.g. `запусти 026` / `/task-run 026`.

## error_task_not_found
Task `{task_id}` not found in `Tasks/`.

## fallback_profile_question
Which profile? (1) FEATURE (2) BUG (3) REFACTOR (4) TEST (5) REVIEW (6) EPIC

## confirm_dispatch
Profile: `{profile}`, mode: `{mode}`, stack: `{stack}`, start: `{start_stage}`. Correct?

## error_research_required
Stage `{stage}` requires `Research.md` first. Run Research, or use `--skip-research`.

## error_redo_no_artifact
Cannot `redo` `{stage}` — its artifact does not exist. Use `run --from {stage}` instead.

## stage_done_prompt
`{stage}` complete. Continue to next? [Yes / Edit / No]
