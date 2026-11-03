RSpec.describe SmsTraffic::Client, 'status' do
  include_context 'with configured client'

  subject(:reply) { described_class.status(*sms_ids) }

  let(:first_sms_id) { '8287713301' }
  let(:second_sms_id) { '8287713303' }
  let(:third_sms_id) { '82877133031' }

  before do
    stub_request(:post, uri)
      .with(body: hash_including(login:, password:, operation: 'status', sms_id: sms_ids.join(',')))
      .to_return(body: xml_body, status: 200)
  end

  context 'when a single sms is requested in the top-level reply shape' do
    let(:sms_ids) { [first_sms_id] }
    let(:xml_body) { fixture('status/success_single.xml') }

    it { is_expected.to be_a(SmsTraffic::Client::StatusReply) }
    it { expect(reply.entries.size).to eq(1) }
    it { expect(reply.status).to eq('Delivered') }
    it { expect(reply.error).to be_nil }
    it { expect(reply.send_date).to eq('2020-05-09 14:11:39') }
    it { expect(reply).not_to be_error }
    it { expect(reply).not_to be_not_found }

    it 'builds a full entry' do
      expect(reply.entry).to have_attributes(
        sms_id: first_sms_id, status: 'Delivered', error: nil, submission_date: '2020-05-09 14:11:39',
        send_date: '2020-05-09 14:11:39', last_status_change_date: '2020-05-09 14:12:00'
      )
    end
  end

  context 'when the only sms is not found' do
    let(:sms_ids) { [first_sms_id] }
    let(:xml_body) { fixture('status/failure_single.xml') }

    it { expect(reply.entries.size).to eq(1) }
    it { expect(reply.status).to be_nil }
    it { expect(reply.error).to eq('no such message or this message does not belong to you') }
    it { expect(reply).to be_error }
    it { expect(reply).to be_not_found }
    it { expect(reply.statuses).to be_empty }
    it { expect(reply.errors).to eq(first_sms_id => reply.error) }
  end

  context 'when multiple sms respond with success and error' do
    let(:sms_ids) { [first_sms_id, second_sms_id, third_sms_id] }
    let(:xml_body) { fixture('status/success_and_failure_multiple.xml') }

    it { expect(reply.entries).to all(be_a(SmsTraffic::Client::StatusReply::Entry)) }
    it { expect(reply.entries.map(&:sms_id)).to eq(sms_ids) }
    it { expect { reply.status }.to raise_error(ArgumentError) }
    it { expect { reply.entry }.to raise_error(ArgumentError) }
    it { expect(reply.status(first_sms_id)).to eq('Expired') }
    it { expect(reply.statuses).to eq(first_sms_id => 'Expired', second_sms_id => 'Delivered') }
    it { expect(reply.error(third_sms_id)).to include('does not') }
    it { expect(reply.errors.keys).to contain_exactly(third_sms_id) }
    it { expect(reply.error?(first_sms_id)).to be(false) }
    it { expect(reply.not_found?(third_sms_id)).to be(true) }
    it { expect(reply.entry('unknown')).to be_nil }
  end

  context 'when multiple sms respond with success' do
    let(:sms_ids) { [first_sms_id, second_sms_id] }
    let(:xml_body) { fixture('status/success_multiple.xml') }

    it { expect(reply.entries.size).to eq(2) }
    it { expect(reply.statuses).to eq(first_sms_id => 'Expired', second_sms_id => 'Delivered') }
    it { expect(reply.error(first_sms_id)).to be_nil }
    it { expect(reply.errors).to be_empty }
    it { expect(reply.send_date(second_sms_id)).to eq('2020-05-09 14:11:40') }
  end

  context 'when the reply result is ERROR' do
    let(:sms_ids) { [first_sms_id] }
    let(:xml_body) { fixture('failure.xml') }

    it { expect { reply }.to raise_error(SmsTraffic::ApiError, /login param is missing/) }
  end
end
