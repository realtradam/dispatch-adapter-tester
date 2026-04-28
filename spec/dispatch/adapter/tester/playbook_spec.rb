# frozen_string_literal: true

RSpec.describe Dispatch::Adapter::Tester::Playbook do
  let(:message_step) do
    { "step" => 1, "type" => "message", "content" => "Hello from the AI" }
  end

  let(:tool_call_step) do
    {
      "step" => 2,
      "type" => "tool_calls",
      "content" => nil,
      "tool_calls" => [
        {
          "id" => "tc_read_001",
          "name" => "read_file",
          "arguments" => { "path" => "/some/file.rb" }
        }
      ]
    }
  end

  let(:tool_call_with_content_step) do
    {
      "step" => 3,
      "type" => "tool_calls",
      "content" => "I will read the file for you.",
      "tool_calls" => [
        {
          "id" => "tc_read_002",
          "name" => "read_file",
          "arguments" => { "path" => "/other/file.rb" }
        }
      ]
    }
  end

  let(:multi_tool_step) do
    {
      "step" => 4,
      "type" => "tool_calls",
      "content" => nil,
      "tool_calls" => [
        {
          "id" => "tc_write_001",
          "name" => "write_file",
          "arguments" => { "path" => "/a.rb", "content" => "hello" }
        },
        {
          "id" => "tc_write_002",
          "name" => "write_file",
          "arguments" => { "path" => "/b.rb", "content" => "world" }
        }
      ]
    }
  end

  def build_adapter(steps, **kwargs)
    described_class.new(steps_json: JSON.generate(steps), **kwargs)
  end

  describe "#initialize" do
    it "parses a valid JSON string of steps" do
      adapter = build_adapter([message_step])
      expect(adapter.steps.length).to eq(1)
      expect(adapter.steps.first.step_id).to eq(1)
    end

    it "accepts an array directly instead of a JSON string" do
      adapter = described_class.new(steps_json: [message_step])
      expect(adapter.steps.length).to eq(1)
    end

    it "accepts empty steps" do
      adapter = build_adapter([])
      expect(adapter.steps).to be_empty
    end

    it "absorbs extra keyword arguments for drop-in compat" do
      expect do
        described_class.new(
          steps_json: "[]",
          model: "gpt-4",
          max_tokens: 50_000,
          min_request_interval: 3.0,
          rate_limit: nil
        )
      end.not_to raise_error
    end

    it "raises on invalid JSON" do
      expect do
        described_class.new(steps_json: "not json")
      end.to raise_error(Dispatch::Adapter::Tester::InvalidPlaybookError, /Failed to parse/)
    end

    it "raises when JSON is not an array" do
      expect do
        described_class.new(steps_json: '{"step": 1}')
      end.to raise_error(Dispatch::Adapter::Tester::InvalidPlaybookError, /must be an array/)
    end

    it "raises on duplicate step IDs" do
      steps = [
        { "step" => 1, "type" => "message", "content" => "a" },
        { "step" => 1, "type" => "message", "content" => "b" }
      ]
      expect do
        build_adapter(steps)
      end.to raise_error(Dispatch::Adapter::Tester::InvalidPlaybookError, /Duplicate step IDs/)
    end
  end

  describe "#chat" do
    context "with a message step" do
      it "returns a Response with content and end_turn stop_reason" do
        adapter = build_adapter([message_step])
        response = adapter.chat([])

        expect(response).to be_a(Dispatch::Adapter::Response)
        expect(response.content).to eq("Hello from the AI")
        expect(response.stop_reason).to eq(:end_turn)
        expect(response.tool_calls).to be_empty
      end

      it "reports zero token usage" do
        adapter = build_adapter([message_step])
        response = adapter.chat([])

        expect(response.usage.input_tokens).to eq(0)
        expect(response.usage.output_tokens).to eq(0)
      end
    end

    context "with a tool_calls step" do
      it "returns a Response with tool_calls and tool_use stop_reason" do
        adapter = build_adapter([tool_call_step])
        response = adapter.chat([])

        expect(response.stop_reason).to eq(:tool_use)
        expect(response.tool_calls.length).to eq(1)

        tc = response.tool_calls.first
        expect(tc).to be_a(Dispatch::Adapter::ToolUseBlock)
        expect(tc.id).to eq("tc_read_001")
        expect(tc.name).to eq("read_file")
        expect(tc.arguments).to eq({ "path" => "/some/file.rb" })
      end

      it "returns nil content when content is nil" do
        adapter = build_adapter([tool_call_step])
        response = adapter.chat([])

        expect(response.content).to be_nil
      end
    end

    context "with a tool_calls step that has content" do
      it "returns both content and tool_calls" do
        adapter = build_adapter([tool_call_with_content_step])
        response = adapter.chat([])

        expect(response.content).to eq("I will read the file for you.")
        expect(response.tool_calls.length).to eq(1)
        expect(response.stop_reason).to eq(:tool_use)
      end
    end

    context "with multiple tool calls in a single step" do
      it "returns all tool calls" do
        adapter = build_adapter([multi_tool_step])
        response = adapter.chat([])

        expect(response.tool_calls.length).to eq(2)
        expect(response.tool_calls.map(&:id)).to eq(%w[tc_write_001 tc_write_002])
        expect(response.tool_calls.map(&:name)).to eq(%w[write_file write_file])
      end
    end

    context "with a multi-step playbook" do
      it "consumes steps sequentially" do
        adapter = build_adapter([message_step, tool_call_step])

        r1 = adapter.chat([])
        expect(r1.content).to eq("Hello from the AI")
        expect(r1.stop_reason).to eq(:end_turn)

        r2 = adapter.chat([])
        expect(r2.stop_reason).to eq(:tool_use)
        expect(r2.tool_calls.first.id).to eq("tc_read_001")
      end

      it "advances the current_index" do
        adapter = build_adapter([message_step, tool_call_step])
        expect(adapter.current_index).to eq(0)

        adapter.chat([])
        expect(adapter.current_index).to eq(1)

        adapter.chat([])
        expect(adapter.current_index).to eq(2)
      end
    end

    context "when the playbook is exhausted" do
      it "raises PlaybookExhaustedError with step details" do
        adapter = build_adapter([message_step])
        adapter.chat([])

        expect do
          adapter.chat([])
        end.to raise_error(Dispatch::Adapter::Tester::PlaybookExhaustedError) do |error|
          expect(error.total_steps).to eq(1)
          expect(error.calls_made).to eq(2)
          expect(error.message).to include("all 1 steps")
          expect(error.message).to include("2nd time")
        end
      end
    end

    it "records each call in the call_log" do
      adapter = build_adapter([message_step])
      messages = [Dispatch::Adapter::Message.new(role: "user", content: "hi")]
      tools = [{ name: "test", description: "test", parameters: {} }]

      adapter.chat(messages, system: "You are helpful", tools: tools)

      expect(adapter.call_log.length).to eq(1)
      log_entry = adapter.call_log.first
      expect(log_entry[:system]).to eq("You are helpful")
      expect(log_entry[:tools]).to eq(tools)
      expect(log_entry[:step].step_id).to eq(1)
    end

    it "reports the configured model name in responses" do
      adapter = build_adapter([message_step], model: "custom-model")
      response = adapter.chat([])

      expect(response.model).to eq("custom-model")
    end
  end

  describe "#model_name" do
    it "returns the default model name" do
      adapter = build_adapter([])
      expect(adapter.model_name).to eq("tester-playbook")
    end

    it "returns a custom model name" do
      adapter = build_adapter([], model: "gpt-4")
      expect(adapter.model_name).to eq("gpt-4")
    end
  end

  describe "#provider_name" do
    it "returns 'Tester Playbook'" do
      adapter = build_adapter([])
      expect(adapter.provider_name).to eq("Tester Playbook")
    end
  end

  describe "#max_context_tokens" do
    it "returns a large context window" do
      adapter = build_adapter([])
      expect(adapter.max_context_tokens).to eq(1_000_000)
    end
  end

  describe "#list_models" do
    it "returns a single ModelInfo entry" do
      adapter = build_adapter([])
      models = adapter.list_models

      expect(models.length).to eq(1)
      expect(models.first).to be_a(Dispatch::Adapter::ModelInfo)
      expect(models.first.id).to eq("tester-playbook")
      expect(models.first.supports_tool_use).to be true
    end
  end

  describe "#finished?" do
    it "returns false when steps remain" do
      adapter = build_adapter([message_step])
      expect(adapter.finished?).to be false
    end

    it "returns true when all steps consumed" do
      adapter = build_adapter([message_step])
      adapter.chat([])
      expect(adapter.finished?).to be true
    end

    it "returns true for empty playbook" do
      adapter = build_adapter([])
      expect(adapter.finished?).to be true
    end
  end

  describe "#remaining_steps" do
    it "tracks remaining step count" do
      adapter = build_adapter([message_step, tool_call_step])
      expect(adapter.remaining_steps).to eq(2)

      adapter.chat([])
      expect(adapter.remaining_steps).to eq(1)

      adapter.chat([])
      expect(adapter.remaining_steps).to eq(0)
    end
  end

  describe "#verify_all_consumed!" do
    it "does not raise when all steps consumed" do
      adapter = build_adapter([message_step])
      adapter.chat([])

      expect { adapter.verify_all_consumed! }.not_to raise_error
    end

    it "raises UnconsumedStepsError with remaining step IDs" do
      adapter = build_adapter([message_step, tool_call_step])
      adapter.chat([])

      expect do
        adapter.verify_all_consumed!
      end.to raise_error(Dispatch::Adapter::Tester::UnconsumedStepsError) do |error|
        expect(error.total_steps).to eq(2)
        expect(error.consumed).to eq(1)
        expect(error.remaining_step_ids).to eq([2])
      end
    end

    it "does not raise for empty playbook" do
      adapter = build_adapter([])
      expect { adapter.verify_all_consumed! }.not_to raise_error
    end
  end

  describe "#reset!" do
    it "resets the index and call_log" do
      adapter = build_adapter([message_step])
      adapter.chat([])

      adapter.reset!

      expect(adapter.current_index).to eq(0)
      expect(adapter.call_log).to be_empty
      expect(adapter.finished?).to be false
    end

    it "allows replaying the playbook" do
      adapter = build_adapter([message_step])
      r1 = adapter.chat([])
      adapter.reset!
      r2 = adapter.chat([])

      expect(r1.content).to eq(r2.content)
    end
  end
end
