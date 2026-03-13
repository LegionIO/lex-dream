# frozen_string_literal: true

RSpec.describe Legion::Extensions::Dream::Helpers::DreamStore do
  let(:store) { described_class.new }
  let(:now) { Time.now.utc }

  describe 'agenda management' do
    it 'adds an agenda item' do
      store.add_agenda_item(type: :unresolved, content: 'something unresolved', weight: 0.8)
      expect(store.agenda.size).to eq(1)
      item = store.agenda.first
      expect(item[:type]).to eq(:unresolved)
      expect(item[:content]).to eq('something unresolved')
      expect(item[:weight]).to eq(0.8)
    end

    it 'respects AGENDA_MAX_ITEMS limit' do
      max = Legion::Extensions::Dream::Helpers::Constants::AGENDA_MAX_ITEMS
      (max + 3).times { |i| store.add_agenda_item(type: :curious, content: "item #{i}", weight: 0.5) }
      expect(store.agenda.size).to eq(max)
    end

    it 'drops oldest items when limit exceeded' do
      max = Legion::Extensions::Dream::Helpers::Constants::AGENDA_MAX_ITEMS
      (max + 2).times { |i| store.add_agenda_item(type: :surfacing, content: "item #{i}", weight: 0.5) }
      contents = store.agenda.map { |item| item[:content] }
      expect(contents).not_to include('item 0')
      expect(contents).not_to include('item 1')
      expect(contents).to include("item #{max + 1}")
    end

    it 'validates agenda item type' do
      expect { store.add_agenda_item(type: :invalid, content: 'bad', weight: 0.5) }
        .to raise_error(ArgumentError)
    end

    it 'timestamps agenda items' do
      before = Time.now.utc
      store.add_agenda_item(type: :corrective, content: 'check this', weight: 0.7)
      after = Time.now.utc
      ts = store.agenda.first[:created_at]
      expect(ts).to be_a(Time)
      expect(ts).to be >= before
      expect(ts).to be <= after
    end

    it 'clamps weight to 0.0..1.0' do
      store.add_agenda_item(type: :unresolved, content: 'heavy', weight: 2.5)
      expect(store.agenda.first[:weight]).to eq(1.0)

      store.clear
      store.add_agenda_item(type: :unresolved, content: 'light', weight: -0.5)
      expect(store.agenda.first[:weight]).to eq(0.0)
    end
  end

  describe 'walk results' do
    it 'records a walk result' do
      store.record_walk_result(source_id: 'mem-1', path: %w[a b c], novelty_score: 0.72)
      expect(store.walk_results.size).to eq(1)
      result = store.walk_results.first
      expect(result[:source_id]).to eq('mem-1')
      expect(result[:path]).to eq(%w[a b c])
      expect(result[:novelty_score]).to eq(0.72)
    end

    it 'includes discovery timestamp' do
      before = Time.now.utc
      store.record_walk_result(source_id: 'mem-2', path: [], novelty_score: 0.5)
      after = Time.now.utc
      ts = store.walk_results.first[:discovered_at]
      expect(ts).to be_a(Time)
      expect(ts).to be >= before
      expect(ts).to be <= after
    end
  end

  describe 'contradictions' do
    it 'records a contradiction' do
      store.record_contradiction(trace_ids: %w[t1 t2], domain: :belief, resolution: :recency_weighted)
      expect(store.contradictions.size).to eq(1)
      c = store.contradictions.first
      expect(c[:trace_ids]).to eq(%w[t1 t2])
      expect(c[:domain]).to eq(:belief)
      expect(c[:resolution]).to eq(:recency_weighted)
      expect(c[:resolved_at]).to be_a(Time)
    end
  end

  describe 'entropy history' do
    it 'records an entropy snapshot' do
      store.record_entropy(entropy: 0.42, classification: :stable, trend: :decreasing)
      expect(store.entropy_history.size).to eq(1)
      snap = store.entropy_history.first
      expect(snap[:entropy]).to eq(0.42)
      expect(snap[:classification]).to eq(:stable)
      expect(snap[:trend]).to eq(:decreasing)
      expect(snap[:checked_at]).to be_a(Time)
    end
  end

  describe 'TTL expiration' do
    let(:ttl) { Legion::Extensions::Dream::Helpers::Constants::DREAM_PARTITION_TTL }

    it 'expires agenda items older than DREAM_PARTITION_TTL' do
      store.add_agenda_item(type: :unresolved, content: 'stale', weight: 0.5)
      store.agenda.first[:created_at] = now - (ttl + 100)
      store.expire_stale!
      expect(store.agenda).to be_empty
    end

    it 'expires walk results older than DREAM_PARTITION_TTL' do
      store.record_walk_result(source_id: 'old', path: [], novelty_score: 0.1)
      store.walk_results.first[:discovered_at] = now - (ttl + 100)
      store.expire_stale!
      expect(store.walk_results).to be_empty
    end

    it 'keeps items within TTL' do
      store.add_agenda_item(type: :curious, content: 'fresh', weight: 0.6)
      store.record_walk_result(source_id: 'new', path: [], novelty_score: 0.9)
      store.expire_stale!
      expect(store.agenda.size).to eq(1)
      expect(store.walk_results.size).to eq(1)
    end
  end

  describe '#clear' do
    it 'empties all stores' do
      store.add_agenda_item(type: :unresolved, content: 'x', weight: 0.5)
      store.record_walk_result(source_id: 'y', path: [], novelty_score: 0.3)
      store.record_contradiction(trace_ids: %w[a], domain: :goal, resolution: :recency_weighted)
      store.record_entropy(entropy: 0.5, classification: :elevated, trend: :stable)
      store.clear
      expect(store.agenda).to be_empty
      expect(store.walk_results).to be_empty
      expect(store.contradictions).to be_empty
      expect(store.entropy_history).to be_empty
    end
  end
end
