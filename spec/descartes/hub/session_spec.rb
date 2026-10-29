# frozen_string_literal: true

require "spec_helper"
require "descartes/hub/session"
require "descartes/hub/protocol"

RSpec.describe Descartes::Hub::Session do
  let(:logger) { Logger.new(nil) }
  let(:session) { described_class.new(logger: logger) }

  describe "#initialize" do
    it "starts in :created state" do
      expect(session.state).to eq(:created)
    end
  end

  describe "#handle_message" do
    context "when handling init message" do
      let(:init_msg) do
        {
          type: "init",
          task_name: "test_task",
          prompt: "Say hello",
          system_prompt: "You are a bot",
          llm_profile: "openai",
          tools: [
            {
              name: "remote_tool",
              description: "A tool",
              parameters: { type: "object", properties: {}, required: [] }
            }
          ]
        }.to_json
      end

      it "transitions to :running state and spawns thread" do
        # Mocking the agent to avoid real LLM calls in tests
        agent_double = instance_double("Descartes::Agent::Base")
        allow(Descartes::Agent::Base).to receive(:new).and_return(agent_double)
        allow(agent_double).to receive(:execute).and_return("done")

        session.handle_message(init_msg)

        expect(%i[running finished]).to include(session.state)
        expect(session.thread).to be_a(Thread)

        session.thread.join
        expect(session.state).to eq(:finished)
      end

      it "uses ENV['DEFAULT_LLM_PROFILE'] when llm_profile is omitted in init" do
        agent_double = instance_double("Descartes::Agent::Base")
        expect(Descartes::Agent::Base).to receive(:new)
          .with(hash_including(profile_name: "kimi"))
          .and_return(agent_double)
        allow(agent_double).to receive(:execute).and_return("done")

        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("DEFAULT_LLM_PROFILE").and_return("kimi")

        msg_without_profile = {
          type: "init",
          task_name: "test_task",
          prompt: "Say hello",
          tools: []
        }.to_json

        session.handle_message(msg_without_profile)
        session.thread.join
      end

      it "falls back to 'default' when llm_profile is omitted and no ENV is set" do
        agent_double = instance_double("Descartes::Agent::Base")
        expect(Descartes::Agent::Base).to receive(:new)
          .with(hash_including(profile_name: "default"))
          .and_return(agent_double)
        allow(agent_double).to receive(:execute).and_return("done")

        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("DEFAULT_LLM_PROFILE").and_return(nil)

        msg_without_profile = {
          type: "init",
          task_name: "test_task",
          prompt: "Say hello",
          tools: []
        }.to_json

        session.handle_message(msg_without_profile)
        session.thread.join
      end
    end

    context "when handling tool_result message" do
      let(:tool_result_msg) do
        {
          type: "tool_result",
          call_id: "123",
          output: "Success",
          status: "ok"
        }.to_json
      end

      it "pushes message to queue" do
        queue = session.instance_variable_get(:@message_queue)

        session.handle_message(tool_result_msg)

        expect(queue.size).to eq(1)
        expect(queue.pop[:type]).to eq("tool_result")
      end
    end

    it "raises ParseError for invalid JSON" do
      expect { session.handle_message("invalid") }.to raise_error(Descartes::Hub::Protocol::ParseError)
    end
  end

  describe "Remote Tool execution" do
    it "transitions state to :waiting_tool and broadcasts execute_tool msg" do
      session.set_state(:running)
      schema = { name: "remote_tool", description: "test", parameters: { type: "object", properties: {}, required: [] } }
      tool_class = session.send(:build_remote_tool_class, schema)
      tool = tool_class.new(nil)

      expect(tool.class.tool_name).to eq("remote_tool")
    end
  end

  describe "#terminate!" do
    it "kills the thread and transitions to :aborted" do
      # Create a thread that loops forever
      session.instance_variable_set(:@thread, Thread.new { loop { sleep 0.1 } })
      session.instance_variable_set(:@state, :running)

      session.terminate!

      expect(session.state).to eq(:aborted)
      expect(session.thread.alive?).to be false
    end

    it "does not change state if already finished" do
      session.instance_variable_set(:@state, :finished)
      session.terminate!
      expect(session.state).to eq(:finished)
    end
  end
end
