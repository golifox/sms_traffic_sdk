RSpec.describe 'malformed HTTP 200 bodies' do
  include_context 'with configured client'

  malformed_bodies = {
    'an HTML error page' => '<html><body>Bad Gateway<br></body></html>',
    'plain text'         => 'OK',
    'a truncated reply'  => '<reply><result>OK</result><code>0'
  }

  malformed_bodies.each do |name, body|
    context "when the body is #{name}" do
      before { stub_request(:post, uri).to_return(status: 200, body:) }

      it 'returns an empty reply from Client.deliver' do
        reply = SmsTraffic::Client.deliver('79991112233', 'message')

        expect(reply.to_h).to eq({})
        expect(reply).not_to be_ok
      end

      it 'returns false from Sms#deliver with a not-enqueued error' do
        sms = SmsTraffic::Sms.new('79991112233', 'message')

        expect(sms.deliver).to be(false)
        expect(sms.errors).to eq(['Sms has not been enqueued: '])
      end

      it 'returns an empty reply from Client.status' do
        reply = SmsTraffic::Client.status('1')

        expect(reply.to_h).to eq({})
        expect(reply.entries).to eq([])
      end

      it 'keeps the status from Sms#update_status' do
        sms = SmsTraffic::Sms.new('79991112233', 'message')
        sms.instance_variable_set(:@id, '1')

        expect(sms.update_status).to eq('not-sent')
        expect(sms.errors).to eq(['No status returned for sms 1'])
      end

      it 'returns an empty reply from Client.balance' do
        reply = SmsTraffic::Client.balance

        expect(reply.to_h).to eq({})
        expect(reply.balance).to be_nil
      end
    end
  end
end
