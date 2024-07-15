lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require_relative 'lib/sms_traffic/version'

Gem::Specification.new do |spec|
  spec.name          = 'sms_traffic'
  spec.version       = SmsTraffic::VERSION
  spec.authors       = ['David Rybolovlev']
  spec.email         = ['i@golifox.ru']

  spec.summary       = 'Send sms via SmsTraffic service.'
  spec.description   = 'Send sms via SmsTraffic service.'
  spec.homepage      = 'https://github.com/golifox/sms_traffic'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.7.0'

  spec.add_dependency 'nokogiri', '~> 1.12'
  spec.add_dependency 'nori', '~> 2.6'
  spec.add_dependency 'zeitwerk', '~> 2.5'

  spec.metadata['rubygems_mfa_required'] = 'true'
end
