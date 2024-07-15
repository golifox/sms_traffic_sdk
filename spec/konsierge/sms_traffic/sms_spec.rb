RSpec.describe SmsTraffic::Sms do
  subject(:sms) { described_class.new(phone, message, originator: originator) }

  let(:phone) { '79991112233' }
  let(:message) { 'message' }
  let(:originator) { 'originator' }

  describe '.new' do
    context 'when phone is nil' do
      let(:phone) { nil }

      it_behaves_like 'raises ArgumentError', "Phone should be assigned to #{described_class}."
    end

    context 'when phone is not 11 digits' do
      let(:phone) { '7999111223' }

      it_behaves_like 'raises ArgumentError', 'Phone number should contain only numbers. Minimum length is 11.'
    end

    context 'when phone is not a number' do
      let(:phone) { '7999111223a' }

      it_behaves_like 'raises ArgumentError', 'Phone number should contain only numbers. Minimum length is 11.'
    end

    context 'when message is nil' do
      let(:message) { nil }

      it_behaves_like 'raises ArgumentError', "Message should be specified to #{described_class}."
    end

    context 'when originator is nil and default originator specified' do
      before { allow(SmsTraffic.configuration).to receive(:originator).and_return('default_originator') }
      let(:originator) { nil }

      it { expect(subject.originator).to eq(SmsTraffic.configuration.originator) }
    end

    context 'when originator is nil and default originator not specified' do
      let(:originator) { nil }

      it_behaves_like 'raises ArgumentError', "Originator should be specified to #{described_class}."
    end

    context 'when params are valid' do
      it { is_expected.to be_a(described_class) }
      it { expect(subject.phone).to eq(phone) }
      it { expect(subject.message).to eq(message) }
      it { expect(subject.originator).to eq(originator) }
      it { expect(subject.status).to eq('not-sent') }
      it { expect(subject.errors).to eq([]) }
    end
  end

  describe '.deliver' do
    subject(:deliver) { sms.deliver }
    subject(:delivered) { sms }

    context 'when response is not success' do
      let(:response) do
        instance_double(SmsTraffic::Client::Response, success?: false, error_description: 'error')
      end

      before do
        allow(SmsTraffic::Client).to receive(:deliver).and_return(response)
        deliver
      end

      it { expect(deliver).to be_falsey }
      it { expect(delivered.errors).to include(response.error_description) }
    end

    context 'when sms traffic respond with error' do
      let(:response) { instance_double(SmsTraffic::Client::Response, success?: true, reply: reply) }
      let(:reply) do
        instance_double(SmsTraffic::Client::DeliverReply, ok?: false, error_description: 'error')
      end

      before do
        allow(SmsTraffic::Client).to receive(:deliver).and_return(response)
        deliver
      end

      it { expect(deliver).to be_falsey }
      it { expect(delivered.errors).to include(reply.error_description) }
    end

    context 'when sms traffic respond with success' do
      let(:response) { instance_double(SmsTraffic::Client::Response, success?: true, reply: reply) }
      let(:reply) { instance_double(SmsTraffic::Client::DeliverReply, ok?: true, sms_id: 1) }

      before do
        allow(SmsTraffic::Client).to receive(:deliver).and_return(response)
        deliver
      end

      it { expect(deliver).to be_truthy }
      it { expect(delivered.status).to eq('sent') }
      it { expect(delivered.id).to eq(reply.sms_id) }
    end
  end

  describe '.update_status' do
    subject(:update_status) { sms.update_status }
    subject(:updated) { sms }

    let(:sms_id) { 1 }

    context 'when id is nil' do
      it { expect(update_status).to eq('not-sent') }
    end

    context 'when sms traffic respond with error' do
      let(:response) do
        instance_double(SmsTraffic::Client::Response, success?: false, reply: nil, code: '401')
      end

      before do
        sms.instance_variable_set(:@id, sms_id)
        allow(SmsTraffic::Client).to receive(:status).with(sms_id).and_return(response)
        update_status
      end

      it { expect(update_status).to eq(response.code) }
      it { expect { update_status }.not_to(change { updated.status }) }
    end

    context 'when sms traffic respond with success' do
      let(:response) do
        instance_double(SmsTraffic::Client::Response, success?: true, reply: reply, code: '0')
      end
      let(:reply) do
        instance_double(SmsTraffic::Client::StatusReply, status: 'sent')
      end

      before do
        sms.instance_variable_set(:@id, sms_id)
        sms.instance_variable_set(:@status, 'not-sent')

        allow(SmsTraffic::Client).to receive(:status).with(sms_id).and_return(response)
      end

      it 'updates status' do
        update_status
        expect(updated.status).to eq(reply.status)
      end

      it { expect { update_status }.to(change { updated.status }.from('not-sent').to(reply.status)) }
    end
  end
end
