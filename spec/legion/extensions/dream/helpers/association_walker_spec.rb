# frozen_string_literal: true

RSpec.describe Legion::Extensions::Dream::Helpers::AssociationWalker do
  let(:trace_helper) { Legion::Extensions::Memory::Helpers::Trace }
  let(:memory_store) { Legion::Extensions::Memory::Helpers::Store.new }

  let(:trace_a) do
    trace_helper.new_trace(
      type:                :episodic,
      content_payload:     'Event A - high intensity unresolved',
      emotional_intensity: 0.9,
      unresolved:          true
    )
  end

  let(:trace_b) do
    trace_helper.new_trace(
      type:                :semantic,
      content_payload:     'Concept B',
      emotional_intensity: 0.3,
      unresolved:          false
    )
  end

  let(:trace_c) do
    trace_helper.new_trace(
      type:                :trust,
      content_payload:     'Trust C',
      emotional_intensity: 0.2,
      unresolved:          false
    )
  end

  before do
    # Store all traces
    memory_store.store(trace_a)
    memory_store.store(trace_b)
    memory_store.store(trace_c)

    # Link: a -> b -> c (bidirectional)
    trace_a[:associated_traces] << trace_b[:trace_id]
    trace_b[:associated_traces] << trace_a[:trace_id]
    trace_b[:associated_traces] << trace_c[:trace_id]
    trace_c[:associated_traces] << trace_b[:trace_id]
  end

  describe '.walk' do
    it 'returns walk results with novelty scores' do
      results = described_class.walk(store: memory_store, start_id: trace_a[:trace_id])
      expect(results).not_to be_empty
      expect(results.first).to have_key(:novelty_score)
      expect(results.first).to have_key(:trace_id)
      expect(results.first).to have_key(:depth)
      expect(results.first).to have_key(:path)
    end

    it 'filters results below novelty threshold' do
      results = described_class.walk(
        store:             memory_store,
        start_id:          trace_a[:trace_id],
        novelty_threshold: 1.0
      )
      expect(results).to be_empty
    end

    it 'scores novel paths higher than previously traversed paths' do
      first_results = described_class.walk(
        store:             memory_store,
        start_id:          trace_a[:trace_id],
        novelty_threshold: 0.0
      )
      expect(first_results).not_to be_empty

      known = Set.new(first_results.map { |r| r[:path].join('->') })

      # All paths now known — novelty scores drop to 0.0, below the default threshold
      second_results = described_class.walk(
        store:       memory_store,
        start_id:    trace_a[:trace_id],
        known_paths: known
      )
      expect(second_results).to be_empty
    end

    it 'respects max_hops' do
      results = described_class.walk(
        store:    memory_store,
        start_id: trace_a[:trace_id],
        max_hops: 1
      )
      results.each { |r| expect(r[:depth]).to be <= 1 }
    end
  end

  describe '.select_start_trace' do
    it 'returns the highest-salience unresolved episodic trace' do
      # Add a second unresolved episodic with lower intensity
      trace_d = trace_helper.new_trace(
        type:                :episodic,
        content_payload:     'Lower priority episodic',
        emotional_intensity: 0.4,
        unresolved:          true
      )
      memory_store.store(trace_d)

      result = described_class.select_start_trace(store: memory_store)
      expect(result).not_to be_nil
      expect(result[:trace_type]).to eq(:episodic)
      expect(result[:unresolved]).to be true
      expect(result[:trace_id]).to eq(trace_a[:trace_id])
    end

    it 'returns nil when no unresolved episodic traces exist' do
      # Only b and c are in a fresh store with no unresolved episodics
      fresh_store = Legion::Extensions::Memory::Helpers::Store.new
      fresh_store.store(trace_b)
      fresh_store.store(trace_c)

      result = described_class.select_start_trace(store: fresh_store)
      expect(result).to be_nil
    end
  end
end
