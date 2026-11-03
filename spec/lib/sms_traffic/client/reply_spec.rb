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

  it 'treats a non-Hash parsed reply as empty' do
    expect(described_class.new('<reply>hi</reply>').to_h).to eq({})
  end

  it 'keeps ISO-looking dates and booleans as provider strings' do
    reply = described_class.new('<reply><send_date>2020-05-09T14:11:39</send_date><flag>true</flag></reply>')

    expect(reply.to_h).to eq('send_date' => '2020-05-09T14:11:39', 'flag' => 'true')
  end

  it 'keeps Object#hash intact' do
    expect(described_class.new(xml).hash).to be_an(Integer)
  end
end
