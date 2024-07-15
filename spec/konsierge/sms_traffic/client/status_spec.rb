RSpec.describe SmsTraffic::Client, 'status' do
  let(:host) { 'https://example.com' }
  let(:login) { 'login' }
  let(:password) { 'password' }
  let(:originator) { 'originator' }
  let(:uri) { URI.join(host, 'multi.php') }
  let(:headers) { { 'Content-Type': 'application/x-www-form-urlencoded' } }

  before do
    SmsTraffic.configure do |config|
      config.login = login
      config.password = password
      config.host = host
      config.originator = originator
    end
  end

  subject(:status) { described_class.status(*sms_ids) }
  subject(:reply) { status.reply }

  let(:first_sms_id) { '8287713301' }
  let(:second_sms_id) { '8287713303' }
  let(:third_sms_id) { '82877133031' }

  context 'when single sms status respond with error' do
    let(:sms_ids) { [first_sms_id] }
    let(:xml_body) { fixture('status/failure_single.xml') }

    before do
      stub_request(:post, uri)
        .with(body: hash_including(login: login, password: password, operation: 'status', sms_id: first_sms_id))
        .to_return(body: xml_body, status: 200)
    end

    it { expect(status).to be_success }
    it { expect(reply.sms_array.size).to eq(1) }
    it { expect(reply.status).to be_nil }
    it { expect(reply.statuses).to be_empty }
    it { expect(reply.error).to be_nil }
  end

  context 'when multiple sms status respond with success and error' do
    let(:sms_ids) { [first_sms_id, second_sms_id, third_sms_id] }
    let(:xml_body) { fixture('status/success_and_failure_multiple.xml') }

    before do
      stub_request(:post, uri)
        .with(body: hash_including(login: login, password: password, operation: 'status', sms_id: sms_ids.join(',')))
        .to_return(body: xml_body, status: 200)
    end

    it { expect(status).to be_success }
    it { expect(reply.sms_array.size).to eq(3) }
    it { expect { reply.status }.to raise_error(ArgumentError) }
    it { expect(reply.status(first_sms_id)).to eq('Expired') }
    it {
      expect(reply.statuses).to eq(first_sms_id => 'Expired', second_sms_id => 'Delivered')
    }
    it { expect { reply.error }.to raise_error(ArgumentError) }
    it { expect(reply.error(third_sms_id)).to include('does not') }
    it { expect(reply.errors.keys).to contain_exactly(third_sms_id) }
  end

  context 'when multiple sms status respond with success' do
    let(:sms_ids) { [first_sms_id, second_sms_id] }
    let(:xml_body) { fixture('status/success_multiple.xml') }

    before do
      stub_request(:post, uri)
        .with(body: hash_including(login: login, password: password, operation: 'status', sms_id: sms_ids.join(',')))
        .to_return(body: xml_body, status: 200)
    end

    it { expect(status).to be_success }
    it { expect(reply.sms_array.size).to eq(2) }
    it { expect { reply.status }.to raise_error(ArgumentError) }
    it { expect(reply.status(first_sms_id)).to eq('Expired') }
    it { expect(reply.statuses).to include(first_sms_id => 'Expired', second_sms_id => 'Delivered') }
    it { expect { reply.error }.to raise_error(ArgumentError) }
    it { expect(reply.error(first_sms_id)).to be_nil }
    it { expect(reply.errors).to be_empty }
  end
end
