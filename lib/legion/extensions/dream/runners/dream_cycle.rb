# frozen_string_literal: true

module Legion
  module Extensions
    module Dream
      module Runners
        module DreamCycle
          extend self

          CONSOLIDATION_CANDIDATE_THRESHOLD = 5

          EMERGENT_UNRESOLVED = lambda { |trace|
            return true if trace[:unresolved] == true
            return true if trace[:trace_type] == :episodic &&
                           trace[:reinforcement_count] == 0 &&
                           trace[:emotional_intensity] >= 0.5
            return true if trace[:confidence].is_a?(Numeric) &&
                           trace[:confidence] < 0.4 &&
                           trace[:reinforcement_count] == 0

            false
          }

          def execute_dream_cycle(**)
            @phase_data = {}
            results = {}

            # Reload from cache to pick up traces written by other runners (e.g. coldstart)
            store = memory.send(:default_store)
            store.reload if store.respond_to?(:reload)

            Legion::Logging.info '[dream] cycle starting'
            Helpers::Constants::DREAM_CYCLE_PHASES.each do |phase|
              Legion::Logging.debug "[dream] starting phase: #{phase}"
              results[phase] = send(:"phase_#{phase}")
            rescue StandardError => e
              Legion::Logging.error "[dream] phase #{phase} failed: #{e.message}"
              Legion::Logging.error "[dream] #{e.backtrace&.first(3)&.join("\n")}"
              results[phase] = { error: e.message }
            end
            # Flush cache-backed store after all phases
            store = memory.send(:default_store)
            store.flush if store.respond_to?(:flush)

            Legion::Logging.info "[dream] cycle complete: #{results.keys.join(', ')}"
            { status: :completed, phases: results }
          end

          def phase_memory_audit(**)
            store = memory.send(:default_store)
            decay_result   = memory.decay_cycle(store: store)
            migrate_result = memory.migrate_tier(store: store)

            candidates = store.all_traces.select do |t|
              t[:trace_type] == :episodic &&
                t[:reinforcement_count] >= CONSOLIDATION_CANDIDATE_THRESHOLD &&
                t[:strength] < Legion::Extensions::Memory::Helpers::Trace::STARTING_STRENGTHS[:episodic]
            end
            candidates.each do |t|
              t[:consolidation_candidate] = true
              store.store(t)
            end

            unresolved = store.all_traces.select(&EMERGENT_UNRESOLVED)
            @phase_data[:unresolved_traces] = unresolved

            Legion::Logging.debug "[dream] memory_audit: decayed=#{decay_result[:decayed]} pruned=#{decay_result[:pruned]} " \
                                  "migrated=#{migrate_result[:migrated]} candidates=#{candidates.size} unresolved=#{unresolved.size}"
            {
              decayed:                  decay_result[:decayed],
              pruned:                   decay_result[:pruned],
              migrated:                 migrate_result[:migrated],
              consolidation_candidates: candidates.size,
              unresolved_count:         unresolved.size
            }
          end

          def phase_association_walk(**)
            store       = memory.send(:default_store)
            start_trace = Helpers::AssociationWalker.select_start_trace(store: store)

            unless start_trace
              @phase_data[:walk_results] = []
              return { walk_results: [], start_trace: nil }
            end

            known   = Set.new(dream_store.walk_results.map { |w| w[:path].join('->') })
            results = Helpers::AssociationWalker.walk(
              store: store, start_id: start_trace[:trace_id], known_paths: known
            )

            results.each do |wr|
              dream_store.record_walk_result(
                source_id: start_trace[:trace_id], path: wr[:path], novelty_score: wr[:novelty_score]
              )
              wr[:path].each_cons(2) do |a_id, b_id|
                memory.hebbian_link(trace_id_a: a_id, trace_id_b: b_id, store: store)
              end
            end

            @phase_data[:walk_results] = results
            Legion::Logging.debug "[dream] association_walk: start=#{start_trace[:trace_id][0..7]} results=#{results.size}"
            { walk_results: results, start_trace: start_trace[:trace_id] }
          end

          def phase_contradiction_resolution(**)
            store    = memory.send(:default_store)
            detected = Helpers::ContradictionDetector.detect(store: store)

            resolutions = detected.map do |contradiction|
              result = Helpers::ContradictionDetector.resolve(
                trace_ids: contradiction[:trace_ids],
                store:     store,
                strategy:  Helpers::Constants::CONTRADICTION_RESOLUTION_STRATEGY
              )
              dream_store.record_contradiction(
                trace_ids:  contradiction[:trace_ids],
                domain:     contradiction[:domain],
                resolution: result[:resolution]
              )
              result
            end

            @phase_data[:contradictions] = resolutions
            Legion::Logging.debug "[dream] contradiction_resolution: detected=#{detected.size} resolved=#{resolutions.count do |r|
              r[:resolution] == :resolved
            end}"
            { detected: detected.size, resolutions: resolutions }
          end

          def phase_identity_entropy_check(**)
            result = identity.check_entropy(observations: {})
            dream_store.record_entropy(
              entropy:        result[:entropy],
              classification: result[:classification],
              trend:          result[:trend]
            )
            @phase_data[:entropy] = result
            Legion::Logging.debug "[dream] identity_entropy: #{result[:classification]} trend=#{result[:trend]}"
            result
          end

          def phase_agenda_formation(**)
            items = Helpers::Agenda.build_from_phases(
              unresolved_traces: @phase_data[:unresolved_traces] || [],
              contradictions:    @phase_data[:contradictions] || [],
              walk_results:      @phase_data[:walk_results] || [],
              entropy:           @phase_data[:entropy] || {}
            )
            items.each do |item|
              dream_store.add_agenda_item(type: item[:type], content: item[:content], weight: item[:weight])
            end
            Legion::Logging.debug "[dream] agenda_formation: #{items.size} items"
            { agenda_items: items.size }
          end

          def phase_consolidation_commit(**)
            store  = memory.send(:default_store)
            traces = Helpers::Agenda.to_semantic_traces(dream_store.agenda)
            traces.each { |t| store.store(t) }

            Array(@phase_data[:unresolved_traces]).each do |t|
              trace = store.get(t[:trace_id])
              next unless trace

              trace[:unresolved] = false
              store.store(trace)
            end

            dream_store.expire_stale!
            dream_store.clear
            Legion::Logging.info "[dream] consolidation_commit: #{traces.size} traces written to memory"
            { traces_written: traces.size, dream_store_cleared: true }
          end

          include Legion::Extensions::Helpers::Lex if defined?(Legion::Extensions::Helpers::Lex)

          private

          def memory
            @memory ||= begin
              runner = Object.new
              runner.extend(Legion::Extensions::Memory::Runners::Traces)
              runner.extend(Legion::Extensions::Memory::Runners::Consolidation)
              runner
            end
          end

          def identity
            @identity ||= Object.new.extend(Legion::Extensions::Identity::Runners::Identity)
          end

          def dream_store
            @dream_store ||= Helpers::DreamStore.new
          end
        end
      end
    end
  end
end
