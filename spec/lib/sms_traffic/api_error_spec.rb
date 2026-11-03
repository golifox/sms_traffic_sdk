RSpec.describe SmsTraffic::ApiError do
  {
    retryable?:          %w[1000],
    access_denied?:      %w[411 412],
    insufficient_funds?: %w[415],
    blocked_phone?:      %w[432]
  }.each do |predicate, codes|
    describe "##{predicate}" do
      codes.each do |code|
        it("is true for #{code}") { expect(described_class.new(code, 'x').public_send(predicate)).to be(true) }
      end

      it 'is true for an integer code' do
        expect(described_class.new(codes.first.to_i, 'x').public_send(predicate)).to be(true)
      end

      it 'is false for another code' do
        expect(described_class.new('401', 'x').public_send(predicate)).to be(false)
      end
    end
  end

  it 'keeps the code as given' do
    expect(described_class.new('1000', 'x').code).to eq('1000')
  end

  it 'answers false to every predicate without a code' do
    error = described_class.new(nil, 'x')

    expect([error.retryable?, error.access_denied?, error.insufficient_funds?, error.blocked_phone?]).to all(be(false))
  end
end
