# frozen_string_literal: true

module Legion
  module Extensions
    module Dream
      module Helpers
        class DreamStore
          attr_reader :agenda, :walk_results, :contradictions, :entropy_history

          def initialize
            @agenda          = []
            @walk_results    = []
            @contradictions  = []
            @entropy_history = []
          end

          def add_agenda_item(type:, content:, weight:)
            unless Constants::AGENDA_ITEM_TYPES.include?(type)
              raise ArgumentError, "unknown agenda item type: #{type.inspect}; " \
                                   "must be one of #{Constants::AGENDA_ITEM_TYPES.inspect}"
            end

            clamped_weight = weight.clamp(0.0, 1.0)

            @agenda << {
              type:       type,
              content:    content,
              weight:     clamped_weight,
              created_at: Time.now.utc
            }

            trim_agenda!
          end

          def record_walk_result(source_id:, path:, novelty_score:)
            @walk_results << {
              source_id:    source_id,
              path:         path,
              novelty_score: novelty_score,
              discovered_at: Time.now.utc
            }
          end

          def record_contradiction(trace_ids:, domain:, resolution:)
            @contradictions << {
              trace_ids:   trace_ids,
              domain:      domain,
              resolution:  resolution,
              resolved_at: Time.now.utc
            }
          end

          def record_entropy(entropy:, classification:, trend:)
            @entropy_history << {
              entropy:        entropy,
              classification: classification,
              trend:          trend,
              checked_at:     Time.now.utc
            }
          end

          def expire_stale!
            cutoff = Time.now.utc - Constants::DREAM_PARTITION_TTL
            @agenda.reject!         { |item| item[:created_at] < cutoff }
            @walk_results.reject!   { |item| item[:discovered_at] < cutoff }
            @contradictions.reject! { |item| item[:resolved_at] < cutoff }
            @entropy_history.reject! { |item| item[:checked_at] < cutoff }
          end

          def clear
            @agenda.clear
            @walk_results.clear
            @contradictions.clear
            @entropy_history.clear
          end

          private

          def trim_agenda!
            excess = @agenda.size - Constants::AGENDA_MAX_ITEMS
            @agenda.shift(excess) if excess.positive?
          end
        end
      end
    end
  end
end
