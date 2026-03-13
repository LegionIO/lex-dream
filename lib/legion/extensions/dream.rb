# frozen_string_literal: true

require 'legion/extensions/dream/version'
require 'legion/extensions/dream/helpers/constants'

module Legion
  module Extensions
    module Dream
      extend Legion::Extensions::Core if Legion::Extensions.const_defined? :Core
    end
  end
end
