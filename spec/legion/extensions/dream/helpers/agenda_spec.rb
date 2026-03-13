# frozen_string_literal: true

RSpec.describe Legion::Extensions::Dream::Helpers::Agenda do
  describe '.build_from_phases' do
    it 'creates agenda items from phase outputs' do
      phase_outputs = {
        unresolved_traces: [{ trace_id: 'a', emotional_intensity: 0.7 }],
        contradictions:    [{ resolution: :unresolvable, trace_ids: %w[x y], domain: 'd' }],
        walk_results:      [{ trace_id: 'b', path: %w[s b], novelty_score: 0.9 }],
        entropy:           { classification: :high_entropy, trend: :rising, entropy: 0.8 }
      }
      items = described_class.build_from_phases(phase_outputs)
      types = items.map { |i| i[:type] }
      expect(types).to include(:unresolved, :surfacing, :curious, :corrective)
    end

    it 'skips corrective when entropy is normal' do
      phase_outputs = {
        unresolved_traces: [],
        contradictions:    [],
        walk_results:      [],
        entropy:           { classification: :normal, trend: :stable, entropy: 0.4 }
      }
      items = described_class.build_from_phases(phase_outputs)
      expect(items.map { |i| i[:type] }).not_to include(:corrective)
    end

    it 'skips corrective when entropy is high_entropy but trend is not rising' do
      phase_outputs = {
        unresolved_traces: [],
        contradictions:    [],
        walk_results:      [],
        entropy:           { classification: :high_entropy, trend: :stable, entropy: 0.8 }
      }
      items = described_class.build_from_phases(phase_outputs)
      expect(items.map { |i| i[:type] }).not_to include(:corrective)
    end

    it 'skips surfacing when all contradictions are resolved' do
      phase_outputs = {
        unresolved_traces: [],
        walk_results:      [],
        contradictions:    [{ resolution: :resolved, winner_id: 'x', loser_id: 'y' }],
        entropy:           { classification: :normal, trend: :stable, entropy: 0.4 }
      }
      items = described_class.build_from_phases(phase_outputs)
      expect(items.map { |i| i[:type] }).not_to include(:surfacing)
    end

    it 'uses emotional_intensity as weight for unresolved items' do
      phase_outputs = {
        unresolved_traces: [{ trace_id: 'a', emotional_intensity: 0.7 }],
        contradictions:    [],
        walk_results:      [],
        entropy:           { classification: :normal, trend: :stable, entropy: 0.4 }
      }
      items = described_class.build_from_phases(phase_outputs)
      expect(items.first[:weight]).to eq(0.7)
    end

    it 'uses novelty_score as weight for curious items' do
      phase_outputs = {
        unresolved_traces: [],
        contradictions:    [],
        walk_results:      [{ trace_id: 'b', path: %w[s b], novelty_score: 0.85 }],
        entropy:           { classification: :normal, trend: :stable, entropy: 0.4 }
      }
      items = described_class.build_from_phases(phase_outputs)
      curious = items.find { |i| i[:type] == :curious }
      expect(curious[:weight]).to eq(0.85)
    end

    it 'sets weight to 0.7 for surfacing items' do
      phase_outputs = {
        unresolved_traces: [],
        contradictions:    [{ resolution: :unresolvable, trace_ids: %w[x y], domain: 'auth' }],
        walk_results:      [],
        entropy:           { classification: :normal, trend: :stable, entropy: 0.4 }
      }
      items = described_class.build_from_phases(phase_outputs)
      surfacing = items.find { |i| i[:type] == :surfacing }
      expect(surfacing[:weight]).to eq(0.7)
    end

    it 'uses entropy value as weight for corrective items' do
      phase_outputs = {
        unresolved_traces: [],
        contradictions:    [],
        walk_results:      [],
        entropy:           { classification: :high_entropy, trend: :rising, entropy: 0.95 }
      }
      items = described_class.build_from_phases(phase_outputs)
      corrective = items.find { |i| i[:type] == :corrective }
      expect(corrective[:weight]).to eq(0.95)
    end

    it 'includes created_at on every item' do
      phase_outputs = {
        unresolved_traces: [{ trace_id: 'a', emotional_intensity: 0.5 }],
        contradictions:    [],
        walk_results:      [],
        entropy:           { classification: :normal, trend: :stable, entropy: 0.4 }
      }
      items = described_class.build_from_phases(phase_outputs)
      items.each { |item| expect(item).to have_key(:created_at) }
    end

    it 'returns empty array when all inputs are empty' do
      phase_outputs = {
        unresolved_traces: [],
        contradictions:    [],
        walk_results:      [],
        entropy:           { classification: :normal, trend: :stable, entropy: 0.2 }
      }
      expect(described_class.build_from_phases(phase_outputs)).to eq([])
    end
  end

  describe '.to_semantic_traces' do
    it 'converts agenda items to semantic traces' do
      items = [
        { type: :curious,    content: { path: %w[a b c] }, weight: 0.8,  created_at: Time.now.utc },
        { type: :unresolved, content: { trace_id: 'x' },   weight: 0.6,  created_at: Time.now.utc }
      ]
      traces = described_class.to_semantic_traces(items)
      expect(traces.size).to eq(2)
      expect(traces.first[:trace_type]).to eq(:semantic)
      expect(traces.first[:emotional_intensity]).to eq(0.8)
      expect(traces.first[:domain_tags]).to include('dream:curious')
      expect(traces.first[:content_payload][:dream_agenda]).to eq(:curious)
    end

    it 'embeds original content fields into content_payload' do
      items = [
        { type: :surfacing, content: { trace_ids: %w[x y], domain: 'auth' }, weight: 0.7, created_at: Time.now.utc }
      ]
      traces = described_class.to_semantic_traces(items)
      payload = traces.first[:content_payload]
      expect(payload[:dream_agenda]).to eq(:surfacing)
      expect(payload[:trace_ids]).to eq(%w[x y])
      expect(payload[:domain]).to eq('auth')
    end

    it 'returns empty array for empty input' do
      expect(described_class.to_semantic_traces([])).to eq([])
    end
  end
end
