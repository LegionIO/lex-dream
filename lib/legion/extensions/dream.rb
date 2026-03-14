# frozen_string_literal: true

require 'legion/extensions/dream/version'
require 'legion/extensions/dream/helpers/constants'
require 'legion/extensions/dream/helpers/dream_store'
require 'legion/extensions/dream/helpers/association_walker'
require 'legion/extensions/dream/helpers/contradiction_detector'
require 'legion/extensions/dream/helpers/agenda'
require 'legion/extensions/dream/helpers/dream_journal'
require 'legion/extensions/dream/helpers/llm_enhancer'
require 'legion/extensions/dream/runners/dream_cycle'
require 'legion/extensions/dream/client'

module Legion
  module Extensions
    module Dream
      extend Legion::Extensions::Core if Legion::Extensions.const_defined? :Core
    end
  end
end
