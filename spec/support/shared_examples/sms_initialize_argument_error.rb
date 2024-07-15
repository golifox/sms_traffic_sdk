RSpec.shared_examples 'raises ArgumentError' do |expected_error|
  it 'raises ArgumentError' do
    will_be_expected.to raise_error(ArgumentError, expected_error)
  end
end
