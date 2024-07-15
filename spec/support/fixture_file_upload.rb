module Fixture
  def fixture(fixture_name)
    File.read(File.join(fixture_path, fixture_name))
  end

  def fixture_path
    File.expand_path('fixtures', 'spec')
  end
end

RSpec.configure do |config|
  config.include Fixture
end
