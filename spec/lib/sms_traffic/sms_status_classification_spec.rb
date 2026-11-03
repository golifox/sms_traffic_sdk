RSpec.describe SmsTraffic::Sms, 'status classification' do
  include_context 'with configured client'

  subject(:sms) { described_class.new('79991112233', 'text') }

  def sent_sms_with_provider_status(provider_status)
    stub_request(:post, uri).with(body: hash_including(phones: '79991112233'))
                            .to_return(body: fixture('deliver/success_single.xml').sub('1000472891', '1'))
    stub_request(:post, uri).with(body: hash_including(operation: 'status'))
                            .to_return(body: "<reply><sms_id>1</sms_id><status>#{provider_status}</status></reply>")
    sms.deliver
    sms.update_status
    sms
  end

  it 'is neither final nor delivered before sending' do
    expect([sms.final?, sms.delivered?]).to eq([false, false])
  end

  it 'is neither final nor delivered when sent' do
    stub_request(:post, uri).to_return(body: fixture('deliver/success_single.xml'))
    sms.deliver

    expect([sms.status, sms.final?, sms.delivered?]).to eq(['sent', false, false])
  end

  { '' => 'sent', 'Buffered SMSC' => 'buffered smsc' }.each do |provider_status, expected|
    it "is not final and has no errors for #{provider_status.inspect}" do
      result = sent_sms_with_provider_status(provider_status)

      expect([result.status, result.final?, result.errors]).to eq([expected, false, []])
    end
  end

  it 'keeps the sent status without errors for a self-closing status element' do
    stub_request(:post, uri).with(body: hash_including(phones: '79991112233'))
                            .to_return(body: fixture('deliver/success_single.xml').sub('1000472891', '1'))
    stub_request(:post, uri).with(body: hash_including(operation: 'status'))
                            .to_return(body: '<reply><sms_id>1</sms_id><status/></reply>')
    sms.deliver
    sms.update_status

    expect([sms.status, sms.errors]).to eq(['sent', []])
  end

  it 'reports an error when the entry has neither status nor error' do
    stub_request(:post, uri).with(body: hash_including(phones: '79991112233'))
                            .to_return(body: fixture('deliver/success_single.xml').sub('1000472891', '1'))
    stub_request(:post, uri).with(body: hash_including(operation: 'status'))
                            .to_return(body: '<reply><sms_id>1</sms_id></reply>')
    sms.deliver
    sms.update_status

    expect(sms.errors).to eq(['No status returned for sms 1'])
  end

  it 'is final and delivered for Delivered' do
    result = sent_sms_with_provider_status('Delivered')

    expect([result.status, result.final?, result.delivered?]).to eq(['delivered', true, true])
  end

  ['Non Delivered', 'Rejected', 'Expired', 'Deleted', 'Unknown status'].each do |status|
    it "is final but not delivered for #{status}" do
      result = sent_sms_with_provider_status(status)

      expect([result.final?, result.delivered?]).to eq([true, false])
    end
  end
end
