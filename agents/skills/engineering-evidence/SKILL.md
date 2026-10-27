---
name: engineering-evidence
description: Use when investigating bugs, comparing contracts, interpreting probes, or reporting behavior. Separate observations from conclusions and qualify each claim.
---

# Engineering evidence

Use the smallest observation that can change the decision.
Apply this workflow within the task, not as another deliverable.
Do not create a checklist, report schema, instrument, or permanent test by default.

## Choose the question

1. State the behavior or decision that needs an answer.
2. Identify the expected behavior from a source independent of the implementation under examination.
3. Choose an observation that can distinguish the competing explanations.

An oracle is the source that defines an expected result.
Useful sources include a specification, an established consumer, a reference implementation, or a captured interaction.
Check the source revision and its applicability to the target.
Distinguish required behavior from recommendations and examples.
Do not count copies of one source as independent evidence.
Resolve disagreements explicitly instead of selecting the source that makes the current code pass.

## Make the observation

Accept a reported failure as an observation.
Do not repeat it only to check the report.
Use existing logs and artifacts when their inputs and context answer the question.
Reproduce a failure when reproduction answers an unresolved question about its cause or conditions.

For a search or probe, establish that the operation can observe a known-present case.
Check access, scope, input, and tool errors before interpreting an empty result as absence.
Trace a failure across the relevant boundary, such as a caller, protocol, process, or storage interface.
Add temporary instrumentation only when the available observations cannot distinguish the explanations.
Keep secrets out of logs and model context.

Change one relevant variable when testing a hypothesis.
Compare the result with the chosen oracle, not only with the previous implementation.
Check a test's expectation before changing production code to satisfy it.
A fixture describes its inputs, not the product's requirements.

## Match the claim to the observation

Do not add observations that the evidence does not contain.
An available stub, interface, or tool does not establish that a call occurred.
A missing trace leaves execution unknown, not disproved.

| Observation | What it establishes | What it does not establish |
| --- | --- | --- |
| A search returns no matches | That query found nothing in its visible scope | The feature or data does not exist |
| A stub returns success | The exercised caller accepts that reply | The real dependency completes the requested work |
| A wire trace matches a specification | The observed fields and sequence match that contract | The remote system accepts or completes the operation |
| A test passes | Its assertions hold for the exercised inputs | The expectation is correct or another environment behaves identically |
| A transfer exits successfully | The command reports success | The destination contains the complete source |

Check backups and transfers by restoring or reading the destination and comparing content.
Inspect the current checkout and relevant revisions before relying on remembered results.
Retain an earlier result when its relevant inputs remain unchanged.
Repeat a check when changed inputs invalidate that result, not for each status message.

## Finish the work

Exercise the changed behavior through its consumer or boundary when execution is available and permitted.
Follow the project's conventions for tests and CI.
Keep permanent tests for meaningful behavior, failures, and safety boundaries.
Do not turn every investigation into a test suite or every useful check into a merge gate.

When execution is unavailable, finish the reachable source, format, and contract checks.
State the missing capability and the conclusion that remains unknown.
Do not claim a required outcome that the available evidence cannot establish.
Keep physical qualification separate from source checks and emulator results.

Report the conclusion, the observation that supports it, and any material limit.
Include the command, relevant revision or input, and artifact location when another person needs to inspect or repeat it.
Keep evidence that supports an active claim or unresolved question.
Remove temporary scaffolds after preserving that evidence.

## Related practices

The [systematic-debugging skill](https://github.com/obra/superpowers/blob/main/skills/systematic-debugging/SKILL.md) describes hypothesis-driven diagnosis.
The [verification-before-completion skill](https://github.com/obra/superpowers/blob/main/skills/verification-before-completion/SKILL.md) separates evidence from assertions.
This skill does not import their mandatory phases, preset retry counts, or per-message verification requirements.
