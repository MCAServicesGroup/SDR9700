# SDR9700 Project Issues

This file tracks unresolved issues identified during SDR9700 project work.
Record confirmed findings from implementation, review, testing, CI,
documentation, packaging, release work, hardware validation, security checks,
and repository administration.

## Tracking Rules

- The next issue identifier is `SDR-0013`. Advance this counter when assigning
  an identifier; never reuse one after its entry is removed.
- Record a confirmed issue when it remains unresolved after the current task.
  Do not record unsupported speculation as a finding.
- Include concrete evidence, user or project impact, and the next action needed
  to make progress.
- Use one of these statuses: `open`, `investigating`, `blocked`, or `deferred`.
- Use one of these severities: `critical`, `high`, `medium`, or `low`.
- Update an existing entry instead of creating a duplicate. Link a GitHub issue
  or pull request when one exists.
- Remove resolved entries. Their commits, pull requests, and release notes
  carry the resolution history.
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

### SDR-0006: Apple release secrets remain at repository scope

- Status: `deferred`
- Severity: `high`
- Area: GitHub Actions release credentials
- Identified: 2026-10-03 while configuring the `macos_release` environment
- Evidence: The environment has a `main`-only branch policy and required
  maintainer review, but no environment secrets. The five Apple signing and
  notarization secret names remain configured at repository scope.
- Impact: Other workflows can still access the repository-scoped credentials,
  so the release environment does not yet isolate them.
- Next action: When the maintainer is ready to move the secrets, re-enter the
  five Apple secrets in `macos_release` from the originals, verify their names,
  then delete the repository-scoped copies. The maintainer requested on
  2026-10-03 that repository-scoped copies remain for now.
- Related: `resources/packaging/macos/README.md`, `.github/workflows/release_macos.yml`
