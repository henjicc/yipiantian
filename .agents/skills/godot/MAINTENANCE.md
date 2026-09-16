# Maintaining the godot skill

This skill is a dated snapshot of a moving target (the current stable Godot). It is technical debt by design: useful only as long as it is refreshed. This is the upkeep process.

The `date` field in `SKILL.md` frontmatter is the snapshot date (last full review). Each reference file under `references/` carries its own `**Verified YYYY-MM-DD**` line.

## When to refresh
- Godot ships a new minor (4.x) or a major, or a notable paradigm shift lands.
- A reference file's `Verified` date is more than roughly 3 to 6 months old. Run the freshness report:
  ```sh
  node scripts/check-freshness.mjs                              # oldest entries first
  node scripts/check-freshness.mjs --max-age-days=120 --fail    # non-zero exit if any are stale (for CI)
  ```
- A user reports an API or behavior newer than a file documents.

## How to refresh an entry (official docs are the source of record)
1. Read the OFFICIAL source: the Godot release notes for the version, the migration notes, and the relevant class reference pages on docs.godotengine.org. Do not refresh from memory or secondary blogs.
2. Update the affected facts: deprecated/replacement API, breaking changes, "new in" features, default-changed behavior, and any signature that moved.
3. Bump that file's `**Verified YYYY-MM-DD**` line to today.
4. If the headline guidance changed, update the matching bullet in the `SKILL.md` Reference Files list or Core Rules.
5. Run the checks:
   ```sh
   node scripts/check-skills.mjs       # frontmatter, links, registration
   node scripts/check-freshness.mjs    # date report
   ```
6. After a full pass, bump the snapshot date: the `date` in `SKILL.md` frontmatter and the "Snapshot date" line in the freshness section.

## Keep version-specific facts version-tagged
The paradigm sections (typed GDScript, call-down-signal-up, TileMapLayer over TileMap, annotation and signal syntax) age slowly and should stay version-neutral. The volatile facts (breaking changes, new features, deprecations) belong under explicitly version-tagged headings (e.g. "Godot 4.6 Breaking Changes") so a reader can tell at a glance what is pinned to a release and what is durable.

## Efficient bulk refresh
A full re-verify is cheap with parallel research: one agent per reference file, each reading the official docs for the target version and returning the deltas, then fold the results back into the files. Prioritize the files whose `Verified` dates are oldest.

## Source
Grounded in the official Godot documentation at docs.godotengine.org and the per-version release notes.
