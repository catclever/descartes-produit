# frozen_string_literal: true

require "descartes"
require "descartes/hub"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

require_relative "support/ruby_llm_mock"
