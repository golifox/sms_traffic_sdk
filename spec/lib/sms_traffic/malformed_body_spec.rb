RSpec.describe 'malformed HTTP 200 bodies' do
  include_context 'with configured client'

  malformed_bodies = {
    'an HTML error page' => '<html><body>Bad Gateway<br></body></html>',
    'plain text'         => 'OK',
    'a truncated reply'  => '<reply><result>OK</result><code>0',
    'empty'              => ''
  }

  malformed_bodies.each do |name, body|
    context "when the body is #{name}" do
      let(:error_message) { "Malformed reply (#{body.bytesize} bytes)" }

      before { stub_request(:post, uri).to_return(status: 200, body:) }

      it 'raises MalformedReplyError with the body from Client.deliver' do
        expect { SmsTraffic::Client.deliver('79991112233', 'message') }
          .to raise_error(SmsTraffic::MalformedReplyError, error_message) { |error| expect(error.body).to eq(body) }
      end

      it 'returns false from Sms#deliver with the error message' do
        sms = SmsTraffic::Sms.new('79991112233', 'message')

        expect(sms.deliver).to be(false)
        expect(sms.errors).to eq([error_message])
      end

      it 'raises MalformedReplyError from Client.status' do
        expect { SmsTraffic::Client.status('1') }.to raise_error(SmsTraffic::MalformedReplyError)
      end

      it 'keeps the status from Sms#update_status' do
        sms = SmsTraffic::Sms.new('79991112233', 'message')
        sms.instance_variable_set(:@id, '1')

        expect(sms.update_status).to eq('not-sent')
        expect(sms.errors).to eq([error_message])
      end

      it 'raises MalformedReplyError from Client.balance' do
        expect { SmsTraffic::Client.balance }.to raise_error(SmsTraffic::MalformedReplyError)
      end
    end
  end

  context 'when a 2xx response has no body' do
    before { stub_request(:post, uri).to_return(status: 204) }

    it 'raises MalformedReplyError from Client.status' do
      expect { SmsTraffic::Client.status('1') }
        .to raise_error(SmsTraffic::MalformedReplyError, 'Malformed reply (0 bytes)')
    end

    it 'returns false from Sms#deliver with the error message' do
      sms = SmsTraffic::Sms.new('79991112233', 'message')

      expect(sms.deliver).to be(false)
      expect(sms.errors).to eq(['Malformed reply (0 bytes)'])
    end
  end
end
