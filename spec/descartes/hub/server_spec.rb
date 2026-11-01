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

    context "when HUB_AUTH_TOKEN is configured" do
      let(:auth_token) { "secret_token_123" }

      around do |example|
        old_token = ENV["HUB_AUTH_TOKEN"]
        ENV["HUB_AUTH_TOKEN"] = auth_token
        example.run
      ensure
        ENV["HUB_AUTH_TOKEN"] = old_token
      end

      it "still allows /healthz without auth token" do
        env = {
          "REQUEST_METHOD" => "GET",
          "PATH_INFO" => "/healthz",
          "rack.input" => StringIO.new
        }

        status, _headers, body = server.call(env)
        expect(status).to eq(200)
        expect(JSON.parse(body.first)["status"]).to eq("ok")
      end

      it "blocks requests without token with 401 Unauthorized" do
        env = {
          "REQUEST_METHOD" => "GET",
          "PATH_INFO" => "/",
          "rack.input" => StringIO.new
        }

        status, _headers, body = server.call(env)
        expect(status).to eq(401)
        expect(JSON.parse(body.first)["error"]).to include("Unauthorized")
      end

      it "blocks requests with wrong token with 401 Unauthorized" do
        env = {
          "REQUEST_METHOD" => "GET",
          "PATH_INFO" => "/",
          "QUERY_STRING" => "token=wrong_secret",
          "rack.input" => StringIO.new
        }

        status, _headers, body = server.call(env)
        expect(status).to eq(401)
      end

      it "allows requests with valid query param token" do
        env = {
          "REQUEST_METHOD" => "GET",
          "PATH_INFO" => "/",
          "QUERY_STRING" => "token=#{auth_token}",
          "rack.input" => StringIO.new
        }

        status, _headers, body = server.call(env)
        expect(status).to eq(200)
      end

      it "allows requests with valid Authorization Bearer header" do
        env = {
          "REQUEST_METHOD" => "GET",
          "PATH_INFO" => "/",
          "HTTP_AUTHORIZATION" => "Bearer #{auth_token}",
          "rack.input" => StringIO.new
        }

        status, _headers, body = server.call(env)
        expect(status).to eq(200)
      end
    end
  end
end
