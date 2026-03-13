# frozen_string_literal: true

require 'bundler/setup'
require 'legion/extensions/memory'
require 'legion/extensions/memory/client'
require 'legion/extensions/identity'
require 'legion/extensions/identity/client'
require 'legion/extensions/emotion'
require 'legion/extensions/emotion/client'
require 'legion/extensions/dream'

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
