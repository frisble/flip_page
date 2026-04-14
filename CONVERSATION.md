# Conversation — flip_page inception

Date: 2026-04-14

## Context

User is working on `palio_del_vecchio_mercato_frontend` (Flutter). Wants a page-flip widget. Evaluating whether to adopt an existing pub.dev package or build own as first open-source Flutter contribution.

---

## Q1 — Adopt `turnable_page` or build from scratch?

**User:** https://pub.dev/packages/turnable_page — better to implement this package or create one from scratch? Goal: first Flutter open-source contribution.

**Assistant analysis of `turnable_page`:**

| Field | Value |
|-------|-------|
| Version | 1.0.1 |
| Last update | 6 months ago |
| Likes | 40 |
| Pub points | 140 |
| Weekly downloads | 212 |
| Platforms | Android, iOS, Linux, macOS, Windows, Web |
| Null-safety | Yes |
| License | **Proprietary** (Turnable Page Proprietary License) |
| Publisher | Unverified |
| Deps | `pdfrx ^2.1.3` |
| Roadmap gaps | a11y, bookmarks, animation customization |

**Recommendation: build own. Skip `turnable_page`.**

Reasons:

- **License proprietary.** Blocks fork/redistribution. Contribution path locked to their PRs only. Kills open-source-contribution goal.
- **Unverified publisher**, low adoption (40 likes, 212 weekly downloads). Low trust, low signal.
- **Stale** (6 months), roadmap items unshipped.
- **Heavy dep** (`pdfrx`) bundled even if only page-flip is needed.

Build-own case:

- Page-flip = bounded scope. Good first package.
- Market gap: no dominant MIT/BSD page-flip widget on pub.dev.
- Full control: license (MIT), API, platform matrix.
- `CustomPainter` + `Transform` + `GestureDetector` covers core. Split PDF into separate addon package (`flip_page_pdf`) — keep core lean.

**Scope v0.1:**

- Single widget `FlipPage(children: [...])`.
- Drag gesture → curl animation (perspective transform + shadow).
- Interactive children (hit-test before flip).
- Portrait + landscape layout.
- Pure Flutter, zero runtime deps.

**Prior art to study** (ideas only, not code — features aren't copyrightable):

- `page_flip` (MIT, archived)
- `turn_page_transition`
- `turnable_page` README

---

## Q2 — Create initial commit

**User:** Create initial commit in `/Users/nicolamazzocato/Documents/Work/Frisble/Packages/Flutter/flip_page`.

**Actions taken:**

1. Scaffolded package via `fvm flutter create --template=package --project-name flip_page --description "..." .`
2. Replaced `LICENSE` placeholder with MIT (Nicola Mazzocato, 2026).
3. Replaced `CHANGELOG.md` TODO with `0.0.1 — Initial scaffold.`
4. Rewrote `README.md` with pre-alpha status, planned features, usage sketch.
5. Commented-out `homepage`/`repository`/`issue_tracker` placeholders in `pubspec.yaml` (pending repo URL).
6. Verified: `flutter analyze` → 0 issues; `flutter test` → stub passes.
7. Committed: `chore: initial package scaffold` — commit `f2975a8`.

**Files committed (9):**

- `.gitignore`
- `.metadata`
- `CHANGELOG.md`
- `LICENSE`
- `README.md`
- `analysis_options.yaml`
- `lib/flip_page.dart`
- `pubspec.yaml`
- `test/flip_page_test.dart`

**Tooling:**

- Flutter 3.41.6 (stable, via fvm)
- Dart 3.11.4

---

## Next steps (pending)

- [ ] Add GitHub remote + push (need repo URL).
- [ ] Fill `homepage` / `repository` / `issue_tracker` in `pubspec.yaml`.
- [ ] Scaffold `example/` app.
- [ ] Design `FlipPage` API + `CustomPainter` curl math for v0.1.
