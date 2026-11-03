RSpec.describe SmsTraffic::Client::Reply do
  let(:xml) { fixture('failure.xml') }

  it 'accepts frozen input without mutating it' do
    frozen = xml.dup.freeze

    reply = described_class.new(frozen)

    expect(reply.to_h).to include('result' => 'ERROR', 'code' => '401')
    expect(frozen).to eq(xml)
  end

  it 'exposes the parsed reply as a JSON-serializable hash' do
    expect(JSON.parse(described_class.new(xml).to_h.to_json)).to include('description' => 'login param is missing')
  end

  it 'keeps Object#hash intact' do
    expect(described_class.new(xml).hash).to be_an(Integer)
  end
end
