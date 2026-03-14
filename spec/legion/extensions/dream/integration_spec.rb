# frozen_string_literal: true

RSpec.describe 'Dream cycle integration' do
  let(:memory_store) { Legion::Extensions::Memory::Helpers::Store.new }
  let(:memory_client) { Legion::Extensions::Memory::Client.new(store: memory_store) }
  let(:identity_client) { Legion::Extensions::Identity::Client.new }
  let(:emotion_client) { Legion::Extensions::Emotion::Client.new }
  let(:tick_client) { Legion::Extensions::Tick::Client.new(mode: :dormant) }
  let(:dream_client) do
    Legion::Extensions::Dream::Client.new(
      memory: memory_client, identity: identity_client, emotion: emotion_client
    )
  end
  let(:trace_helper) { Legion::Extensions::Memory::Helpers::Trace }

  it 'runs a complete dream cycle with populated memory' do
    # 1. Seed memory with 10 episodic traces (some unresolved)
    10.times do |i|
      t = trace_helper.new_trace(
        type:                :episodic,
        content_payload:     { event: "meeting_#{i}" },
        emotional_intensity: rand,
        emotional_valence:   rand(-1.0..1.0),
        domain_tags:         ['work']
      )
      t[:unresolved] = true if i < 3
      memory_store.store(t)
    end

    # 2. Add contradicting trust traces
    t_pos = trace_helper.new_trace(type: :trust, content_payload: { assessment: 'reliable' },
                                   domain_tags: ['partner'], emotional_valence: 0.9, emotional_intensity: 0.8)
    t_neg = trace_helper.new_trace(type: :trust, content_payload: { assessment: 'unreliable' },
                                   domain_tags: ['partner'], emotional_valence: -0.8, emotional_intensity: 0.3)
    t_neg[:last_reinforced] = Time.now.utc - 172_800
    memory_store.store(t_pos)
    memory_store.store(t_neg)

    # 3. Link traces for association walking
    all_ids = memory_store.all_traces.map { |t| t[:trace_id] }
    all_ids.each_cons(2) do |a, b|
      ta = memory_store.get(a)
      tb = memory_store.get(b)
      ta[:associated_traces] << b
      tb[:associated_traces] << a
    end

    # 4. Simulate tick transition to dormant_active
    tick_state = tick_client.send(:tick_state)
    allow(tick_state).to receive(:seconds_since_signal).and_return(1801.0)
    transition = tick_client.evaluate_mode_transition(signals: [])
    expect(transition[:new_mode]).to eq(:dormant_active)

    # 5. Run dream cycle
    result = dream_client.execute_dream_cycle
    expect(result[:status]).to eq(:completed)

    # 6. Verify each phase produced output
    expect(result[:phases][:memory_audit][:decayed]).to be >= 0
    expect(result[:phases][:memory_audit][:unresolved_count]).to be >= 3
    expect(result[:phases][:association_walk]).to have_key(:walk_results)
    expect(result[:phases][:contradiction_resolution][:detected]).to be >= 1
    expect(result[:phases][:identity_entropy_check]).to have_key(:entropy)
    expect(result[:phases][:agenda_formation]).to have_key(:agenda_items)
    expect(result[:phases][:consolidation_commit][:dream_store_cleared]).to be true

    # 7. Verify unresolved flags cleared after cycle
    unresolved = memory_store.all_traces.select { |t| t[:unresolved] == true }
    expect(unresolved).to be_empty

    # 8. Verify dream-tagged semantic traces exist in memory (organic recall mechanism)
    dream_traces = memory_store.all_traces.select { |t| t[:domain_tags].any? { |d| d.start_with?('dream:') } }
    # May be 0 if no agenda items formed (depends on phase outputs), but structure should work
    expect(dream_traces).to all(satisfy { |t| t[:trace_type] == :semantic })

    # 9. Simulate return to dormant after dream completes
    transition = tick_client.evaluate_mode_transition(signals: [], dream_complete: true)
    expect(transition[:new_mode]).to eq(:dormant)
  end

  it 'handles empty memory gracefully' do
    result = dream_client.execute_dream_cycle
    expect(result[:status]).to eq(:completed)
    expect(result[:phases][:memory_audit][:decayed]).to eq(0)
    expect(result[:phases][:association_walk][:walk_results]).to be_empty
    expect(result[:phases][:contradiction_resolution][:detected]).to eq(0)
  end

  it 'handles memory with no unresolved traces' do
    5.times do |i|
      memory_store.store(trace_helper.new_trace(type: :episodic, content_payload: { i: i }))
    end
    result = dream_client.execute_dream_cycle
    expect(result[:status]).to eq(:completed)
    expect(result[:phases][:association_walk][:walk_results]).to be_empty
    expect(result[:phases][:association_walk][:start_trace]).to be_nil
  end
end
