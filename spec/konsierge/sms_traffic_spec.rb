RSpec.describe SmsTraffic do
  describe '.configure' do
    context 'when validations passed' do
      let(:attributes) { { login: 'username', password: 'password', host: 'http://example.com', originator: 'q' } }

      it 'can be configured' do
        described_class.configure do |config|
          config.login = attributes[:login]
          config.password = attributes[:password]
          config.host = attributes[:host]
          config.originator = attributes[:originator]
        end

        expect(described_class.configuration).to have_attributes(attributes)
      end
    end

    context 'when validations failed' do
      invalid_attributes = [
        [{ login: nil, password: 'pass', host: 'http://example.com', originator: 'q', debug: true },
         'login not specified'],
        [{ login: 'usr', password: nil, host: 'http://example.com', originator: 'q', debug: true },
         'password not specified'],
        [{ login: 'usr', password: 'pass', host: nil, debug: true, originator: 'q' }, 'host not specified'],
        [{ login: 'usr', password: 'pass', host: 'http://example.com', originator: nil, debug: true },
         'originator not specified'],
        [{ login: 'usr', password: 'pass', host: 'http://example.com', debug: true }, 'debug logger not specified']
      ]

      invalid_attributes.each do |attributes, scenario|
        it "raises error when #{scenario}" do
          expect do
            described_class.configure do |config|
              config.login = attributes[:login]
              config.password = attributes[:password]
              config.host = attributes[:host]
              config.debug = attributes[:debug]
              config.logger = attributes[:logger]
            end
          end.to raise_error(ArgumentError)
        end
      end
    end
  end

  describe '.configuration' do
    subject { described_class.configuration }

    it 'returns configuration' do
      is_expected.to be_a(SmsTraffic::Configuration)
    end

    it 'returns the same instance' do
      is_expected.to eq(described_class.configuration)
    end

    it 'returns sets default fields' do
      subject.reset!

      is_expected.to have_attributes(subject.send(:default_configuration))
    end
  end
end
