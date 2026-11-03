RSpec.shared_context 'with configured client' do
  let(:host) { 'https://example.com' }
  let(:login) { 'api-user-42' }
  let(:password) { 'secret-password' }
  let(:originator) { 'originator' }
  let(:uri) { URI.join(host, 'multi.php') }

  before do
    SmsTraffic.configure do |config|
      config.login = login
      config.password = password
      config.host = host
      config.originator = originator
    end
  end
end
