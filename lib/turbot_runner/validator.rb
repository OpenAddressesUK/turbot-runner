module TurbotRunner
  module Validator
    extend self

    def validate(data_type, record, identifying_fields)
      schema_path = TurbotRunner.schema_path(data_type)
      error = Openc::JsonSchema.validate(schema_path, record)

      message = nil

      if error.nil?
        flattened_record = TurbotRunner::Utils.flatten(record)

        # identifying_attributes = flattened_record.reject do |k, v|
        #   !identifying_fields.include?(k) || v.nil? || v == ''
        # end
        #
        # if identifying_attributes.empty?
        #   message = "There were no values provided for any of the identifying fields: #{identifying_fields.join(', ')}"
        # end
      else
        message = case error[:type]
        when :missing
          "Missing required property: #{error[:path]}"
        when :one_of_no_matches
          "No match for property: #{error[:path]}"
        when :one_of_many_matches
          "Multiple possible matches for property: #{error[:path]}"
        when :too_short
          "Property too short: #{error[:path]} (must be at least #{error[:length]} characters)"
        when :too_long
          "Property too long: #{error[:path]} (must be at most #{error[:length]} characters)"
        when :type_mismatch
          "Property of wrong type: #{error[:path]} (must be of type #{error[:allowed_types].join(', ')})"
        when :enum_mismatch
          "Property not an allowed value: #{error[:path]} (must be one of #{error[:allowed_values].join(', ')})"
        when :format_mismatch
          "Property not of expected format: #{error[:path]} (must be of format #{error[:expected_format]})"
        when :unknown
          error[:message]
        end
      end

      message
    end
  end
end
