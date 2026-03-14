# frozen_string_literal: true

module Legion
  module Extensions
    module Dream
      module Helpers
        module AssociationWalker
          module_function

          def walk(store:, start_id:, max_hops: Constants::ASSOCIATION_WALK_HOPS, # rubocop:disable Metrics/ParameterLists
                   novelty_threshold: Constants::ASSOCIATION_NOVELTY_THRESHOLD,
                   known_paths: Set.new, **)
            raw = store.walk_associations(start_id: start_id, max_hops: max_hops)

            raw.filter_map do |result|
              score = compute_novelty(
                path:        result[:path],
                depth:       result[:depth],
                store:       store,
                known_paths: known_paths
              )
              next if score < novelty_threshold

              result.merge(novelty_score: score)
            end
          end

          def select_start_trace(store:)
            store.all_traces
                 .select { |t| t[:trace_type] == :episodic && t[:unresolved] == true }
                 .max_by { |t| t[:emotional_intensity] }
          end

          def compute_novelty(path:, depth:, store:, known_paths:)
            path_key = path.join('->')
            return 0.0 if known_paths.include?(path_key)

            depth_factor = depth / Constants::ASSOCIATION_WALK_HOPS.to_f

            type_diversity = path.map { |id| store.get(id)&.dig(:trace_type) }.compact.uniq.size
            type_factor    = type_diversity / path.size.to_f

            ((depth_factor * 0.4) + (type_factor * 0.6)).clamp(0.0, 1.0)
          end

          private :compute_novelty
        end
      end
    end
  end
end
