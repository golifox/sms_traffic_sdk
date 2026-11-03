require 'open3'
require 'rbconfig'

RSpec.describe SmsTraffic::Client::Reply do
  describe 'with a custom xml_parser that raises' do
    let(:parser) { Class.new { def parse(_xml) = raise(ArgumentError, 'custom parser failed') }.new }

    it 're-raises the parser error' do
      expect { described_class.new('<x', xml_parser: parser) }.to raise_error(ArgumentError, 'custom parser failed')
    end

    # The suite has REXML loaded already, so a fresh process proves the gem does not depend on that.
    it 're-raises the parser error in a process where REXML is not loaded yet' do
      script = <<~RUBY
        require 'sms_traffic'
        parser = Class.new { def parse(_xml) = raise(ArgumentError, 'custom parser failed') }.new
        begin
          SmsTraffic::Client::Reply.new('<x', xml_parser: parser)
        rescue ArgumentError => e
          puts e.message
        end
      RUBY
      lib = File.expand_path('../../../../lib', __dir__)
      output, status = Open3.capture2e(RbConfig.ruby, '-I', lib, '-e', script)

      expect([output.strip, status.success?]).to eq(['custom parser failed', true])
    end
  end
end
