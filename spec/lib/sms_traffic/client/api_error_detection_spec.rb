RSpec.describe SmsTraffic::Client::Reply, 'api_error?' do
  it 'is true for ERROR' do
    expect(described_class.new(fixture('failure.xml'))).to be_api_error
  end

  it 'is true for the ERRO spelling the provider documents in its example' do
    expect(described_class.new(fixture('failure_erro.xml'))).to be_api_error
  end

  it 'is false for OK' do
    expect(described_class.new(fixture('deliver/success_single.xml'))).not_to be_api_error
  end

  it 'is false without a result (status and account replies)' do
    replies = [fixture('status/success_single.xml'), fixture('account/success.xml')]

    expect(replies.map { |xml| described_class.new(xml).api_error? }).to all(be(false))
  end
end

RSpec.describe SmsTraffic::Client, 'ERRO reply' do
  include_context 'with configured client'

  it 'raises ApiError from deliver' do
    stub_request(:post, uri).to_return(body: fixture('failure_erro.xml'))

    expect { described_class.deliver('79991112233', 'text') }
      .to raise_error(SmsTraffic::ApiError) { |error| expect(error).to have_attributes(code: '411') }
  end
end
