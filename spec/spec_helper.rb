# frozen_string_literal: true

require 'bundler/setup'

# Stub Legion::Logging and framework classes before loading extensions
module Legion
  module Logging
    def self.debug(_msg); end

    def self.info(_msg); end

    def self.warn(_msg); end

    def self.error(_msg); end
  end

  module Extensions
    module Actors
      class Every; end # rubocop:disable Lint/EmptyClass
    end

    module Helpers
      module Lex; end
    end
  end
end

# Satisfy file-level requires from actor classes (e.g. lex-identity OrphanCheck)
$LOADED_FEATURES << 'legion/extensions/actors/every'

require 'legion/extensions/memory'
require 'legion/extensions/memory/client'
require 'legion/extensions/identity'
require 'legion/extensions/identity/client'
require 'legion/extensions/emotion'
require 'legion/extensions/emotion/client'
require 'legion/extensions/tick'
require 'legion/extensions/tick/client'
require 'legion/extensions/dream'

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
