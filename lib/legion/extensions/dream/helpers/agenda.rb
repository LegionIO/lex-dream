# frozen_string_literal: true

module Legion
  module Extensions
    module Dream
      module Helpers
        module Agenda
          module_function

          def build_from_phases(phase_outputs)
            items = []
            now   = Time.now.utc

            Array(phase_outputs[:unresolved_traces]).each do |trace|
              items << {
                type:       :unresolved,
                content:    { trace_id: trace[:trace_id] },
                weight:     trace[:emotional_intensity],
                created_at: now
              }
            end

            Array(phase_outputs[:contradictions]).each do |contradiction|
              next unless contradiction[:resolution] == :unresolvable

              items << {
                type:       :surfacing,
                content:    { trace_ids: contradiction[:trace_ids], domain: contradiction[:domain] },
                weight:     0.7,
                created_at: now
              }
            end

            Array(phase_outputs[:walk_results]).each do |result|
              items << {
                type:       :curious,
                content:    { trace_id: result[:trace_id], path: result[:path] },
                weight:     result[:novelty_score],
                created_at: now
              }
            end

            entropy = phase_outputs[:entropy] || {}
            if entropy[:classification] == :high_entropy && entropy[:trend] == :rising
              items << {
                type:       :corrective,
                content:    { classification: entropy[:classification], trend: entropy[:trend] },
                weight:     entropy[:entropy],
                created_at: now
              }
            end

            items
          end

          def to_semantic_traces(agenda_items)
            agenda_items.map do |item|
              Legion::Extensions::Memory::Helpers::Trace.new_trace(
                type:               :semantic,
                content_payload:    { dream_agenda: item[:type], **item[:content] },
                emotional_intensity: item[:weight],
                domain_tags:        ["dream:#{item[:type]}"],
                origin:             :direct_experience
              )
            end
          end
        end
      end
    end
  end
end
