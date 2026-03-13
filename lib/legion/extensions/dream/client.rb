# frozen_string_literal: true

module Legion
  module Extensions
    module Dream
      class Client
        include Runners::DreamCycle

        attr_reader :dream_store

        def initialize(memory: nil, identity: nil, emotion: nil, **)
          @memory      = memory   || Legion::Extensions::Memory::Client.new
          @identity    = identity || Legion::Extensions::Identity::Client.new
          @emotion     = emotion  || Legion::Extensions::Emotion::Client.new
          @dream_store = Helpers::DreamStore.new
          @phase_data  = {}
        end

        private

        attr_reader :memory, :identity, :emotion, :phase_data
      end
    end
  end
end
