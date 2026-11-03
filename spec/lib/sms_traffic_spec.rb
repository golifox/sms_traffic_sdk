RSpec.describe SmsTraffic do
  describe '.configure' do
    context 'when validations passed' do
      it 'can be configured' do
        described_class.configure do |config|
          config.login          = 'username'
          config.password       = 'password'
          config.host           = 'http://example.com'
          config.originator     = 'q'
          config.validate_phone = false
        end

        expect(described_class.configuration).to have_attributes(
          login: 'username', password: 'password', host: 'http://example.com', originator: 'q', validate_phone: false
        )
      end

      it 'does not require a default originator' do
        expect do
          described_class.configure do |config|
            config.login    = 'usr'
            config.password = 'pass'
            config.host     = 'http://example.com'
          end
        end.not_to raise_error
      end
    end

    context 'when validations failed' do
      let(:valid) { { login: 'usr', password: 'pass', host: 'http://example.com' } }

      {
        'login'        => { login: nil },
        'password'     => { password: nil },
        'host'         => { host: nil },
        'debug logger' => { debug: true }
      }.each do |scenario, override|
        it "raises error when #{scenario} not specified" do
          expect do
            described_class.configure do |config|
              valid.merge(override).each { |key, value| config.public_send("#{key}=", value) }
            end
          end.to raise_error(ArgumentError)
        end
      end
    end
  end

  describe '.configuration' do
    subject(:configuration) { described_class.configuration }

    it { is_expected.to be_a(SmsTraffic::Configuration) }
    it { is_expected.to equal(described_class.configuration) }

    it 'is not a singleton' do
      expect(SmsTraffic::Configuration.new).not_to equal(configuration)
    end

    it 'restores defaults on reset!' do
      configuration.login = 'changed'
      configuration.read_timeout = 99
      configuration.reset!

      expect(configuration).to have_attributes(
        login: nil, password: nil, host: nil, originator: nil, debug: false, logger: nil,
        open_timeout: 10, read_timeout: 30, validate_phone: true
      )
      expect(configuration.xml_parser).to be_a(Nori)
    end

    it 'lists every attribute in to_h' do
      expect(configuration.to_h.keys).to contain_exactly(
        :login, :password, :host, :fallback_host, :originator, :debug, :logger,
        :open_timeout, :read_timeout, :validate_phone, :xml_parser
      )
    end
  end

  describe 'loading' do
    it 'is loadable through the gem name' do
      expect(system(RbConfig.ruby, '-I', File.expand_path('../../lib', __dir__), '-e',
                    "require 'sms_traffic_sdk'; exit(defined?(SmsTraffic::Sms) ? 0 : 1)")).to be(true)
    end
  end
end
