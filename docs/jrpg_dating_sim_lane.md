# KAI 9000 JRPG + Dating Sim Lane

## Branch flow

`main` <- `proposed/jrpg-dating-sim` <- `testing/jrpg-dating-sim`

## Testing lane

All experimental Godot 4 JRPG, dialogue, social-link, affection, battle integration, save-state, Android, and AI-assisted systems land here first.

Testing may contain incomplete or disposable work. Upstream frameworks are treated as donor dependencies and must retain license/provenance records.

## Proposed lane

Only changes that pass the testing gate are promoted here. Proposed is the review candidate for eventual integration into `main` and must remain runnable and reversible.

## Promotion gate

A change may move from testing to proposed only when:

- Godot project opens without parser errors.
- Headless project check succeeds where supported.
- Existing gameplay/bootstrap path still runs.
- New social or JRPG state is deterministic and save-safe.
- Dialogue mutations do not directly own authoritative relationship state.
- Third-party source and license information is recorded.
- Android-specific changes do not break desktop/headless operation.
- No secrets, tokens, generated binaries, or local machine paths are committed.

## Initial architecture target

- Godot 4 runtime
- JRPG framework donor layer
- Dialogue Manager narrative layer
- KAI-owned SocialState relationship system
- Story/event router
- Battle/exploration integration
- Unified save adapter

## Rule

Experiment in `testing/jrpg-dating-sim`.
Promote by pull request into `proposed/jrpg-dating-sim`.
Only promote proposed work to `main` after a separate review pass.
