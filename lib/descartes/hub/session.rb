# frozen_string_literal: true

require "json"
require "logger"
require "descartes"
require_relative "protocol"

module Descartes
  module Hub
    class Session
      attr_reader :state, :thread, :session_id, :channel

      def initialize(channel: nil, logger: nil)
        @channel = channel
        @state = :created
        @session_id = object_id.to_s
        @logger = logger || Logger.new($stdout, level: Logger::INFO)
        @message_queue = Queue.new
        @mutex = Mutex.new
        @thread = nil
        @agent = nil
      end

      def send_message(payload)
        return unless @channel.respond_to?(:send)

        @channel.send(payload)
      rescue StandardError => e
        @logger.error "[Session #{@session_id}] Failed to send message to channel: #{e.message}"
      end

      def handle_message(raw_msg)
        payload = Protocol.parse(raw_msg)

        case payload[:type]
        when "init"
          handle_init(payload)
        when "tool_result"
          handle_tool_result(payload)
        else
          @logger.warn "[Session #{@session_id}] Ignored message type: #{payload[:type]}"
        end
      rescue Protocol::ParseError => e
        @logger.error "[Session #{@session_id}] Failed to parse message: #{e.message}"
        raise e
      end

      def terminate!
        @mutex.synchronize do
          return if %i[finished aborted].include?(@state)

          @state = :aborted
        end

        if @thread&.alive?
          @thread.kill
          @thread.join(1) # wait for thread to actually die
        end

        @message_queue.clear
        @logger.info "[Session #{@session_id}] Terminated."
      end

      def set_state(new_state)
        @mutex.synchronize do
          @state = new_state
        end
      end

      private

      def handle_init(payload)
        @mutex.synchronize do
          raise "Session already initialized" unless @state == :created

          @state = :running
        end

        task_name = payload[:task_name]
        prompt = payload[:prompt]
        system_prompt = payload[:system_prompt]
        profile_candidate = payload[:llm_profile]&.to_s&.strip
        env_default = ENV["DEFAULT_LLM_PROFILE"]&.strip
        llm_profile = if profile_candidate && !profile_candidate.empty?
                        profile_candidate
                      elsif env_default && !env_default.empty?
                        env_default
                      else
                        "default"
                      end
        tools = payload[:tools] || []

        # Initialize context
        context = Descartes::Context.new({ task_name: task_name })

        # Build RemoteTools
        remote_tools = tools.map do |tool_schema|
          build_remote_tool_class(tool_schema)
        end

        @agent = Descartes::Agent::Base.new(
          name: "hub_agent_#{@session_id}",
          profile_name: llm_profile,
          system_prompt: system_prompt,
          tools: remote_tools,
          logger: @logger
        )

        if @agent.respond_to?(:on)
          @agent.on(:thought) do |text|
            send_message(Protocol.build(:stream_event, event: "thought", data: text))
          end

          @agent.on(:tool_call_start) do |data|
            send_message(Protocol.build(:stream_event, event: "tool_call_start", data: data))
          end

          @agent.on(:tool_call_end) do |data|
            send_message(Protocol.build(:stream_event, event: "tool_call_end", data: data))
          end
        end

        @thread = Thread.new do
          result = @agent.execute(context, prompt)

          @mutex.synchronize do
            @state = :finished
          end

          # Send finished msg
          finished_msg = Protocol.build(:finished, result: result, status: "ok")
          @logger.info "[Session #{@session_id}] Hub Message Out: #{finished_msg}"
          send_message(finished_msg)

          @logger.info "[Session #{@session_id}] Finished successfully."
        rescue StandardError => e
          @mutex.synchronize do
            @state = :aborted
          end
          error_msg = Protocol.build(:error, message: e.message)
          @logger.info "[Session #{@session_id}] Hub Message Out: #{error_msg}"
          send_message(error_msg)

          @logger.error "[Session #{@session_id}] Error in worker thread: #{e.message}"
          @logger.error e.backtrace.join("\n")
        end
      end

      def handle_tool_result(payload)
        # Push payload to queue to unblock the waiting tool
        @message_queue.push(payload)
      end

      def build_remote_tool_class(schema)
        # Create an anonymous class inheriting from Tool::Base
        queue = @message_queue
        session_id = @session_id
        logger = @logger
        session = self

        Class.new(Descartes::Tool::Base) do
          # We define class methods directly using the schema
          name schema[:name]
          description schema[:description]
          parameters schema[:parameters]

          # Use closures to access queue and other session state
          define_method :execute do |args|
            logger.info "[Session #{session_id}] Executing remote tool: #{self.class.tool_name}"

            # Send execute_tool message
            call_id = "call_#{rand(1_000_000)}"
            execute_msg = Protocol.build(:execute_tool, call_id: call_id, tool: self.class.tool_name, arguments: args)
            logger.info "[Session #{session_id}] Hub Message Out: #{execute_msg}"
            session.send_message(execute_msg)

            session.set_state(:waiting_tool)

            begin
              loop do
                msg = queue.pop(timeout: 120)
                return "Error: Remote tool execution timed out after 120s" if msg.nil?
                return msg[:output] if msg[:type] == "tool_result" && msg[:call_id] == call_id

                # Put it back if it's not ours (unlikely in single thread but good practice)
                queue.push(msg) unless msg[:type] == "tool_result"
              end
            ensure
              session.set_state(:running)
            end
          end
        end
      end
    end
  end
end
