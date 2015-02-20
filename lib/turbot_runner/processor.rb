require 'openc/json_schema'

module TurbotRunner
  class Processor
    def initialize(runner, script_config, record_handler)
      @runner = runner
      @data_type = script_config[:data_type]
      #@identifying_fields = script_config[:identifying_fields]
      @record_handler = record_handler
    end

    def process(line)
      begin
        if line.strip == "RUN ENDED"
          @record_handler.handle_run_ended
          @runner.interrupt if @runner
        else
          record = Openc::JsonSchema.convert_dates(schema_path, JSON.parse(line))

          error_message = Validator.validate(@data_type, record, nil)

          if error_message.nil?
            begin
              @record_handler.handle_valid_record(record, @data_type)
            rescue InterruptRun
              @runner.interrupt if @runner
            end
          else
            @record_handler.handle_invalid_record(record, @data_type, error_message)
            @runner.interrupt_and_mark_as_failed if @runner
          end
        end
      rescue JSON::ParserError
        @record_handler.handle_invalid_json(line)
        @runner.interrupt_and_mark_as_failed if @runner
      end
    end

    def interrupt
      @runner.interrupt
    end

    def schema_path
      TurbotRunner.schema_path(@data_type)
    end
  end
end
