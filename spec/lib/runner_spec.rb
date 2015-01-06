require 'json'
require 'turbot_runner'

describe TurbotRunner::Runner do
  before(:each) do
    Dir.glob('spec/bots/**/output/*').each {|f| File.delete(f)}
  end

  after(:all) do
    puts
    puts 'If all specs passed, you should now run `ruby spec/manual_spec.rb`'
  end

  describe '#run' do
    context 'with a bot written in ruby' do
      before do
        @runner = TurbotRunner::Runner.new('spec/bots/ruby-bot')
      end

      it 'produces expected output' do
        @runner.run
        expect([@runner, 'scraper']).to have_output('full-scraper.out')
      end

      it 'returns true' do
        expect(@runner.run).to be(true)
      end
    end

    context 'with a bot written in python' do
      before do
        @runner = TurbotRunner::Runner.new('spec/bots/python-bot')
      end

      it 'produces expected output' do
        @runner.run
        expect([@runner, 'scraper']).to have_output('full-scraper.out')
      end
    end

    context 'with a bot with a transformer' do
      before do
        @runner = TurbotRunner::Runner.new('spec/bots/bot-with-transformer')
      end

      it 'produces expected outputs' do
        @runner.run
        expect([@runner, 'scraper']).to have_output('full-scraper.out')
        expect([@runner, 'transformer']).to have_output('full-transformer.out')
      end

      it 'returns true' do
        expect(@runner.run).to be(true)
      end
    end

    context 'with a bot with multiple transformers' do
      before do
        @runner = TurbotRunner::Runner.new('spec/bots/bot-with-transformers')
      end

      it 'produces expected outputs' do
        @runner.run
        expect([@runner, 'scraper']).to have_output('full-scraper.out')
        expect([@runner, 'transformer1']).to have_output('full-transformer.out')
        expect([@runner, 'transformer2']).to have_output('full-transformer.out')
      end

      it 'returns true' do
        expect(@runner.run).to be(true)
      end
    end

    context 'with a bot that logs' do
      context 'when logging to file enabled' do
        it 'logs to file' do
          expected_log = "doing...\ndone\n"
          runner = TurbotRunner::Runner.new(
            'spec/bots/logging-bot',
            :log_to_file => true
          )
          runner.run
          expect([runner, 'scraper']).to have_error_output_matching(expected_log)
        end
      end

      context 'when logging to file not enabled' do
        xit 'logs to stderr' do
          # This is tested in manual_spec.rb
        end
      end
    end

    context 'with a bot that outputs RUN ENDED' do
      before do
        @runner = TurbotRunner::Runner.new(
          'spec/bots/bot-that-emits-run-ended',
          :log_to_file => true
        )
      end
      it 'calls handle_run_ended on the handler' do
        expect_any_instance_of(TurbotRunner::BaseHandler).to receive(:handle_run_ended)
        @runner.run
      end

      it 'interrupts the run' do
        expect_any_instance_of(TurbotRunner::ScriptRunner).to receive(:interrupt)
        @runner.run
      end
    end


    context 'with a bot that crashes in scraper' do
      before do
        @runner = TurbotRunner::Runner.new(
          'spec/bots/bot-that-crashes-in-scraper',
          :log_to_file => true
        )
      end

      it 'returns false' do
        expect(@runner.run).to be(false)
      end

      it 'writes error to stderr' do
        @runner.run
        expect([@runner, 'scraper']).to have_error_output_matching(/Oh no/)
      end

      it 'still runs the transformers' do
        expect(@runner).to receive(:run_script).once.with(
          hash_including(:file=>"scraper.rb"))
        expect(@runner).to receive(:run_script).once.with(
          hash_including(:file=>"transformer1.rb"), anything)
        @runner.run
      end
    end

    context 'with a bot that expects a file to be present in the working directory' do
      before do
        @runner = TurbotRunner::Runner.new(
          'spec/bots/bot-that-expects-file',
          :log_to_file => true
        )
      end

      it 'returns true' do
        expect(@runner.run).to be(true)
      end
    end

    context 'with a bot that crashes in transformer' do
      before do
        @runner = TurbotRunner::Runner.new(
          'spec/bots/bot-that-crashes-in-transformer',
          :log_to_file => true
        )
      end

      it 'returns false' do
        expect(@runner.run).to be(false)
      end

      it 'writes error to stderr' do
        @runner.run
        expect([@runner, 'transformer2']).to have_error_output_matching(/Oh no/)
      end
    end

    context 'with a bot that is interrupted in scraper' do
      xit 'produces truncated output' do
        # This is tested in manual_spec.rb
      end
    end

    context 'with a handler that interrupts the runner' do
      before do
        class Handler < TurbotRunner::BaseHandler
          def initialize(*)
            @count = 0
            super
          end

          def handle_valid_record(record, data_type)
            @count += 1
            raise TurbotRunner::InterruptRun if @count >= 5
          end
        end

        @runner = TurbotRunner::Runner.new(
          'spec/bots/slow-bot',
          :record_handler => Handler.new,
          :log_to_file => true
        )
      end

      it 'produces expected output' do
        @runner.run
        expect([@runner, 'scraper']).to have_output('truncated-scraper.out')
      end

      it 'returns true' do
        expect(@runner.run).to be(true)
      end
    end

    context 'with a scraper that produces an invalid record' do
      it 'returns false' do
        @runner = TurbotRunner::Runner.new('spec/bots/invalid-record-bot')
        expect(@runner.run).to be(false)
      end
    end

    context 'with a scraper that produces invalid JSON' do
      it 'returns false' do
        @runner = TurbotRunner::Runner.new('spec/bots/invalid-json-bot')
        expect(@runner.run).to be(false)
      end
    end

    context 'with a scraper that hangs' do
      # XXX This spec fails because the loop in ScriptRunner#run that
      # reads lines from the output file doesn't start until the
      # output file is created; however, the way we're redirecting
      # stdout using the shell means the file doesn't get created
      # until
      it 'returns false' do
        @runner = TurbotRunner::Runner.new(
          'spec/bots/bot-with-pause',
          :timeout => 1,
          :log_to_file => true
        )
        expect(@runner.run).to be(false)
      end
    end
  end

  describe '#process_output' do
    before do
      class Handler < TurbotRunner::BaseHandler
        attr_reader :records_seen

        def initialize(*)
          @records_seen = Hash.new {|h, k| h[k] = 0}
          super
        end

        def handle_valid_record(record, data_type)
          @records_seen[data_type] += 1
        end
      end

      @handler = Handler.new
    end

    it 'calls handler once for each line of output' do
      TurbotRunner::Runner.new('spec/bots/bot-with-transformer').run

      runner = TurbotRunner::Runner.new(
        'spec/bots/bot-with-transformer',
        :record_handler => @handler
      )

      runner.process_output
      expect(@handler.records_seen['primary data']).to eq(10)
      expect(@handler.records_seen['simple-licence']).to eq(10)
    end

    it 'can cope when scraper has failed immediately' do
      TurbotRunner::Runner.new('spec/bots/bot-that-crashes-immediately').run

      runner = TurbotRunner::Runner.new(
        'spec/bots/bot-with-transformer',
        :record_handler => @handler
      )

      runner.process_output
    end
  end

  describe '#set_up_output_directory' do
    before do
      @runner = TurbotRunner::Runner.new('spec/bots/bot-with-transformer')
    end

    it 'clears existing output' do
      path = File.join(@runner.base_directory, 'output', 'scraper.out')
      FileUtils.touch(path)
      @runner.set_up_output_directory
      expect(File.exist?(path)).to be(false)
    end

    it 'does not clear existing files that are not output files' do
      path = File.join(@runner.base_directory, 'output', 'stdout')
      FileUtils.touch(path)
      @runner.set_up_output_directory
      expect(File.exist?(path)).to be(true)
    end
  end
end


RSpec::Matchers.define :have_output do |expected|
  match do |actual|
    runner, script = actual

    expected_path = File.join('spec', 'outputs', expected)
    expected_output = File.readlines(expected_path).map {|line| JSON.parse(line)}
    actual_path = File.join(runner.base_directory, 'output', "#{script}.out")
    actual_output = File.readlines(actual_path).map {|line| JSON.parse(line)}
    expect(expected_output).to eq(actual_output)
  end
end


RSpec::Matchers.define :have_error_output_matching do |expected|
  match do |actual|
    runner, script = actual

    actual_path = File.join(runner.base_directory, 'output', "#{script}.err")
    actual_output = File.read(actual_path)
    expect(actual_output).to match(expected)
  end
end
