# frozen_string_literal: true

require "spec_helper"
require "descartes/hub/protocol"

RSpec.describe Descartes::Hub::Protocol do
  describe ".parse" do
    it "parses a valid message" do
      json = '{"type": "init", "task_name": "test"}'
      expect(described_class.parse(json)).to eq({ type: "init", task_name: "test" })
    end

    it "raises ParseError for invalid JSON" do
      expect { described_class.parse("invalid") }.to raise_error(Descartes::Hub::Protocol::ParseError, /Invalid JSON/)
    end

    it "raises ParseError for missing type" do
      expect { described_class.parse('{"key": "value"}') }.to raise_error(Descartes::Hub::Protocol::ParseError, /Missing message type/)
    end

    it "raises ParseError for unknown type" do
      expect { described_class.parse('{"type": "unknown"}') }.to raise_error(Descartes::Hub::Protocol::ParseError, /Unknown message type/)
    end
  end

  describe ".build" do
    it "builds a valid message" do
      json = described_class.build(:init, task_name: "test")
      expect(JSON.parse(json, symbolize_names: true)).to eq({ type: "init", task_name: "test" })
    end

    it "raises Error for unknown type" do
      expect { described_class.build(:unknown) }.to raise_error(Descartes::Hub::Protocol::Error, /Unknown message type/)
    end
  end
end
