# frozen_string_literal: true

require_relative 'lib/legion/extensions/dream/version'

Gem::Specification.new do |spec|
  spec.name          = 'lex-dream'
  spec.version       = Legion::Extensions::Dream::VERSION
  spec.authors       = ['Esity']
  spec.email         = ['matthewdiverson@gmail.com']

  spec.summary       = 'LEX Dream'
  spec.description   = 'Autonomous dream cycle for brain-modeled agentic AI — memory consolidation, association walking, contradiction resolution, and agenda formation'
  spec.homepage      = 'https://github.com/LegionIO/lex-dream'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/LegionIO/lex-dream'
  spec.metadata['documentation_uri'] = 'https://github.com/LegionIO/lex-dream'
  spec.metadata['changelog_uri'] = 'https://github.com/LegionIO/lex-dream'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/LegionIO/lex-dream/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ['lib']
end
