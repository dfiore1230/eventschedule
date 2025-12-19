# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

## v0.9.0 - 2025-12-18

- Added deterministic XCUITests for ticket scanning flows and negative scenarios (404, 419, malformed 2xx, camera permission denied).
- Hardened ticket scan handling: permissive decoding for 2xx responses and JSON fallback; avoid exposing raw server bodies in the UI (console-only logs).
- Added `UITEST_SCAN_CODE` injection for deterministic scan tests and `UITEST_SIMULATE_CAMERA_DENIED` env var for camera permission simulation in UI tests.
- Added GitHub Actions CI workflow to run unit tests and XCUITests on macOS simulators.

(See merged PR #101 for details.)

## Unreleased


