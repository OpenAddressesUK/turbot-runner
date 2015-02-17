require 'turbot_runner/base_handler'
require 'turbot_runner/exceptions'
require 'turbot_runner/processor'
require 'turbot_runner/runner'
require 'turbot_runner/script_runner'
require 'turbot_runner/utils'
require 'turbot_runner/validator'
require 'turbot_runner/version'

module TurbotRunner
  SCHEMAS_PATH = File.expand_path('../../schema/schemas', __FILE__)

  def self.schema_path(data_type)
    hyphenated_name = data_type.to_s.gsub("_", "-").gsub(" ", "-")
    File.join(SCHEMAS_PATH, "#{hyphenated_name}-schema.json")
  end
end
