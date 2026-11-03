RSpec.describe SmsTraffic::Sms do
  subject(:sms) { described_class.new(phone, message, originator:) }

  include_context 'with configured client'

  let(:phone) { '79991112233' }
  let(:message) { 'message' }

  describe '.new' do
    describe 'phone validation' do
      context 'when phone validation is enabled' do
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

        context 'when phone hides garbage after a newline' do
          let(:phone) { "79991112233\nabc" }

          it_behaves_like 'raises ArgumentError', 'Phone number should contain only numbers. Minimum length is 11.'
        end
      end

      context 'when phone validation is disabled' do
        before { SmsTraffic.configuration.validate_phone = false }

        context 'when phone is nil' do
          let(:phone) { nil }

          it_behaves_like 'raises ArgumentError', "Phone should be assigned to #{described_class}."
        end

        context 'when phone is not 11 digits' do
          let(:phone) { '7999111223' }

          it { will_be_expected.to_not raise_error }
        end

        context 'when phone is not a number' do
          let(:phone) { '7999111223a' }

          it { will_be_expected.to_not raise_error }
        end
      end
    end

    context 'when message is nil' do
      let(:message) { nil }

      it_behaves_like 'raises ArgumentError', "Message should be specified to #{described_class}."
    end

    context 'when originator is nil and default originator specified' do
      subject(:sms) { described_class.new(phone, message) }

      it { expect(sms.originator).to eq('originator') }
    end

    context 'when originator is nil and default originator not specified' do
      subject(:sms) { described_class.new(phone, message) }

      before { SmsTraffic.configuration.originator = nil }

      it_behaves_like 'raises ArgumentError', "Originator should be specified to #{described_class}."
    end

    context 'when params are valid' do
      it { is_expected.to be_a(described_class) }
      it { expect(sms.phone).to eq(phone) }
      it { expect(sms.message).to eq(message) }
      it { expect(sms.originator).to eq(originator) }
      it { expect(sms.status).to eq('not-sent') }
      it { expect(sms.errors).to eq([]) }
      it { expect(sms.reply).to be_nil }
    end
  end

  describe '#deliver' do
    subject(:deliver) { sms.deliver }

    def stub_api(body, status: 200)
      stub_request(:post, uri)
        .with(body: hash_including(login:, password:, phones: phone, message:,
                                   originator:))
        .to_return(body:, status:)
    end

    context 'when the provider enqueues the sms' do
      before { stub_api(fixture('deliver/success_single.xml')) }

      it { is_expected.to be(true) }

      it 'marks the sms as sent and keeps the reply' do
        deliver

        expect(sms).to have_attributes(status: 'sent', id: '1000472891', errors: [])
        expect(sms.reply).to be_a(SmsTraffic::Client::DeliverReply)
      end
    end

    context 'when the provider splits the sms into parts' do
      before { stub_api(fixture('deliver/success_buffer_multiple.xml')) }

      it 'takes the first sms id' do
        deliver

        expect(sms.id).to eq('8287366071')
        expect(sms.reply.sms_ids.size).to eq(3)
      end
    end

    context 'when the provider enqueues nothing' do
      before { stub_api(fixture('deliver/failure_single.xml')) }

      it { is_expected.to be(false) }

      it 'records the provider description and keeps the status' do
        deliver

        expect(sms).to have_attributes(status: 'not-sent', id: nil,
                                       errors: ['Sms has not been enqueued: queued 0 message'])
        expect(sms.reply).not_to be_ok
      end
    end

    context 'when the provider answers with an API error' do
      before { stub_api(fixture('failure.xml')) }

      it { is_expected.to be(false) }

      it 'records the error' do
        deliver

        expect(sms.errors.first).to include('401').and(include('login param is missing'))
        expect(sms.status).to eq('not-sent')
      end
    end

    context 'when the provider answers with an HTTP error' do
      before { stub_api('oops', status: 500) }

      it 'records the error' do
        expect(deliver).to be(false)
        expect(sms.errors.first).to include('500')
      end
    end

    context 'when the connection fails' do
      before { stub_request(:post, uri).to_timeout }

      it 'records the error' do
        expect(deliver).to be(false)
        expect(sms.errors.size).to eq(1)
        expect(sms.status).to eq('not-sent')
      end
    end
  end

  describe '#update_status' do
    subject(:update_status) { sms.update_status }

    def stub_status(body, status: 200)
      stub_request(:post, uri)
        .with(body: hash_including(operation: 'status', sms_id: '8287713301'))
        .to_return(body:, status:)
    end

    context 'when the sms was not delivered yet' do
      it 'returns the status without a request' do
        expect(update_status).to eq('not-sent')
        expect(a_request(:post, uri)).not_to have_been_made
      end
    end

    context 'when the sms has an id' do
      before do
        stub_request(:post, uri).with(body: hash_including(phones: phone)).to_return(
          body: fixture('deliver/success_single.xml').sub('1000472891', '8287713301')
        )
        sms.deliver
      end

      it 'sets the downcased provider status' do
        stub_status(fixture('status/success_single.xml'))

        expect(update_status).to eq('delivered')
        expect(sms.status).to eq('delivered')
      end

      it 'records a not found entry and keeps the status' do
        stub_status(fixture('status/failure_single.xml'))

        expect(update_status).to eq('sent')
        expect(sms.errors).to eq(['no such message or this message does not belong to you'])
      end

      it 'records an HTTP error and keeps the status' do
        stub_status('oops', status: 502)

        expect(update_status).to eq('sent')
        expect(sms.errors.first).to include('502')
      end

      it 'records a connection error and keeps the status' do
        stub_request(:post, uri).with(body: hash_including(operation: 'status')).to_timeout

        expect(update_status).to eq('sent')
        expect(sms.errors.size).to eq(1)
      end
    end
  end
end
