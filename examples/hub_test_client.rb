# frozen_string_literal: true

require "faye/websocket"
require "eventmachine"
require "json"

url = ARGV[0] || "ws://localhost:8089/"
profile = ARGV[1]

puts "======================================================"
puts "  Descartes Hub E2E Test Client"
puts "  Target URL: #{url}"
puts "  LLM Profile: #{profile ? profile : '(Default from Hub ENV/Config)'}"
puts "======================================================"

EM.run do
  ws = Faye::WebSocket::Client.new(url)

  ws.on :open do |_event|
    puts "\n[Client] Connected to Descartes Hub!"
    puts "[Client] Sending 'init' message with local tool declaration..."

    init_payload = {
      type: "init",
      task_name: "math_calculator",
      prompt: "Please calculate the sum of 123 and 456 using your calculator tool.",
      system_prompt: "You are a helpful math assistant. You must use tools to perform calculations and submit your answer.",
      tools: [
        {
          name: "add_numbers",
          description: "Adds two integers together on the client machine.",
          parameters: {
            type: "object",
            properties: {
              a: { type: "integer", description: "First integer" },
              b: { type: "integer", description: "Second integer" }
            },
            required: %w[a b]
          }
        }
      ]
    }
    init_payload[:llm_profile] = profile if profile && !profile.strip.empty?

    ws.send(init_payload.to_json)
  end

  ws.on :message do |event|
    data = JSON.parse(event.data)
    type = data["type"]

    case type
    when "stream_event"
      event_name = data["event"]
      payload = data["data"]
      if event_name == "thought"
        puts "\n[Cloud Brain Thought]: #{payload}"
      elsif event_name == "tool_call_start"
        puts "\n[Cloud Brain Tool Start]: #{payload.inspect}"
      elsif event_name == "tool_call_end"
        puts "[Cloud Brain Tool End]: #{payload.inspect}"
      end

    when "execute_tool"
      call_id = data["call_id"]
      tool_name = data["tool"]
      args = data["arguments"]

      puts "\n[Client Received Tool Call Request]:"
      puts "  -> Tool: #{tool_name}"
      puts "  -> Args: #{args.inspect}"

      # Simulate local tool execution
      result = if tool_name == "add_numbers"
                 a = args["a"].to_i
                 b = args["b"].to_i
                 sum = a + b
                 puts "  -> [Client Local Execution] Executed #{a} + #{b} = #{sum}"
                 sum.to_s
               else
                 "Error: Unknown tool"
               end

      # Send tool result back to Hub
      response_msg = {
        type: "tool_result",
        call_id: call_id,
        status: "ok",
        output: result
      }
      puts "  -> [Client Sending Tool Result back to Cloud]: #{response_msg.to_json}"
      ws.send(response_msg.to_json)

    when "finished"
      puts "\n======================================================"
      puts "🎉 [Task Finished Successfully!]"
      puts "Result: #{data["result"]}"
      puts "======================================================"
      ws.close
      EM.stop

    when "error"
      puts "\n======================================================"
      puts "❌ [Task Failed with Error]"
      puts "Message: #{data["message"]}"
      puts "======================================================"
      ws.close
      EM.stop
    end
  end

  ws.on :close do |event|
    puts "\n[Client] Disconnected (code: #{event.code}, reason: #{event.reason})"
    EM.stop
  end
end
