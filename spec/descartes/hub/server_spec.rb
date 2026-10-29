# frozen_string_literal: true

require "spec_helper"
require "descartes/hub/server"

RSpec.describe Descartes::Hub::Server do
  let(:server) { described_class.new(logger: Logger.new(nil)) }

  describe "#call" do
    context "when a normal HTTP request arrives" do
      it "returns 200 with JSON health status" do
        env = {
          "REQUEST_METHOD" => "GET",
          "PATH_INFO" => "/healthz",
          "rack.input" => StringIO.new
        }

        status, headers, body = server.call(env)

        expect(status).to eq(200)
        expect(headers["Content-Type"]).to eq("application/json")

        json = JSON.parse(body.first)
        expect(json["status"]).to eq("ok")
        expect(json["service"]).to eq("descartes-hub")
        expect(json["active_sessions"]).to eq(0)
      end
    end
  end
end
