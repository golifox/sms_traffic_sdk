require 'uri'

RSpec.describe SmsTraffic::Client, 'deliver single sms' do
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

  subject(:deliver) { described_class.deliver(phones, message, originator) }
  subject(:reply) { deliver.reply }

  let(:first_phone) { '79051112233' }
  let(:second_phone) { '79051112233' }
  let(:third_phone) { '79261112233' }
  let(:message) { 'message' }

  context 'when sms not sent' do
    let(:phones) { first_phone }
    let(:body) { fixture('failure.xml') }

    before do
      stub_request(:post, uri)
        .with(body: hash_including(login: login, password: password, phones: phones,
                                   message: message), headers: headers)
        .and_return(body: body, status: 401)
    end

    it { expect(deliver).to be_failure }
    it { expect(deliver.error_description).not_to be_nil }
    it { expect(reply).to be_nil }
  end

  context 'when single sms sent' do
    let(:body) { fixture('deliver/success_single.xml') }
    let(:phones) { first_phone }
    let(:expected_sms_id) { '1000472891' }
    before do
      stub_request(:post, uri)
        .with(body: hash_including(login: login, password: password, phones: phones,
                                   message: message), headers: headers)
        .and_return(body: body, status: 200)
    end

    it { expect(deliver).to be_success }
    it { expect(deliver.error_description).to be_nil }
    it { expect(reply).to be_a(SmsTraffic::Client::DeliverReply) }
    it { expect(reply).to be_ok }
    it { expect(reply).not_to be_error }
    it { expect(reply.result).to eq('OK') }
    it { expect(reply.code).to eq('0') }
    it { expect(reply.description).to include('queued').and(include('1 message')) }
    it { expect(reply.sms_id).to eq(expected_sms_id) }
    it { expect(reply.sms_ids).to include(expected_sms_id) }
    it { expect(reply.error_description).to be_nil }
  end

  context 'when multiple sms sent' do
    let(:phones) { [first_phone, second_phone].join(',') }
    let(:body) { fixture('deliver/success_multiple.xml') }

    before do
      stub_request(:post, uri)
        .with(body: hash_including(login: login, password: password, phones: phones,
                                   message: message), headers: headers)
        .and_return(body: body, status: 200)
    end

    it { expect(deliver).to be_success }
    it { expect(deliver.error_description).to be_nil }
    it { expect(reply).to be_a(SmsTraffic::Client::DeliverReply) }
    it { expect(reply).to be_ok }
    it { expect(reply.result).to eq('OK') }
    it { expect(reply.code).to eq('0') }
    it { expect(reply.description).to include('queued').and(include('3 messages')) }
    it { expect(reply.sms_id(first_phone)).to eq('8287366071') }
    it { expect(reply.sms_ids).to be_a(Hash) }
    it {
      expect(reply.sms_ids).to eq(first_phone => '8287366071', second_phone => '8287366073',
                                  third_phone => '8287366075')
    }
    it { expect(reply.error_description).to be_nil }
  end

  context 'when sms has not been enqueued' do
    let(:body) { fixture('deliver/failure_single.xml') }
    let(:phones) { first_phone }
    before do
      stub_request(:post, uri)
        .with(body: hash_including(login: login, password: password, phones: phones,
                                   message: message), headers: headers)
        .and_return(body: body, status: 200)
    end

    it { expect(deliver).to be_success }
    it { expect(deliver.error_description).to be_nil }
    it { expect(reply.sms_id).to be_nil }
  end

  context 'when single sms was send and external api respond with multiply success buffered sms ids' do
    let(:phones) { first_phone }
    let(:body) { fixture('deliver/success_buffer_multiple.xml') }
    let(:expected_sms_id) { '8287366071' }

    before do
      stub_request(:post, uri)
        .with(body: hash_including(login: login, password: password, phones: phones,
                                   message: message), headers: headers)
        .and_return(body: body, status: 200)
    end

    it { expect(deliver).to be_success }
    it { expect(deliver.error_description).to be_nil }
    it { expect(reply).to be_a(SmsTraffic::Client::DeliverReply) }
    it { expect(reply).to be_ok }
    it { expect(reply).not_to be_error }
    it { expect(reply.result).to eq('OK') }
    it { expect(reply.code).to eq('0') }
    it { expect(reply.description).to include('queued').and(include('3 messages')) }
    it { expect(reply.sms_id).to eq(expected_sms_id) } # return first sms_id from array
    it { expect(reply.sms_id(first_phone)).to eq(expected_sms_id) }
    it { expect(reply.error_description).to be_nil }
  end

  context 'when single sms not queued' do
    let(:phones) { first_phone }
    let(:body) { fixture('deliver/success_not_queued.xml') }

    before do
      stub_request(:post, uri)
        .with(body: hash_including(login: login, password: password, phones: phones,
                                   message: message), headers: headers)
        .and_return(body: body, status: 200)
    end

    it { expect(deliver).to be_success }
    it { expect(deliver.error_description).to be_nil }
    it { expect(reply).to be_a(SmsTraffic::Client::DeliverReply) }
    it { expect(reply).not_to be_ok }
    it { expect(reply).to be_error }
    it { expect(reply.result).to eq('OK') }
    it { expect(reply.code).to eq('0') }
    it { expect(reply.description).to include('queued').and(include('0 messages')) }
    it { expect(reply.error_description).to include('queued 0 messages') }
  end
end
