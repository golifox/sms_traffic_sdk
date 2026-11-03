RSpec.describe SmsTraffic::Client, 'balance' do
  include_context 'with configured client'

  subject(:reply) { described_class.balance }

  before do
    stub_request(:post, uri)
      .with(body: hash_including(login:, password:, operation: 'account'))
      .to_return(body: xml_body)
  end

  context 'with an integer account' do
    let(:xml_body) { fixture('account/success.xml') }

    it { is_expected.to be_a(SmsTraffic::Client::AccountReply) }
    it { expect(reply.balance).to eq(BigDecimal('10025')) }
    it { expect(reply.balance).to be_a(BigDecimal) }
  end

  context 'with a decimal account' do
    let(:xml_body) { fixture('account/success_decimal.xml') }

    it { expect(reply.balance).to eq(BigDecimal('10025.5')) }
  end

  context 'without an account element' do
    let(:xml_body) { '<reply></reply>' }

    it { expect(reply.balance).to be_nil }
  end

  context 'with a non-numeric account' do
    let(:xml_body) { '<reply><account>abc</account></reply>' }

    it { expect(reply.balance).to be_nil }
  end

  context 'when the provider replies with an error' do
    let(:xml_body) { fixture('failure_erro.xml') }

    it { expect { reply }.to raise_error(SmsTraffic::ApiError, /invalid login/) }
  end
end
