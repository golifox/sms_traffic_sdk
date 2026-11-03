require 'logger'
require 'stringio'

RSpec.describe SmsTraffic::Client, 'errors and transport' do
  include_context 'with configured client'

  let(:phone) { '79051112233' }
  let(:message) { 'top secret text' }

  describe 'ConnectionError' do
    {
      'socket error' => SocketError,
      'refused'      => Errno::ECONNREFUSED,
      'io error'     => IOError,
      'open timeout' => Net::OpenTimeout,
      'read timeout' => Net::ReadTimeout,
      'ssl error'    => OpenSSL::SSL::SSLError
    }.each do |name, error_class|
      it "wraps #{name} and keeps the cause" do
        stub_request(:post, uri).to_raise(error_class)

        expect { described_class.deliver(phone, message) }.to raise_error(SmsTraffic::ConnectionError) { |error|
          expect(error.cause).to be_a(error_class)
        }
      end
    end

    it 'is wrapped for status requests too' do
      stub_request(:post, uri).to_timeout

      expect { described_class.status('1') }.to raise_error(SmsTraffic::ConnectionError)
    end
  end

  describe 'HttpError' do
    it 'exposes status and body for non-2xx replies' do
      stub_request(:post, uri).to_return(status: 503, body: 'down')

      expect { described_class.deliver(phone, message) }.to raise_error(SmsTraffic::HttpError) { |error|
        expect(error).to have_attributes(status: 503, body: 'down')
      }
    end

    it 'is raised for status requests too' do
      stub_request(:post, uri).to_return(status: 401, body: fixture('failure.xml'))

      expect { described_class.status('1') }.to raise_error(SmsTraffic::HttpError) { |error|
        expect(error.status).to eq(401)
      }
    end
  end

  describe 'error hierarchy' do
    it 'roots every error in SmsTraffic::Error' do
      expect([SmsTraffic::ConnectionError, SmsTraffic::HttpError, SmsTraffic::ApiError])
        .to all(be < SmsTraffic::Error)
      expect(SmsTraffic::Error).to be < StandardError
    end
  end

  describe 'request building' do
    it 'uses the current host on every request' do
      first = stub_request(:post, 'https://example.com/multi.php')
              .to_return(body: fixture('deliver/success_single.xml'))
      second = stub_request(:post, 'https://other.example.org/multi.php')
               .to_return(body: fixture('deliver/success_single.xml'))

      described_class.deliver(phone, message)
      SmsTraffic.configuration.host = 'https://other.example.org'
      described_class.deliver(phone, message)

      expect(first).to have_been_requested.once
      expect(second).to have_been_requested.once
    end

    it 'applies configured timeouts' do
      SmsTraffic.configuration.open_timeout = 3
      SmsTraffic.configuration.read_timeout = 7
      stub_request(:post, uri).to_return(body: fixture('deliver/success_single.xml'))
      http = nil
      allow(Net::HTTP).to receive(:start).and_wrap_original do |original, *args, **kwargs, &block|
        original.call(*args, **kwargs) do |connection|
          http = connection
          block.call(connection)
        end
      end

      described_class.deliver(phone, message)

      expect(http).to have_attributes(open_timeout: 3, read_timeout: 7)
    end

    it 'passes a flat sms_id list to status' do
      stub = stub_request(:post, uri).with(body: hash_including(sms_id: '1,2'))
                                     .to_return(body: fixture('status/success_multiple.xml'))

      described_class.status('1', '2')

      expect(stub).to have_been_requested
    end
  end

  describe 'debug logging' do
    let(:output) { StringIO.new }

    before do
      SmsTraffic.configuration.debug = true
      SmsTraffic.configuration.logger = Logger.new(output)
      stub_request(:post, uri).to_return(body: fixture('deliver/success_single.xml'))
    end

    it 'logs one request and one response line without secrets' do
      described_class.deliver(phone, message)

      lines = output.string.lines
      expect(lines.grep(/request/i).size).to eq(1)
      expect(lines.grep(/response/i).size).to eq(1)
      expect(output.string).to include('[FILTERED]')
      expect(output.string).not_to include(password)
      expect(output.string).not_to include(message)
      expect(output.string).not_to include(login)
    end

    it 'filters phones and extra options but keeps the allowlisted params' do
      described_class.deliver(phone, message, 'brand', 'individual_messages' => "#{phone}:x", start_date: 'later-today')

      request_line = output.string.lines.grep(/request/i).first
      expect(request_line).not_to include(phone)
      expect(request_line).not_to include('later-today')
      expect(request_line).to include('originator', 'brand', 'want_sms_ids', 'rus')
    end

    it 'keeps sms ids in a status request line' do
      stub_request(:post, uri).to_return(body: fixture('status/success_single.xml'))

      described_class.status('987654321')

      expect(output.string.lines.grep(/request/i).first).to include('987654321', 'status')
    end

    it 'does not log the response body' do
      body = "<reply><result>ERROR</result><description>#{login} #{password} #{message}</description></reply>"
      stub_request(:post, uri).to_return(body:)

      expect { described_class.deliver(phone, message) }.to raise_error(SmsTraffic::ApiError)
      expect(output.string).to match(/response 200 \(\d+ bytes\)/)
      [login, password, message].each { |secret| expect(output.string).not_to include(secret) }
    end

    it 'never enables Net::HTTP debug output' do
      expect_any_instance_of(Net::HTTP).not_to receive(:set_debug_output)
      described_class.deliver(phone, message)
    end

    it 'logs nothing when debug is off' do
      SmsTraffic.configuration.debug = false

      described_class.deliver(phone, message)

      expect(output.string).to be_empty
    end
  end
end
