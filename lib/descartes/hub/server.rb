# frozen_string_literal: true

require "faye/websocket"
require "json"
require "logger"
require "rack"
require "descartes"
require_relative "session"
require_relative "version"

module Descartes
  module Hub
    class Server
      KEEPALIVE_TIME = 15

      attr_reader :sessions

      def initialize(logger: nil)
        @logger = logger || Logger.new($stdout, level: Logger::INFO)
        @sessions = {}
      end

      def call(env)
        req = Rack::Request.new(env)

        # Allow open health check probes without authentication
        if req.path_info.match?(%r{\A/healthz?\z}) && !Faye::WebSocket.websocket?(env)
          body = JSON.generate({
                                 status: "ok",
                                 service: "descartes-hub",
                                 version: Descartes::Hub::VERSION,
                                 active_sessions: @sessions.size
                               })
          return [200, { "Content-Type" => "application/json" }, [body]]
        end

        # Authenticate if HUB_AUTH_TOKEN is configured in environment
        auth_token = ENV["HUB_AUTH_TOKEN"]&.strip
        if auth_token && !auth_token.empty?
          token = extract_token(env, req)
          unless token == auth_token
            @logger.warn "[Descartes::Hub::Server] Unauthorized connection attempt blocked from #{req.ip}"
            return [401, { "Content-Type" => "application/json" }, [JSON.generate({ error: "Unauthorized: Invalid or missing HUB_AUTH_TOKEN" })]]
          end
        end

        if Faye::WebSocket.websocket?(env)
          ws = Faye::WebSocket.new(env, nil, { ping: KEEPALIVE_TIME })

          ws.on :open do |_event|
            @logger.info "[Descartes::Hub::Server] Client connected (ID: #{ws.object_id})"
            session = Session.new(channel: ws, logger: @logger)
            @sessions[ws.object_id] = session
          end

          ws.on :message do |event|
            session = @sessions[ws.object_id]
            if session
              begin
                session.handle_message(event.data)
              rescue StandardError => e
                @logger.error "[Descartes::Hub::Server] Error handling message: #{e.message}"
              end
            else
              @logger.warn "[Descartes::Hub::Server] Message received for untracked session #{ws.object_id}"
            end
          end

          ws.on :close do |event|
            @logger.info "[Descartes::Hub::Server] Client disconnected (ID: #{ws.object_id}, code: #{event.code}, reason: #{event.reason})"
            session = @sessions.delete(ws.object_id)
            session&.terminate!
            ws = nil
          end

          ws.rack_response
        else
          # Standard HTTP health check endpoint
          body = JSON.generate({
                                 status: "ok",
                                 service: "descartes-hub",
                                 version: Descartes::Hub::VERSION,
                                 active_sessions: @sessions.size
                               })
          [200, { "Content-Type" => "application/json" }, [body]]
        end
      end

      private

      def extract_token(env, req)
        auth_header = env["HTTP_AUTHORIZATION"]
        if auth_header && auth_header.start_with?("Bearer ")
          auth_header.sub(/^Bearer /, "").strip
        elsif req.params["token"]
          req.params["token"].strip
        end
      end
    end
  end
end
