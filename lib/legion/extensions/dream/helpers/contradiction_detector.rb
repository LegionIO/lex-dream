# frozen_string_literal: true

module Legion
  module Extensions
    module Dream
      module Helpers
        module ContradictionDetector
          SCANNABLE_TYPES   = %i[trust semantic].freeze
          VALENCE_THRESHOLD = 0.3
          RESOLUTION_MARGIN = 0.1

          module_function

          def detect(store:)
            traces = SCANNABLE_TYPES.flat_map { |type| store.retrieve_by_type(type) }

            domain_groups = Hash.new { |h, k| h[k] = [] }
            traces.each do |trace|
              trace[:domain_tags].each { |tag| domain_groups[tag] << trace }
            end

            contradictions = []
            domain_groups.each do |domain, group|
              group.combination(2) do |a, b|
                next unless opposing_valence?(a, b)

                contradictions << {
                  trace_ids: [a[:trace_id], b[:trace_id]],
                  domain:    domain,
                  valence_a: a[:emotional_valence],
                  valence_b: b[:emotional_valence]
                }
              end
            end

            contradictions
          end

          def resolve(trace_ids:, store:, strategy: :recency_weighted)
            trace_a = store.get(trace_ids[0])
            trace_b = store.get(trace_ids[1])

            score_a = resolution_score(trace_a, strategy)
            score_b = resolution_score(trace_b, strategy)

            return { resolution: :unresolvable } if (score_a - score_b).abs <= RESOLUTION_MARGIN

            winner, loser = score_a > score_b ? [trace_a, trace_b] : [trace_b, trace_a]

            now = Time.now.utc
            winner[:strength]         = [winner[:strength] + 0.1, 1.0].min
            winner[:peak_strength]    = [winner[:peak_strength], winner[:strength]].max
            winner[:last_reinforced]  = now

            loser[:strength] = [loser[:strength] - 0.1, 0.0].max

            { resolution: :resolved, winner_id: winner[:trace_id], loser_id: loser[:trace_id] }
          end

          def resolution_score(trace, strategy)
            recency   = 1.0 / (1.0 + (Time.now.utc - trace[:last_reinforced]))
            intensity = trace[:emotional_intensity]
            case strategy
            when :recency_weighted   then (recency * 0.6) + (intensity * 0.4)
            when :intensity_weighted then (recency * 0.3) + (intensity * 0.7)
            else (recency * 0.5) + (intensity * 0.5)
            end
          end
          private_class_method :resolution_score

          def opposing_valence?(trace_a, trace_b)
            return false if trace_a[:emotional_valence].abs < VALENCE_THRESHOLD
            return false if trace_b[:emotional_valence].abs < VALENCE_THRESHOLD

            (trace_a[:emotional_valence] > 0) != (trace_b[:emotional_valence] > 0)
          end
          private_class_method :opposing_valence?
        end
      end
    end
  end
end
