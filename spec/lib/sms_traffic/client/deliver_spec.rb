RSpec.describe SmsTraffic::Client, 'deliver' do
  include_context 'with configured client'

  subject(:reply) { described_class.deliver(phones, message, originator) }

  let(:first_phone) { '79051112233' }
  let(:second_phone) { '79261112233' }
  let(:message) { 'message' }
  let(:phones) { first_phone }
  let(:headers) { { 'Content-Type' => 'application/x-www-form-urlencoded' } }

  def stub_deliver(body, status: 200)
    stub_request(:post, uri)
      .with(body: hash_including(login:, password:, phones:, message:), headers:)
      .to_return(body:, status:)
  end

  context 'when single sms sent' do
    before { stub_deliver(fixture('deliver/success_single.xml')) }

    it { is_expected.to be_a(SmsTraffic::Client::DeliverReply) }
    it { is_expected.to be_ok }
    it { is_expected.not_to be_error }
    it { expect(reply.result).to eq('OK') }
    it { expect(reply.code).to eq('0') }
    it { expect(reply.description).to include('queued').and(include('1 message')) }
    it { expect(reply.messages).to eq([{ phone: nil, sms_id: '1000472891', push_id: nil }]) }
    it { expect(reply.sms_id).to eq('1000472891') }
    it { expect(reply.sms_ids).to eq(['1000472891']) }
    it { expect(reply.error_description).to be_nil }
    it { expect(reply.ok?).to be(true) }
  end

  context 'when single message_info includes a phone' do
    before { stub_deliver(fixture('deliver/success_single_with_phone.xml')) }

    it { expect(reply.messages).to eq([{ phone: first_phone, sms_id: '1000472891', push_id: nil }]) }
    it { expect(reply.sms_id(first_phone)).to eq('1000472891') }
    it { expect(reply.sms_id('79990000000')).to be_nil }
  end

  context 'when multiple sms sent' do
    let(:phones) { [first_phone, second_phone].join(',') }

    before { stub_deliver(fixture('deliver/success_multiple.xml')) }

    it { is_expected.to be_ok }
    it { expect(reply.description).to include('3 messages') }

    it 'normalizes messages in reply order' do
      expect(reply.messages).to eq(
        [{ phone: first_phone, sms_id: '8287366071', push_id: 'a' },
         { phone: first_phone, sms_id: '8287366073', push_id: 'a' },
         { phone: second_phone, sms_id: '8287366075', push_id: 'b' }]
      )
    end

    it { expect(reply.sms_ids).to eq(%w[8287366071 8287366073 8287366075]) }
    it { expect(reply.sms_id).to eq('8287366071') }
    it { expect(reply.sms_id(second_phone)).to eq('8287366075') }
    it { expect(reply.sms_id(first_phone)).to eq('8287366071') }
  end

  context 'when one phone receives a multi-part sms' do
    before { stub_deliver(fixture('deliver/success_buffer_multiple.xml')) }

    it { is_expected.to be_ok }
    it { expect(reply.sms_ids).to eq(%w[8287366071 8287366072 8287366073]) }
    it { expect(reply.sms_id).to eq('8287366071') }
  end

  context 'when sms has not been enqueued' do
    before { stub_deliver(fixture('deliver/failure_single.xml')) }

    it { is_expected.not_to be_ok }
    it { expect(reply.ok?).to be(false) }
    it { expect(reply.messages).to eq([]) }
    it { expect(reply.sms_id).to be_nil }
    it { expect(reply.sms_ids).to eq([]) }
    it { expect(reply.error_description).to eq('Sms has not been enqueued: queued 0 message') }
  end

  context 'when sms is not queued' do
    before { stub_deliver(fixture('deliver/success_not_queued.xml')) }

    it { is_expected.not_to be_ok }
    it { is_expected.to be_error }
    it { expect(reply.error_description).to include('queued 0 messages') }
  end

  context 'when the reply result is ERROR' do
    before { stub_deliver(fixture('failure.xml')) }

    it 'raises ApiError with code and description' do
      expect { reply }.to raise_error(SmsTraffic::ApiError) { |error|
        expect(error).to have_attributes(code: '401', description: 'login param is missing')
      }
    end
  end

  context 'when originator is omitted' do
    subject(:reply) { described_class.deliver(phones, message) }

    before do
      stub_request(:post, uri).with(body: hash_including(originator: 'originator'))
                              .to_return(body: fixture('deliver/success_single.xml'))
    end

    it { is_expected.to be_ok }
  end
end
