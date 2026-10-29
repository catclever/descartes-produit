# frozen_string_literal: true

require "json"

module Descartes
  module Hub
    module Protocol
      class Error < StandardError; end
      class ParseError < Error; end

      VALID_TYPES = %w[init status execute_tool tool_result stream_event finished error].freeze

      def self.parse(json_string)
        payload = JSON.parse(json_string, symbolize_names: true)
        type = payload[:type]
        raise ParseError, "Missing message type" unless type
        raise ParseError, "Unknown message type: #{type}" unless VALID_TYPES.include?(type)

        payload
      rescue JSON::ParserError => e
        raise ParseError, "Invalid JSON: #{e.message}"
      end

      def self.build(type, **payload)
        raise Error, "Unknown message type: #{type}" unless VALID_TYPES.include?(type.to_s)

        { type: type.to_s }.merge(payload).to_json
      end
    end
  end
end
