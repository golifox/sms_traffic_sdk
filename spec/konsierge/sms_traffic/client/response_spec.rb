RSpec.describe SmsTraffic::Client::Response do
  describe '.initialize' do
    subject(:response) { described_class.new(origin) }

    context 'when origin response is success' do
      let(:origin) { instance_double('Net::HTTPResponse', code: 200, body: 'body', message: 'message') }

      it { is_expected.to be_success }
    end

    context 'when origin response is failure' do
      let(:origin) { instance_double('Net::HTTPResponse', code: 400, body: 'body', message: 'message') }

      it { is_expected.to be_failure }
      it { expect(response.error_description).to include('400').and(include('message')) }
    end
  end
end
