# frozen_string_literal: true

RSpec.describe Legion::Extensions::Dream::Runners::DreamCycle do
  let(:memory_store)    { Legion::Extensions::Memory::Helpers::Store.new }
  let(:memory_client)   { Legion::Extensions::Memory::Client.new(store: memory_store) }
  let(:identity_client) { Legion::Extensions::Identity::Client.new }
  let(:emotion_client)  { Legion::Extensions::Emotion::Client.new }
  let(:client) do
    Legion::Extensions::Dream::Client.new(
      memory:   memory_client,
      identity: identity_client,
      emotion:  emotion_client
    )
  end
  let(:trace_helper) { Legion::Extensions::Memory::Helpers::Trace }

  describe '#execute_dream_cycle' do
    it 'returns a result hash with all six phases' do
      result = client.execute_dream_cycle
      expect(result[:phases].keys).to contain_exactly(
        :memory_audit, :association_walk, :contradiction_resolution,
        :identity_entropy_check, :agenda_formation, :consolidation_commit
      )
    end

    it 'returns completed status' do
      result = client.execute_dream_cycle
      expect(result[:status]).to eq(:completed)
    end
  end

  describe '#phase_memory_audit' do
    before do
      3.times { |i| memory_store.store(trace_helper.new_trace(type: :episodic, content_payload: { i: i })) }
    end

    it 'runs decay and migration' do
      result = client.phase_memory_audit
      expect(result).to have_key(:decayed)
      expect(result).to have_key(:migrated)
    end

    it 'identifies consolidation candidates' do
      t = trace_helper.new_trace(type: :episodic, content_payload: {})
      t[:reinforcement_count] = 10
      t[:strength] = 0.3
      memory_store.store(t)
      client.phase_memory_audit
      expect(memory_store.get(t[:trace_id])[:consolidation_candidate]).to be true
    end
  end

  describe '#phase_association_walk' do
    it 'returns walk results when unresolved traces exist' do
      t1 = trace_helper.new_trace(type: :episodic, content_payload: {}, emotional_intensity: 0.8, unresolved: true)
      t2 = trace_helper.new_trace(type: :semantic, content_payload: {})
      memory_store.store(t1)
      memory_store.store(t2)
      t1[:associated_traces] << t2[:trace_id]
      t2[:associated_traces] << t1[:trace_id]
      result = client.phase_association_walk
      expect(result[:walk_results]).to be_an(Array)
    end

    it 'returns empty when no unresolved traces' do
      memory_store.store(trace_helper.new_trace(type: :episodic, content_payload: {}))
      result = client.phase_association_walk
      expect(result[:walk_results]).to be_empty
    end
  end

  describe '#phase_contradiction_resolution' do
    it 'detects and resolves contradictions' do
      t1 = trace_helper.new_trace(type: :trust, content_payload: {},
                                  domain_tags: ['reliability'], emotional_valence: 0.8, emotional_intensity: 0.9)
      t2 = trace_helper.new_trace(type: :trust, content_payload: {},
                                  domain_tags: ['reliability'], emotional_valence: -0.7, emotional_intensity: 0.2)
      t2[:last_reinforced] = Time.now.utc - 86_400
      memory_store.store(t1)
      memory_store.store(t2)
      result = client.phase_contradiction_resolution
      expect(result[:detected]).to be >= 1
    end
  end

  describe '#phase_identity_entropy_check' do
    it 'returns entropy assessment' do
      result = client.phase_identity_entropy_check
      expect(result).to have_key(:entropy)
      expect(result).to have_key(:classification)
    end
  end

  describe '#phase_agenda_formation' do
    it 'builds agenda from collected phase data' do
      t = trace_helper.new_trace(type: :episodic, content_payload: {}, unresolved: true, emotional_intensity: 0.7)
      memory_store.store(t)
      client.phase_memory_audit
      client.phase_association_walk
      client.phase_contradiction_resolution
      client.phase_identity_entropy_check
      result = client.phase_agenda_formation
      expect(result).to have_key(:agenda_items)
    end
  end

  describe '#phase_consolidation_commit' do
    it 'writes agenda traces to memory and clears dream store' do
      client.dream_store.add_agenda_item(type: :curious, content: { path: %w[a b] }, weight: 0.8)
      result = client.phase_consolidation_commit
      expect(result[:traces_written]).to be >= 0
      expect(result[:dream_store_cleared]).to be true
    end
  end
end
