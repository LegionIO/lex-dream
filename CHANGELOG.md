# Changelog

## [Unreleased]

## [0.1.1] - 2026-03-16

### Fixed
- Guard `DreamCycle#memory` with `defined?` check and use `Memory::Client.new` instead of fragile `Object.new.extend` pattern
- Guard `DreamCycle#identity` with `defined?` check to prevent `NoMethodError` when lex-identity is not loaded
- Early return in `execute_dream_cycle` when lex-memory is unavailable (logs warning instead of crashing every 5 minutes)
- Guard `Dream::Client#initialize` against missing Memory, Identity, and Emotion extensions

### Added
- `spec/legion/extensions/dream/actors/dream_cycle_spec.rb` (7 examples) — tests for the DreamCycle actor (Every 300s)

## [0.1.0] - 2026-03-13

### Added
- Initial release
