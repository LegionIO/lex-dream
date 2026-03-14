# lex-dream

**Level 3 Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-agentic/CLAUDE.md`
- **Grandparent**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

Autonomous dream cycle for the LegionIO cognitive architecture. When the agent is idle, it enters `dormant_active` mode and runs an eight-phase internal consolidation cycle: memory audit, association walking, contradiction resolution, identity entropy assessment, agenda formation, consolidation commit, dream reflection, and dream narration. Dream output feeds back into lex-memory as semantic traces that surface organically through normal retrieval — no explicit surfacing mechanism.

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
    constants.rb               # Configuration defaults, DREAM_CYCLE_PHASES list, agenda item types
    dream_store.rb             # In-memory store for agenda, walk results, contradictions, entropy
    association_walker.rb      # Novelty-scored multi-hop association traversal + start trace selection
    contradiction_detector.rb  # Domain-tag overlap + valence divergence detection and resolution
    agenda.rb                  # Phase output synthesis and semantic trace conversion
    llm_enhancer.rb            # Optional LLM integration for contradiction resolution and agenda synthesis
    dream_journal.rb           # Writes human-readable dream journal entries
  runners/
    dream_cycle.rb             # Eight-phase dream cycle runner (all phase methods)
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

## The Eight Dream Phases

All phases execute sequentially via direct Ruby method calls (not queued through transport). Phases are defined in `Constants::DREAM_CYCLE_PHASES`.

| Phase | Method | What It Does |
|---|---|---|
| 1. Memory Audit | `phase_memory_audit` | Runs decay + tier migration, marks consolidation candidates, collects unresolved traces using `EMERGENT_UNRESOLVED` heuristics |
| 2. Association Walk | `phase_association_walk` | Selects highest-salience unresolved trace, BFS walks associations with novelty scoring, materializes novel links via `hebbian_link` |
| 3. Contradiction Resolution | `phase_contradiction_resolution` | Detects opposing-valence traces by domain overlap; resolves via LLM if available, otherwise falls back to recency/intensity weighting |
| 4. Identity Entropy Check | `phase_identity_entropy_check` | Calls `identity.check_entropy`, records result in DreamStore, flags drift as corrective agenda item |
| 5. Agenda Formation | `phase_agenda_formation` | Synthesizes phases 1-4 into typed, weighted agenda items; uses LLM synthesis if available, mechanical fallback otherwise |
| 6. Consolidation Commit | `phase_consolidation_commit` | Converts agenda to semantic traces in lex-memory, clears unresolved flags, expires stale dream state, flushes cache store |
| 7. Dream Reflection | `phase_dream_reflection` | Calls `lex-reflection` to assess cognitive health of the dream cycle (skipped if extension not loaded) |
| 8. Dream Narration | `phase_dream_narration` | Calls `lex-narrator` to produce a narrative summary (skipped if extension not loaded) |

## DreamStore

In-memory store owned entirely by lex-dream. The agent's private journal:

- `agenda` — weighted orientation items (`:unresolved`, `:surfacing`, `:curious`, `:corrective`)
- `walk_results` — novel association paths with novelty scores
- `contradictions` — resolution logs with domain and outcome
- `entropy_history` — identity entropy snapshots

Items expire via `DREAM_PARTITION_TTL`. Oldest agenda items drop when `AGENDA_MAX_ITEMS` exceeded.

## LLM Enhancement

`Helpers::LlmEnhancer` provides optional LLM-enhanced processing:
- `available?` — returns true when `Legion::LLM` is started
- `resolve_contradiction(trace_a, trace_b, strategy:)` — prompts LLM to reason about which trace is more reliable; falls back to mechanical resolution if unavailable or on error
- `synthesize_agenda(unresolved_traces:, contradictions:, walk_results:, entropy:)` — prompts LLM to synthesize agenda items from all phase data; mechanical fallback via `Helpers::Agenda.build_from_phases`

The system prompt instructs the LLM to act as the agent's internal dream processor: concise, analytical, structured reasoning only.

## Dream Journal

`Helpers::DreamJournal.write_entry(results:, phase_data:, dream_store:)` is called after all phases complete but before dream state is cleared. It writes a human-readable journal entry to the `logs/` directory.

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

- **lex-tick**: Dream runs in `dormant_active` mode. Eight dream phases registered in `MODE_PHASES[:dormant_active]`. Tick budget is uncapped (`Float::INFINITY`).
- **lex-memory**: Direct calls to `decay_cycle`, `migrate_tier`, `hebbian_link`. Calls `CacheStore#reload` before the cycle starts (picks up traces written by other processes). Calls `CacheStore#flush` after the cycle completes.
- **lex-identity**: Calls `check_entropy` during phase 4 for drift detection.
- **lex-emotion**: Uses emotional intensity/valence from traces for salience ranking and contradiction detection.
- **lex-reflection**: Phase 7 delegates to `lex-reflection` for cognitive health assessment (optional, skipped if not loaded).
- **lex-narrator**: Phase 8 delegates to `lex-narrator` for dream narrative generation (optional, skipped if not loaded).
- **legion-llm**: LlmEnhancer checks `Legion::LLM.started?` to determine if LLM-enhanced resolution/synthesis is available.

## Transition Rules (in lex-tick)

```
dormant → dormant_active:    no signals for 1800s (DREAM_IDLE_THRESHOLD)
dormant_active → sentinel:   high-salience signal (>= 0.7) or human_direct
dormant_active → dormant:    dream cycle completes (dream_complete: true)
sentinel → dormant_active:   no signals for 600s (SENTINEL_TO_DREAM_THRESHOLD)
```

## Development Notes

- `memory.send(:default_store)` needed because `default_store` is private on the memory runner
- `store.reload` and `store.flush` are called defensively with `respond_to?` guards (only implemented by `CacheStore`, not `Store`)
- `EMERGENT_UNRESOLVED` lambda defines five heuristics for finding unprocessed traces beyond the simple `unresolved: true` flag — episodic with zero reinforcement and high emotion, low-confidence unreinforced, negative-valence semantic/procedural, high-intensity unreinforced
- Phase methods collect data into `@phase_data` for use by later phases and for the dream journal
- `dream_store.clear` is called at the end of `consolidation_commit` to reset state for the next dream cycle
- Dream reflection and narration phases return `{ status: :skipped, reason: :extension_not_loaded }` when their dependencies are absent — the cycle completes normally
- All state is in-memory (consistent with v0.1.0 pattern across agentic extensions)
