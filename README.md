# lex-dream

Autonomous dream cycle for the [LegionIO](https://github.com/LegionIO/LegionIO) cognitive architecture. When the agent is idle, it runs an eight-phase internal consolidation cycle: memory audit, association walking, contradiction resolution, identity entropy assessment, agenda formation, consolidation commit, dream reflection, and dream narration.

## Installation

Add to your Gemfile:

```ruby
gem 'lex-dream'
```

## How It Works

Dream output feeds back into lex-memory as semantic traces with `dream:*` domain tags. These surface organically through normal retrieval ranking -- no explicit surfacing mechanism needed.

### The Eight Dream Phases

| Phase | What It Does |
|-------|-------------|
| Memory Audit | Runs decay + tier migration, marks consolidation candidates, collects unresolved traces |
| Association Walk | BFS walks associations from highest-salience unresolved trace, materializes novel Hebbian links |
| Contradiction Resolution | Detects opposing-valence traces by domain; resolves via LLM if available, else mechanical fallback |
| Identity Entropy Check | Calls lex-identity entropy assessment, flags drift as corrective agenda item |
| Agenda Formation | Synthesizes phases 1-4 into typed, weighted agenda items (LLM synthesis when available) |
| Consolidation Commit | Converts agenda to semantic traces in lex-memory, clears dream state |
| Dream Reflection | Assesses cognitive health of the dream cycle via lex-reflection (skipped if not loaded) |
| Dream Narration | Produces a narrative summary via lex-narrator (skipped if not loaded) |

### Agenda Item Types

- `:unresolved` -- traces that need attention
- `:surfacing` -- unresolvable contradictions
- `:curious` -- novel associations discovered during walk
- `:corrective` -- identity entropy drift detected

## Dependencies

- `lex-memory` -- trace storage, decay, Hebbian linking, cache reload/flush
- `lex-identity` -- entropy assessment
- `lex-emotion` -- emotional intensity for salience ranking
- `lex-reflection` -- optional cognitive health assessment (dream_reflection phase)
- `lex-narrator` -- optional narrative generation (dream_narration phase)
- `legion-llm` -- optional LLM enhancement for contradiction resolution and agenda synthesis

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
