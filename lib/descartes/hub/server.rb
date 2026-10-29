# frozen_string_literal: true

require "faye/websocket"
require "json"
require "logger"
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
    end
  end
end
