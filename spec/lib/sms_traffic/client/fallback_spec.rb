require 'logger'
require 'stringio'

RSpec.describe SmsTraffic::Client, 'fallback host' do
  include_context 'with configured client'

  let(:fallback_host) { 'https://backup.example.com' }
  let(:fallback_uri) { URI.join(fallback_host, 'multi.php') }
  let(:phone) { '79991112233' }
  let(:ok_deliver) { fixture('deliver/success_single.xml') }
  let(:temporary_error) { '<reply><result>ERROR</result><code>1000</code><description>try later</description></reply>' }

  before { SmsTraffic.configuration.fallback_host = fallback_host }

  it 'defaults to nil' do
    SmsTraffic.configuration.reset!

    expect(SmsTraffic.configuration.fallback_host).to be_nil
  end

  describe '.deliver' do
    [SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH, Net::OpenTimeout].each do |error|
      it "repeats once on the fallback host after #{error}" do
        stub_request(:post, uri).to_raise(error)
        backup = stub_request(:post, fallback_uri).to_return(body: ok_deliver)

        expect(described_class.deliver(phone, 'text')).to be_ok
        expect(backup).to have_been_requested.once
      end
    end

    it 'repeats once after API error 1000' do
      stub_request(:post, uri).to_return(body: temporary_error)
      stub_request(:post, fallback_uri).to_return(body: ok_deliver)

      expect(described_class.deliver(phone, 'text')).to be_ok
    end

    it 'does not use the fallback after a read timeout' do
      stub_request(:post, uri).to_raise(Net::ReadTimeout)
      backup = stub_request(:post, fallback_uri).to_return(body: ok_deliver)

      expect { described_class.deliver(phone, 'text') }.to raise_error(SmsTraffic::ConnectionError)
      expect(backup).not_to have_been_requested
    end

    it 'does not use the fallback after a reset connection' do
      stub_request(:post, uri).to_raise(Errno::ECONNRESET)
      backup = stub_request(:post, fallback_uri).to_return(body: ok_deliver)

      expect { described_class.deliver(phone, 'text') }.to raise_error(SmsTraffic::ConnectionError)
      expect(backup).not_to have_been_requested
    end

    it 'does not use the fallback after HTTP 5xx' do
      stub_request(:post, uri).to_return(status: 503, body: 'down')
      backup = stub_request(:post, fallback_uri).to_return(body: ok_deliver)

      expect { described_class.deliver(phone, 'text') }.to raise_error(SmsTraffic::HttpError)
      expect(backup).not_to have_been_requested
    end

    it 'does not use the fallback after another API error' do
      stub_request(:post, uri).to_return(body: fixture('failure.xml'))
      backup = stub_request(:post, fallback_uri).to_return(body: ok_deliver)

      expect { described_class.deliver(phone, 'text') }.to raise_error(SmsTraffic::ApiError)
      expect(backup).not_to have_been_requested
    end

    it 'raises the error of the last attempt' do
      stub_request(:post, uri).to_raise(SocketError)
      stub_request(:post, fallback_uri).to_return(body: temporary_error)

      expect { described_class.deliver(phone, 'text') }
        .to raise_error(SmsTraffic::ApiError) { |error| expect(error.code).to eq('1000') }
    end

    it 'tries only once on the fallback host' do
      stub_request(:post, uri).to_raise(SocketError)
      backup = stub_request(:post, fallback_uri).to_raise(SocketError)

      expect { described_class.deliver(phone, 'text') }.to raise_error(SmsTraffic::ConnectionError)
      expect(backup).to have_been_requested.once
    end
  end

  describe 'read-only requests' do
    before { stub_request(:post, fallback_uri).to_return(body: fixture('status/success_single.xml')) }

    it 'retries status after a read timeout' do
      stub_request(:post, uri).to_raise(Net::ReadTimeout)

      expect(described_class.status('8287713301').status).to eq('Delivered')
    end

    it 'retries status after a reset connection' do
      stub_request(:post, uri).to_raise(Errno::ECONNRESET)

      expect(described_class.status('8287713301').status).to eq('Delivered')
    end

    it 'retries status after HTTP 5xx' do
      stub_request(:post, uri).to_return(status: 502, body: 'bad gateway')

      expect(described_class.status('8287713301').status).to eq('Delivered')
    end

    it 'retries status after API error 1000' do
      stub_request(:post, uri).to_return(body: temporary_error)

      expect(described_class.status('8287713301').status).to eq('Delivered')
    end

    it 'does not retry status after HTTP 4xx' do
      stub_request(:post, uri).to_return(status: 401, body: 'no')

      expect { described_class.status('8287713301') }.to raise_error(SmsTraffic::HttpError)
    end

    it 'retries balance after HTTP 5xx' do
      stub_request(:post, uri).to_return(status: 500, body: 'oops')
      stub_request(:post, fallback_uri).to_return(body: fixture('account/success.xml'))

      expect(described_class.balance.balance).to eq(BigDecimal('10025'))
    end

    it 'retries balance after a read timeout' do
      stub_request(:post, uri).to_raise(Net::ReadTimeout)
      stub_request(:post, fallback_uri).to_return(body: fixture('account/success.xml'))

      expect(described_class.balance.balance).to eq(BigDecimal('10025'))
    end
  end

  context 'without a fallback host' do
    before { SmsTraffic.configuration.fallback_host = nil }

    it 'raises the first error for deliver' do
      stub_request(:post, uri).to_raise(SocketError)

      expect { described_class.deliver(phone, 'text') }.to raise_error(SmsTraffic::ConnectionError)
    end

    it 'raises code 1000 as ApiError' do
      stub_request(:post, uri).to_return(body: temporary_error)

      expect { described_class.status('1') }.to raise_error(SmsTraffic::ApiError)
    end
  end

  describe 'debug logging' do
    let(:output) { StringIO.new }

    before do
      SmsTraffic.configuration.debug = true
      SmsTraffic.configuration.logger = Logger.new(output)
      stub_request(:post, uri).to_raise(SocketError)
      stub_request(:post, fallback_uri).to_return(body: ok_deliver)
    end

    it 'logs the retry in one line without credentials' do
      described_class.deliver(phone, 'top secret text')

      retry_lines = output.string.lines.grep(/retry/i)
      expect(retry_lines.size).to eq(1)
      expect(retry_lines.first).to include(fallback_host)
      [login, password, 'top secret text'].each { |secret| expect(output.string).not_to include(secret) }
    end
  end

  describe 'Sms' do
    it 'delivers through the fallback host' do
      stub_request(:post, uri).to_raise(Errno::ECONNREFUSED)
      stub_request(:post, fallback_uri).to_return(body: ok_deliver)

      expect(SmsTraffic::Sms.new(phone, 'text').deliver).to be(true)
    end
  end
end
