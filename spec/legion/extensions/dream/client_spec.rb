# frozen_string_literal: true

RSpec.describe Legion::Extensions::Dream::Client do
  let(:memory_client)   { Legion::Extensions::Memory::Client.new }
  let(:identity_client) { Legion::Extensions::Identity::Client.new }
  let(:emotion_client)  { Legion::Extensions::Emotion::Client.new }

  describe '#initialize' do
    it 'accepts dependency injection' do
      client = described_class.new(memory: memory_client, identity: identity_client, emotion: emotion_client)
      expect(client.dream_store).to be_a(Legion::Extensions::Dream::Helpers::DreamStore)
    end

    it 'creates default clients when none injected' do
      client = described_class.new
      expect(client).to respond_to(:execute_dream_cycle)
    end
  end

  describe '#execute_dream_cycle' do
    it 'completes a full cycle' do
      client = described_class.new(memory: memory_client, identity: identity_client, emotion: emotion_client)
      result = client.execute_dream_cycle
      expect(result[:status]).to eq(:completed)
    end
  end
end
