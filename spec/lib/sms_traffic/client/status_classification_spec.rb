RSpec.describe SmsTraffic::Client::StatusReply, 'status classification' do
  def reply_for(status)
    described_class.new("<reply><sms_id>1</sms_id><status>#{status}</status></reply>")
  end

  {
    ''               => [false, false],
    'Buffered SMSC'  => [false, false],
    'Delivered'      => [true, true],
    'Non Delivered'  => [true, false],
    'Rejected'       => [true, false],
    'Expired'        => [true, false],
    'Deleted'        => [true, false],
    'Unknown status' => [true, false]
  }.each do |status, (final, delivered)|
    it "classifies #{status.inspect} as final=#{final} delivered=#{delivered}" do
      entry = reply_for(status).entry

      expect([entry.final?, entry.delivered?]).to eq([final, delivered])
    end
  end

  it 'delegates to the entry like status' do
    reply = described_class.new(fixture('status/success_multiple.xml'))

    expect([reply.final?('8287713301'), reply.delivered?('8287713301'), reply.delivered?('8287713303')])
      .to eq([true, false, true])
  end

  it 'takes no sms_id for a single entry' do
    expect(reply_for('Delivered')).to be_delivered
  end

  it 'is false for an entry with an error' do
    reply = described_class.new(fixture('status/failure_single.xml'))

    expect([reply.final?, reply.delivered?]).to eq([false, false])
  end

  it 'is false for an unknown sms_id' do
    expect(reply_for('Delivered').final?('999')).to be(false)
  end
end
