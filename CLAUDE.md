# lex-dream

**Level 3 Documentation**
- **Parent**: `extensions-agentic/CLAUDE.md`
- **Grandparent**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

Autonomous dream cycle for the LegionIO cognitive architecture. When the agent is idle, it enters `dormant_active` mode and runs a six-phase internal consolidation cycle: memory audit, association walking, contradiction resolution, identity entropy assessment, agenda formation, and consolidation commit. Dream output feeds back into lex-memory as semantic traces that surface organically through normal retrieval — no explicit surfacing mechanism.

## Gem Info

- **Gem name**: `lex-dream`
- **Version**: `0.1.0`
- **Module**: `Legion::Extensions::Dream`
- **Ruby**: `>= 3.4`
- **License**: MIT

## File Structure

```
lib/legion/extensions/dream/
  version.rb
  helpers/
    constants.rb               # Configuration defaults, phase list, agenda item types
    dream_store.rb             # In-memory store for agenda, walk results, contradictions, entropy
    association_walker.rb      # Novelty-scored multi-hop association traversal + start trace selection
    contradiction_detector.rb  # Domain-tag overlap + valence divergence detection and resolution
    agenda.rb                  # Phase output synthesis and semantic trace conversion
  runners/
    dream_cycle.rb             # Six-phase dream cycle runner (all phase methods)
  client.rb                    # Client with dependency injection for memory/identity/emotion
spec/
  legion/extensions/dream/
    helpers/
      dream_store_spec.rb
      association_walker_spec.rb
      contradiction_detector_spec.rb
      agenda_spec.rb
    runners/
      dream_cycle_spec.rb
    client_spec.rb
    integration_spec.rb
```

## Key Constants (Helpers::Constants)

```ruby
ASSOCIATION_WALK_HOPS          = 12       # max BFS depth
ASSOCIATION_NOVELTY_THRESHOLD  = 0.65     # min novelty to log a walk result
CONTRADICTION_RESOLUTION_STRATEGY = :recency_weighted  # or :intensity_weighted
ENTROPY_WINDOW                 = 7        # sessions for identity entropy trend
AGENDA_MAX_ITEMS               = 5        # max agenda items carried forward
DREAM_PARTITION_TTL            = 604_800  # 7 days before unrecalled items expire
AGENDA_ITEM_TYPES              = %i[unresolved surfacing curious corrective]
```

## The Six Dream Phases

All phases execute sequentially via direct Ruby method calls (not queued through transport).

| Phase | Method | What It Does |
|---|---|---|
| 1. Memory Audit | `phase_memory_audit` | Runs decay + tier migration, marks consolidation candidates, collects unresolved traces |
| 2. Association Walk | `phase_association_walk` | Selects highest-salience unresolved episodic trace, BFS walks associations with novelty scoring, materializes novel links via `hebbian_link` |
| 3. Contradiction Resolution | `phase_contradiction_resolution` | Scans trust/semantic traces by domain overlap, detects opposing valence, resolves via recency/intensity weighting |
| 4. Identity Entropy Check | `phase_identity_entropy_check` | Calls `identity.check_entropy`, records result, flags drift as corrective agenda item |
| 5. Agenda Formation | `phase_agenda_formation` | Synthesizes phases 1-4 into typed, weighted agenda items stored in DreamStore |
| 6. Consolidation Commit | `phase_consolidation_commit` | Converts agenda to semantic traces in lex-memory, clears unresolved flags, expires stale dream state |

## DreamStore

In-memory store owned entirely by lex-dream. The agent's private journal:

- `agenda` — weighted orientation items (`:unresolved`, `:surfacing`, `:curious`, `:corrective`)
- `walk_results` — novel association paths with novelty scores
- `contradictions` — resolution logs with domain and outcome
- `entropy_history` — identity entropy snapshots

Items expire via `DREAM_PARTITION_TTL`. Oldest agenda items drop when `AGENDA_MAX_ITEMS` exceeded.

## Client

```ruby
Client.new(memory:, identity:, emotion:)
```

Dependency clients initialized once at boot, held for process lifetime. Defaults to creating its own instances if none injected. The `dream_store` is public (`attr_reader`). All other state is private.

## Organic Recall — How Dream Output Reaches Active Sessions

No explicit surfacing mechanism. Dream output feeds back through normal lex-memory retrieval:

- Novel associations materialized as Hebbian links → participate in `retrieve_ranked`
- Agenda items become semantic traces with `dream:*` domain tags and high emotional intensity
- Reinforced traces have boosted strength → win retrieval ranking
- The agent doesn't "decide to bring something up" — relevant dream-formed knowledge surfaces contextually

## Integration Points

- **lex-tick**: Dream runs in `dormant_active` mode. Six dream phases registered in `MODE_PHASES[:dormant_active]`. Tick budget is uncapped (`Float::INFINITY`).
- **lex-memory**: Direct calls to `decay_cycle`, `migrate_tier`, `hebbian_link`. Uses `walk_associations` for BFS traversal. Reads/writes traces including `unresolved` and `consolidation_candidate` fields.
- **lex-identity**: Calls `check_entropy` during phase 4 for drift detection.
- **lex-emotion**: Uses emotional intensity/valence from traces for salience ranking and contradiction detection.
- **lex-privatecore**: Dream content subject to private core contract. Boundary enforcement called when needed, but lex-dream owns its own state.

## Transition Rules (in lex-tick)

```
dormant → dormant_active:    no signals for 1800s (DREAM_IDLE_THRESHOLD)
dormant_active → sentinel:   high-salience signal (>= 0.7) or human_direct
dormant_active → dormant:    dream cycle completes (dream_complete: true)
sentinel → dormant_active:   no signals for 600s (SENTINEL_TO_DREAM_THRESHOLD)
```

## Development Notes

- `memory.send(:default_store)` needed because `default_store` is private on Memory::Client
- Spec helper must explicitly require Client classes from dependency gems (entry points don't auto-require them)
- Association walking uses lex-memory Store's `walk_associations` (BFS with cycle detection)
- Contradiction detection is organic — no structured schema, works with domain_tags and emotional_valence
- All state is in-memory (consistent with v0.1.0 pattern across agentic extensions)
