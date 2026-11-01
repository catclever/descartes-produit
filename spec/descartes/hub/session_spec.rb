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

    context "when handling init message" do
      it "transitions to :running state and spawns thread" do
        agent_double = instance_double("Descartes::Agent::Base")
        allow(Descartes::Agent::Base).to receive(:new).and_return(agent_double)
        allow(agent_double).to receive(:execute).and_return("done")

        session.handle_message(init_msg)

        expect(%i[running finished]).to include(session.state)
        expect(session.thread).to be_a(Thread)

        session.thread.join
        expect(session.state).to eq(:finished)
      end

      it "injects Dalembert 5 intelligence tools into the agent" do
        agent_double = instance_double("Descartes::Agent::Base")
        expect(Descartes::Agent::Base).to receive(:new) do |args|
          expect(args[:tools]).to include(
            Dalembert::Tools::GithubRepoSurvey,
            Dalembert::Tools::GithubCodeSearch,
            Dalembert::Tools::DocFetcher,
            Dalembert::Tools::SpecInspector,
            Dalembert::Tools::KnowledgeStoreTool
          )
          agent_double
        end
        allow(agent_double).to receive(:execute).and_return("done")

        session.handle_message(init_msg)
        session.thread.join
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

    context "when handling execute_tool message from client" do
      let(:channel) { instance_double("Channel", send: nil) }
      let(:session_with_channel) { described_class.new(channel: channel, logger: logger) }

      it "dispatches to Dalembert tool and sends tool_result" do
        survey_double = instance_double(Dalembert::Tools::GithubRepoSurvey)
        allow(Dalembert::Tools::GithubRepoSurvey).to receive(:new).and_return(survey_double)
        allow(survey_double).to receive(:execute).with({ "query" => "ruby" }).and_return("Repo Blueprint")

        expect(channel).to receive(:send) do |raw_payload|
          data = JSON.parse(raw_payload, symbolize_names: true)
          expect(data[:type]).to eq("tool_result")
          expect(data[:call_id]).to eq("call_456")
          expect(data[:output]).to eq("Repo Blueprint")
        end

        msg = {
          type: "execute_tool",
          call_id: "call_456",
          tool: "survey_architecture",
          arguments: { query: "ruby" }
        }.to_json

        session_with_channel.handle_message(msg)
        sleep 0.1
      end

      it "returns error output when tool is unknown" do
        expect(channel).to receive(:send) do |raw_payload|
          data = JSON.parse(raw_payload, symbolize_names: true)
          expect(data[:type]).to eq("tool_result")
          expect(data[:call_id]).to eq("call_789")
          expect(data[:output]).to include("Error: Unknown cloud tool")
        end

        msg = {
          type: "execute_tool",
          call_id: "call_789",
          tool: "non_existent_tool",
          arguments: {}
        }.to_json

        session_with_channel.handle_message(msg)
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
