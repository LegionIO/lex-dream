# frozen_string_literal: true

module Legion
  module Extensions
    module Dream
      module Helpers
        module Constants
          ASSOCIATION_WALK_HOPS          = 12
          ASSOCIATION_NOVELTY_THRESHOLD  = 0.65
          CONTRADICTION_RESOLUTION_STRATEGY = :recency_weighted
          ENTROPY_WINDOW                 = 7
          AGENDA_MAX_ITEMS               = 5
          DREAM_PARTITION_TTL            = 604_800
          AGENDA_ITEM_TYPES              = %i[unresolved surfacing curious corrective].freeze

          DREAM_CYCLE_PHASES = %i[
            memory_audit
            association_walk
            contradiction_resolution
            identity_entropy_check
            agenda_formation
            consolidation_commit
          ].freeze
        end
      end
    end
  end
end
