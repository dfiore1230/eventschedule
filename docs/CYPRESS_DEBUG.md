# Cypress debug workflow

This document explains the `Cypress debug (failing specs)` workflow.

- Triggering manually: go to Actions → "Cypress debug (failing specs)" → Run workflow. You can optionally provide `specs` as a comma-separated list of spec globs to run.
  - Example `specs` value: `cypress/e2e/admin.spec.js,cypress/e2e/landing.spec.js`

- Scheduled run: the workflow is scheduled to run weekly (Sunday UTC) to surface regressions early.

- Behavior: when run it will start a local MySQL, migrate, seed, install deps (with a fallback to `npm install`), build assets and run the specified Cypress specs. Artifacts (screenshots, videos, results) are uploaded to the run for triage.

- Tip: use the `specs` input to target specific failing specs and capture artifacts without running the full suite.