# Convenience helper for inline-expectation of blocks.
# Helpful when you want to check block for error.
#
# @example
#
#  subject { raise ArgumentError, 'why not?' }
#
#  it { will_be_expected.to raise_error }
#
module WillBeExpected
  def will_be_expected
    expect { subject }
  end
end

RSpec.configure do |config|
  config.include WillBeExpected
end
