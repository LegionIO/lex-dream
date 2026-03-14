# frozen_string_literal: true

RSpec.describe Legion::Extensions::Dream::Helpers::ContradictionDetector do
  let(:trace_helper) { Legion::Extensions::Memory::Helpers::Trace }
  let(:store) { Legion::Extensions::Memory::Helpers::Store.new }

  describe '.detect' do
    it 'finds contradictions between same-domain traces with opposing valence' do
      t1 = trace_helper.new_trace(
        type:                :trust,
        content_payload:     'partner was reliable',
        domain_tags:         ['partner_reliability'],
        emotional_valence:   0.8,
        emotional_intensity: 0.7
      )
      t2 = trace_helper.new_trace(
        type:                :trust,
        content_payload:     'partner was unreliable',
        domain_tags:         ['partner_reliability'],
        emotional_valence:   -0.7,
        emotional_intensity: 0.6
      )
      store.store(t1)
      store.store(t2)

      results = described_class.detect(store: store)
      expect(results.size).to eq(1)
      expect(results.first[:trace_ids]).to contain_exactly(t1[:trace_id], t2[:trace_id])
      expect(results.first[:domain]).to eq('partner_reliability')
      expect(results.first).to have_key(:valence_a)
      expect(results.first).to have_key(:valence_b)
    end

    it 'ignores traces in different domains' do
      t1 = trace_helper.new_trace(
        type:                :trust,
        content_payload:     'domain a positive',
        domain_tags:         ['domain_a'],
        emotional_valence:   0.8,
        emotional_intensity: 0.7
      )
      t2 = trace_helper.new_trace(
        type:                :trust,
        content_payload:     'domain b negative',
        domain_tags:         ['domain_b'],
        emotional_valence:   -0.8,
        emotional_intensity: 0.7
      )
      store.store(t1)
      store.store(t2)

      results = described_class.detect(store: store)
      expect(results).to be_empty
    end

    it 'ignores same-valence-direction traces' do
      t1 = trace_helper.new_trace(
        type:                :semantic,
        content_payload:     'positive belief one',
        domain_tags:         ['belief_a'],
        emotional_valence:   0.6,
        emotional_intensity: 0.5
      )
      t2 = trace_helper.new_trace(
        type:                :semantic,
        content_payload:     'positive belief two',
        domain_tags:         ['belief_a'],
        emotional_valence:   0.8,
        emotional_intensity: 0.5
      )
      store.store(t1)
      store.store(t2)

      results = described_class.detect(store: store)
      expect(results).to be_empty
    end

    it 'only scans trust and semantic trace types' do
      t1 = trace_helper.new_trace(
        type:                :episodic,
        content_payload:     'positive episode',
        domain_tags:         ['shared_domain'],
        emotional_valence:   0.9,
        emotional_intensity: 0.8
      )
      t2 = trace_helper.new_trace(
        type:                :episodic,
        content_payload:     'negative episode',
        domain_tags:         ['shared_domain'],
        emotional_valence:   -0.9,
        emotional_intensity: 0.8
      )
      store.store(t1)
      store.store(t2)

      results = described_class.detect(store: store)
      expect(results).to be_empty
    end
  end

  describe '.resolve' do
    let(:recent_trace) do
      t = trace_helper.new_trace(
        type:                :trust,
        content_payload:     'recent strong trace',
        domain_tags:         ['reliability'],
        emotional_valence:   0.8,
        emotional_intensity: 0.9
      )
      store.store(t)
      t
    end

    let(:old_trace) do
      t = trace_helper.new_trace(
        type:                :trust,
        content_payload:     'old weak trace',
        domain_tags:         ['reliability'],
        emotional_valence:   -0.7,
        emotional_intensity: 0.1
      )
      t[:last_reinforced] = Time.now.utc - 86_400
      store.store(t)
      t
    end

    it 'reinforces the winner and decays the loser with recency_weighted strategy' do
      recent_trace
      old_trace

      winner_strength_before = recent_trace[:strength]
      loser_strength_before = old_trace[:strength]

      result = described_class.resolve(
        trace_ids: [recent_trace[:trace_id], old_trace[:trace_id]],
        store:     store,
        strategy:  :recency_weighted
      )

      expect(result[:resolution]).to eq(:resolved)
      expect(result[:winner_id]).to eq(recent_trace[:trace_id])
      expect(result[:loser_id]).to eq(old_trace[:trace_id])

      winner = store.get(recent_trace[:trace_id])
      loser  = store.get(old_trace[:trace_id])

      expect(winner[:strength]).to be > winner_strength_before
      expect(loser[:strength]).to be < loser_strength_before
    end

    it 'returns unresolvable when traces are equally weighted' do
      now = Time.now.utc

      t1 = trace_helper.new_trace(
        type:                :trust,
        content_payload:     'equal trace one',
        domain_tags:         ['shared'],
        emotional_valence:   0.6,
        emotional_intensity: 0.5
      )
      t1[:last_reinforced] = now
      store.store(t1)

      t2 = trace_helper.new_trace(
        type:                :trust,
        content_payload:     'equal trace two',
        domain_tags:         ['shared'],
        emotional_valence:   -0.6,
        emotional_intensity: 0.5
      )
      t2[:last_reinforced] = now
      store.store(t2)

      result = described_class.resolve(
        trace_ids: [t1[:trace_id], t2[:trace_id]],
        store:     store,
        strategy:  :recency_weighted
      )

      expect(result[:resolution]).to eq(:unresolvable)
    end
  end
end
