# SDR9700 Project Issues

This file is the durable repository-wide ledger for issues identified during
SDR9700 project work. Record findings from implementation, review, testing,
CI, documentation, packaging, release work, hardware validation, security
checks, and repository administration here so they are not lost when they are
outside the immediate task.

## Tracking Rules

- Assign each issue the next sequential `SDR-NNNN` identifier. Never reuse an
  identifier.
- Record a confirmed issue when it is identified, even when it can be resolved
  during the same task. Do not record unsupported speculation as a finding.
- Include concrete evidence, user or project impact, and the next action needed
  to make progress.
- Use one of these statuses: `open`, `investigating`, `blocked`, `deferred`, or
  `resolved`.
- Use one of these severities: `critical`, `high`, `medium`, or `low`.
- Update an existing entry instead of creating a duplicate. Link a GitHub issue
  or pull request when one exists.
- Move completed entries to **Resolved Issues**, adding the resolution and date.
  Do not delete resolved history.
- Do not include credentials, private keys, production data, personal data, or
  other sensitive evidence. Store sensitive local material only under
  `_workspace/private/` and describe it here without exposing it.

## Entry Format

```markdown
### SDR-NNNN: Concise issue title

- Status: `open`
- Severity: `medium`
- Area: Component, workflow, or platform
- Identified: YYYY-MM-DD during the activity that exposed the issue
- Evidence: Reproduction details, logs, test names, or affected paths
- Impact: User-facing or project consequence
- Next action: Specific investigation, decision, or implementation step
- Related: GitHub issue, pull request, commit, or documentation path
```

## Open Issues

No open issues are currently recorded.

## Resolved Issues

### SDR-0001: Intermittent ThreadSanitizer race in CachingQueueTest

- Status: `resolved`
- Severity: `medium`
- Area: Nightly Analysis ThreadSanitizer job, `src/tests/CachingQueueTest.cpp`
- Identified: 2026-09-29 during review of the failed scheduled Nightly
  Analysis run 36585988851 on commit `047b2fe`
- Evidence: TSan reported a data race in
  `CachingQueueTest::deliversValueArrivingDuringBatchEmission` between the
  main thread constructing a `sendValues` slot object in `connect()` and the
  `CachingQueue` worker invoking it. The worker was still emitting a batch left
  by `emitsCacheChangesWithoutHoldingMutex`; `resetSessionState()` in
  `init()` cannot recall a batch already moved out of `items`, and the
  uninstrumented distribution Qt hides Qt's own connection-list ordering from
  TSan. The original test reproduced the report in 54 of 200 local macOS TSan
  runs.
- Impact: The nightly TSan job failed intermittently, and the stale batch
  could be counted as the test's first emission so the lost-wakeup regression
  test could pass without exercising its window.
- Resolution: 2026-09-29. `CachingQueue` records `m_workerIdle` under its
  mutex while the worker blocks with no work, and `CachingQueueTest::init()`
  waits for an idle worker with empty queues before each test connects
  receivers. The fixed test passed 100 consecutive local TSan runs and the
  full local TSan suite passes.
- Related: `src/core/CachingQueue.cpp`, `src/tests/CachingQueueTest.cpp`
