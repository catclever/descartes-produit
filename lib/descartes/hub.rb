# frozen_string_literal: true

require "descartes"
require_relative "hub/version"
require_relative "hub/protocol"
require_relative "hub/session"
require_relative "hub/server"

module Descartes
  module Hub
    class Error < StandardError; end
  end
end
