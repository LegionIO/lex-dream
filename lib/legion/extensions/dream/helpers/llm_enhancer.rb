# frozen_string_literal: true

module Legion
  module Extensions
    module Dream
      module Helpers
        module LlmEnhancer
          DREAM_SYSTEM_PROMPT = <<~PROMPT
            You are the internal dream processor for an autonomous AI agent built on LegionIO.
            During dream cycles you consolidate memory, resolve contradictions, and form agendas.
            Be concise, analytical, and direct. No pleasantries. Output structured reasoning only.
          PROMPT

          module_function

          def available?
            defined?(Legion::LLM) && Legion::LLM.respond_to?(:started?) && Legion::LLM.started?
          rescue StandardError
            false
          end

          # Resolve a contradiction between two traces using LLM reasoning.
          # Returns { resolution:, winner_id:, loser_id:, reasoning: } or
          #         { resolution: :unresolvable, trace_ids:, reasoning: }
          def resolve_contradiction(trace_a, trace_b, strategy:)
            prompt = build_contradiction_prompt(trace_a, trace_b, strategy)

            response = llm_ask(prompt)
            parse_contradiction_response(response, trace_a, trace_b)
          rescue StandardError => e
            Legion::Logging.warn "[dream:llm] contradiction resolution failed: #{e.message}"
            nil
          end

          # Synthesize dream phase results into a coherent agenda narrative.
          # Returns an array of { type:, content:, weight:, reasoning: } items.
          def synthesize_agenda(unresolved_traces:, contradictions:, walk_results:, entropy:)
            prompt = build_agenda_prompt(
              unresolved_traces: unresolved_traces,
              contradictions:    contradictions,
              walk_results:      walk_results,
              entropy:           entropy
            )

            response = llm_ask(prompt)
            parse_agenda_response(response)
          rescue StandardError => e
            Legion::Logging.warn "[dream:llm] agenda synthesis failed: #{e.message}"
            nil
          end

          # Generate a narrative summary of the dream cycle for the journal.
          # Returns a markdown string.
          def narrate_journal(results, phase_data)
            prompt = build_journal_prompt(results, phase_data)

            response = llm_ask(prompt)
            response&.content
          rescue StandardError => e
            Legion::Logging.warn "[dream:llm] journal narration failed: #{e.message}"
            nil
          end

          # --- Private helpers ---

          def llm_ask(prompt)
            chat = Legion::LLM.chat
            chat.with_instructions(DREAM_SYSTEM_PROMPT)
            chat.ask(prompt)
          end
          private_class_method :llm_ask

          def build_contradiction_prompt(trace_a, trace_b, strategy)
            <<~PROMPT
              Two memory traces in domain "#{(trace_a[:domain_tags] & trace_b[:domain_tags]).first}" contradict each other.

              TRACE A (#{trace_a[:trace_id][0..7]}):
              - Type: #{trace_a[:trace_type]}
              - Content: #{summarize_payload(trace_a[:content_payload])}
              - Valence: #{trace_a[:emotional_valence]} | Intensity: #{trace_a[:emotional_intensity]}
              - Strength: #{trace_a[:strength]&.round(3)} | Reinforcements: #{trace_a[:reinforcement_count]}
              - Last reinforced: #{trace_a[:last_reinforced]}

              TRACE B (#{trace_b[:trace_id][0..7]}):
              - Type: #{trace_b[:trace_type]}
              - Content: #{summarize_payload(trace_b[:content_payload])}
              - Valence: #{trace_b[:emotional_valence]} | Intensity: #{trace_b[:emotional_intensity]}
              - Strength: #{trace_b[:strength]&.round(3)} | Reinforcements: #{trace_b[:reinforcement_count]}
              - Last reinforced: #{trace_b[:last_reinforced]}

              Resolution strategy: #{strategy}

              Decide:
              1. Can one trace be identified as more reliable? If so, which one wins and why?
              2. If they are genuinely irreconcilable, say UNRESOLVABLE and explain why.

              Format your response EXACTLY as:
              VERDICT: WINNER_A | WINNER_B | UNRESOLVABLE
              REASONING: <one paragraph explanation>
            PROMPT
          end
          private_class_method :build_contradiction_prompt

          def parse_contradiction_response(response, trace_a, trace_b)
            return nil unless response&.content

            text = response.content
            verdict_match = text.match(/VERDICT:\s*(WINNER_A|WINNER_B|UNRESOLVABLE)/i)
            reasoning_match = text.match(/REASONING:\s*(.+)/im)

            verdict = verdict_match && verdict_match.captures.first.upcase.strip
            reasoning = (reasoning_match && reasoning_match.captures.first.strip) || text

            case verdict
            when 'WINNER_A'
              { resolution: :resolved, winner_id: trace_a[:trace_id],
                loser_id: trace_b[:trace_id], reasoning: reasoning }
            when 'WINNER_B'
              { resolution: :resolved, winner_id: trace_b[:trace_id],
                loser_id: trace_a[:trace_id], reasoning: reasoning }
            else
              { resolution: :unresolvable,
                trace_ids:  [trace_a[:trace_id], trace_b[:trace_id]],
                reasoning:  reasoning }
            end
          end
          private_class_method :parse_contradiction_response

          def build_agenda_prompt(unresolved_traces:, contradictions:, walk_results:, entropy:)
            sections = []

            if unresolved_traces.any?
              traces_summary = unresolved_traces.first(10).map do |t|
                "- [#{t[:trace_type]}] #{summarize_payload(t[:content_payload])} " \
                  "(valence=#{t[:emotional_valence]}, intensity=#{t[:emotional_intensity]})"
              end.join("\n")
              sections << "UNRESOLVED TRACES (#{unresolved_traces.size} total):\n#{traces_summary}"
            end

            if contradictions.any?
              contra_summary = contradictions.first(10).map do |c|
                domain = c[:domain] || 'unknown'
                resolution = c[:resolution] || 'pending'
                reasoning = c[:reasoning] ? " — #{c[:reasoning][0..80]}" : ''
                "- domain=#{domain} resolution=#{resolution}#{reasoning}"
              end.join("\n")
              sections << "CONTRADICTIONS (#{contradictions.size} total):\n#{contra_summary}"
            end

            if walk_results.any?
              walks_summary = walk_results.first(5).map do |w|
                "- path_length=#{w[:path]&.size} novelty=#{w[:novelty_score]&.round(3)}"
              end.join("\n")
              sections << "ASSOCIATION WALKS (#{walk_results.size} paths):\n#{walks_summary}"
            end

            if entropy.is_a?(Hash) && entropy[:classification]
              sections << "IDENTITY ENTROPY: #{entropy[:classification]} (trend=#{entropy[:trend]}, value=#{entropy[:entropy]&.round(4)})"
            end

            <<~PROMPT
              Based on the following dream cycle results, form an agenda of 3-5 items
              the agent should focus on. Each item should have a type, content, and weight.

              #{sections.join("\n\n")}

              Types: unresolved, surfacing, curious, corrective
              - unresolved: traces needing attention or resolution
              - surfacing: novel connections or insights worth remembering
              - curious: interesting patterns worth exploring further
              - corrective: issues or drift that need correction

              Format each item EXACTLY as:
              ITEM: <type> | <weight 0.0-1.0> | <one-line description>
            PROMPT
          end
          private_class_method :build_agenda_prompt

          def parse_agenda_response(response)
            return nil unless response&.content

            items = []
            response.content.scan(/ITEM:\s*(\w+)\s*\|\s*([\d.]+)\s*\|\s*(.+)/) do |type, weight, content|
              type_sym = type.strip.downcase.to_sym
              type_sym = :unresolved unless Constants::AGENDA_ITEM_TYPES.include?(type_sym)
              items << {
                type:    type_sym,
                weight:  weight.strip.to_f.clamp(0.0, 1.0),
                content: { description: content.strip, source: :llm }
              }
            end
            items.empty? ? nil : items
          end
          private_class_method :parse_agenda_response

          def build_journal_prompt(results, phase_data)
            metrics = journal_metrics(results, phase_data)
            details = journal_details(phase_data)

            <<~PROMPT
              Write a brief analytical summary (3-5 paragraphs) of this dream cycle.
              Focus on what the agent learned, what remains unresolved, and what it should
              pay attention to. Write as internal reflection, not a report.

              #{metrics}

              #{details}
            PROMPT
          end
          private_class_method :build_journal_prompt

          def journal_metrics(results, phase_data)
            audit   = results[:memory_audit] || {}
            contra  = results[:contradiction_resolution] || {}
            walk    = results[:association_walk] || {}
            entropy = results[:identity_entropy_check] || phase_data[:entropy] || {}
            agenda  = results[:agenda_formation] || {}
            commit  = results[:consolidation_commit] || {}
            walks   = phase_data[:walk_results] || []
            resolved = (contra[:resolutions] || []).count { |r| r[:resolution] == :resolved }

            <<~METRICS
              METRICS:
              - Traces decayed: #{audit[:decayed]} | Pruned: #{audit[:pruned]}
              - Unresolved found: #{audit[:unresolved_count]}
              - Association paths walked: #{walks.size} (start: #{walk[:start_trace]&.slice(0, 8) || 'none'})
              - Contradictions: #{contra[:detected]} detected, #{resolved} resolved
              - Identity entropy: #{entropy[:classification]} (#{entropy[:trend]})
              - Agenda items: #{agenda[:agenda_items]}
              - Traces consolidated: #{commit[:traces_written]}
            METRICS
          end
          private_class_method :journal_metrics

          def journal_details(phase_data)
            parts = []
            unresolved = phase_data[:unresolved_traces] || []
            contradictions = phase_data[:contradictions] || []

            if unresolved.any?
              lines = unresolved.first(5).map { |t| "  - [#{t[:trace_type]}] #{summarize_payload(t[:content_payload])}" }
              parts << "UNRESOLVED TRACES:\n#{lines.join("\n")}"
            end

            if contradictions.any?
              lines = contradictions.first(5).map do |c|
                reasoning = c[:reasoning] ? ": #{c[:reasoning][0..100]}" : ''
                "  - #{c[:resolution]}#{reasoning}"
              end
              parts << "CONTRADICTIONS:\n#{lines.join("\n")}"
            end

            parts.join("\n\n")
          end
          private_class_method :journal_details

          def summarize_payload(payload)
            case payload
            when String then payload[0..120]
            when Hash then payload.map { |k, v| "#{k}=#{v.to_s[0..40]}" }.first(5).join(', ')
            else payload.to_s[0..120]
            end
          end
          private_class_method :summarize_payload
        end
      end
    end
  end
end
