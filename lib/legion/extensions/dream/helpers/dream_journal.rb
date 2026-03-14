# frozen_string_literal: true

require 'fileutils'

module Legion
  module Extensions
    module Dream
      module Helpers
        module DreamJournal
          JOURNAL_DIR = File.join(Dir.pwd, 'logs', 'dreams')

          module_function

          def write_entry(results:, phase_data:, dream_store:)
            FileUtils.mkdir_p(JOURNAL_DIR)

            timestamp = Time.now.utc.strftime('%Y-%m-%d_%H%M%S')
            path = File.join(JOURNAL_DIR, "dream-#{timestamp}.md")

            content = build_entry(results, phase_data, dream_store)
            File.write(path, content)

            Legion::Logging.info "[dream] journal written to #{path}"
            path
          rescue StandardError => e
            Legion::Logging.warn "[dream] journal write failed: #{e.message}"
            nil
          end

          def build_entry(results, phase_data, _dream_store)
            lines = ["# Dream Cycle — #{Time.now.utc.strftime('%Y-%m-%d %H:%M:%S UTC')}", '']
            section_memory_audit(lines, results, phase_data)
            section_association_walk(lines, results, phase_data)
            section_contradiction_resolution(lines, results)
            section_identity_entropy(lines, results, phase_data)
            section_agenda(lines, results, phase_data)
            section_consolidation(lines, results)
            section_summary(lines, results, phase_data)
            lines.join("\n")
          end

          def section_memory_audit(lines, results, phase_data)
            audit = results[:memory_audit] || {}
            lines << '## Phase 1: Memory Audit'
            lines << ''
            lines << "- Traces decayed: #{audit[:decayed]}"
            lines << "- Traces pruned: #{audit[:pruned]}"
            lines << "- Tier migrations: #{audit[:migrated]}"
            lines << "- Consolidation candidates: #{audit[:consolidation_candidates]}"
            lines << "- Unresolved traces found: #{audit[:unresolved_count]}"
            lines << ''

            unresolved = phase_data[:unresolved_traces] || []
            return unless unresolved.any?

            lines << '### Unresolved Traces'
            lines << ''
            unresolved.first(20).each do |t|
              payload = truncate(extract_payload(t[:content_payload]), 120)
              lines << "- **#{t[:trace_type]}** (#{t[:trace_id][0..7]}) " \
                       "strength=#{t[:strength]&.round(3)} valence=#{t[:emotional_valence]} " \
                       "intensity=#{t[:emotional_intensity]} confidence=#{t[:confidence]}"
              lines << "  > #{payload}"
            end
            lines << "  _(#{unresolved.size - 20} more...)_" if unresolved.size > 20
            lines << ''
          end

          def section_association_walk(lines, results, phase_data)
            walk = results[:association_walk] || {}
            lines << '## Phase 2: Association Walk'
            lines << ''
            lines << "- Start trace: #{walk[:start_trace]&.slice(0, 8) || 'none'}"
            walk_results = phase_data[:walk_results] || []
            lines << "- Paths found: #{walk_results.size}"
            walk_results.first(10).each do |wr|
              path_str = wr[:path]&.map { |id| id[0..7] }&.join(' -> ')
              lines << "  - novelty=#{wr[:novelty_score]&.round(3)}: #{path_str}"
            end
            lines << ''
          end

          def section_contradiction_resolution(lines, results)
            contra = results[:contradiction_resolution] || {}
            resolutions = contra[:resolutions] || []
            resolved_count = resolutions.count { |r| r[:resolution] == :resolved }
            unresolvable_count = resolutions.count { |r| r[:resolution] == :unresolvable }

            lines << '## Phase 3: Contradiction Resolution'
            lines << ''
            lines << "- Contradictions detected: #{contra[:detected]}"
            lines << "- Resolved: #{resolved_count}"
            lines << "- Unresolvable: #{unresolvable_count}"
            lines << ''

            return unless resolutions.any?

            lines << '### Contradiction Details (first 15)'
            lines << ''
            format_resolutions(lines, resolutions.first(15))
            lines << ''
          end

          def section_identity_entropy(lines, results, phase_data)
            entropy = results[:identity_entropy_check] || phase_data[:entropy] || {}
            lines << '## Phase 4: Identity Entropy'
            lines << ''
            lines << "- Classification: #{entropy[:classification]}"
            lines << "- Trend: #{entropy[:trend]}"
            lines << "- Entropy value: #{entropy[:entropy]&.round(4)}"
            lines << ''
          end

          def section_agenda(lines, results, phase_data)
            agenda = results[:agenda_formation] || {}
            lines << '## Phase 5: Agenda Formation'
            lines << ''
            lines << "- Total agenda items: #{agenda[:agenda_items]}"
            lines << ''

            agenda_items = phase_data[:agenda_snapshot] || []
            return unless agenda_items.any?

            agenda_items.group_by { |i| i[:type] }.each do |type, items|
              lines << "### #{type} (#{items.size})"
              lines << ''
              items.first(10).each do |item|
                lines << "- weight=#{item[:weight]&.round(3)}: #{summarize_content(item[:content])}"
              end
              lines << "  _(#{items.size - 10} more...)_" if items.size > 10
              lines << ''
            end
          end

          def section_consolidation(lines, results)
            commit = results[:consolidation_commit] || {}
            lines << '## Phase 6: Consolidation Commit'
            lines << ''
            lines << "- Traces written to memory: #{commit[:traces_written]}"
            lines << "- Dream store cleared: #{commit[:dream_store_cleared]}"
            lines << ''
          end

          def section_summary(lines, results, phase_data)
            audit = results[:memory_audit] || {}
            contra = results[:contradiction_resolution] || {}
            walk_results = phase_data[:walk_results] || []
            resolved = (contra[:resolutions] || []).count { |r| r[:resolution] == :resolved }

            lines << '---'
            lines << ''
            lines << '## Summary'
            lines << ''
            lines << '| Metric | Value |'
            lines << '|--------|-------|'
            lines << "| Traces decayed | #{audit[:decayed]} |"
            lines << "| Unresolved found | #{audit[:unresolved_count]} |"
            lines << "| Associations walked | #{walk_results.size} |"
            lines << "| Contradictions detected | #{contra[:detected]} |"
            lines << "| Contradictions resolved | #{resolved} |"
            lines << "| Agenda items formed | #{(results[:agenda_formation] || {})[:agenda_items]} |"
            lines << "| Traces consolidated | #{(results[:consolidation_commit] || {})[:traces_written]} |"
          end

          def format_resolutions(lines, resolutions)
            resolutions.each do |r|
              domain = r[:domain] ? " domain=#{r[:domain]}" : ''
              valence = r[:valence_a] ? " (#{r[:valence_a]&.round(2)} vs #{r[:valence_b]&.round(2)})" : ''
              lines << if r[:resolution] == :resolved
                         "- **resolved**:#{domain} winner=#{r[:winner_id]&.slice(0, 8)} loser=#{r[:loser_id]&.slice(0, 8)}#{valence}"
                       elsif r[:trace_ids]
                         "- **unresolvable**:#{domain} traces=#{r[:trace_ids].map { |id| id[0..7] }.join(', ')}#{valence}"
                       else
                         "- **unresolvable**:#{domain}#{valence}"
                       end
            end
          end

          def extract_payload(payload)
            case payload
            when String then payload
            when Hash
              payload[:dream_agenda] ? "#{payload[:dream_agenda]}: #{payload.except(:dream_agenda)}" : payload.to_s
            else payload.to_s
            end
          end

          def truncate(str, max)
            str.length > max ? "#{str[0..max]}..." : str
          end

          def summarize_content(content)
            case content
            when Hash
              content.map { |k, v| "#{k}=#{v.is_a?(String) ? v[0..60] : v}" }.join(', ')
            else
              content.to_s[0..100]
            end
          end

          private_class_method :section_memory_audit, :section_association_walk,
                               :section_contradiction_resolution, :section_identity_entropy,
                               :section_agenda, :section_consolidation, :section_summary,
                               :format_resolutions, :extract_payload, :truncate, :summarize_content
        end
      end
    end
  end
end
