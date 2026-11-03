RSpec.describe SmsTraffic::Status do
  it 'lists the provider final statuses' do
    expect(described_class::FINAL).to contain_exactly(
      'Delivered', 'Non Delivered', 'Rejected', 'Expired', 'Deleted', 'Unknown status'
    )
  end

  it 'lists the provider intermediate statuses' do
    expect(described_class::INTERMEDIATE).to contain_exactly('', 'Buffered SMSC')
  end
end
