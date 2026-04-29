# frozen_string_literal: true

RSpec.describe Dispatch::Adapter::Tester::Playbooks::Claude do
  # Helper: builds a Playbook adapter from the steps returned by a playbook method.
  def build_adapter(steps)
    Dispatch::Adapter::Tester::Playbook.new(steps_json: steps)
  end

  def user_message(text)
    Dispatch::Adapter::Message.new(
      role: "user",
      content: [Dispatch::Adapter::TextBlock.new(text: text)]
    )
  end

  # ---------------------------------------------------------------------------
  # Discoverability
  # ---------------------------------------------------------------------------

  describe ".all" do
    it "returns a Hash with all six scenario keys" do
      all = described_class.all
      expect(all).to be_a(Hash)
      expect(all.keys).to contain_exactly(
        :smoke_text, :smoke_tool_use, :smoke_thinking,
        :smoke_usage, :smoke_pricing, :smoke_cache
      )
    end

    it "each value is a non-empty Array" do
      described_class.all.each do |name, steps|
        expect(steps).to be_an(Array), "Expected #{name} to return an Array"
        expect(steps).not_to be_empty, "Expected #{name} steps to be non-empty"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # smoke_text — single-turn "Say hi"
  # ---------------------------------------------------------------------------

  describe ".smoke_text" do
    let(:steps) { described_class.smoke_text }

    it "returns a one-step Array" do
      expect(steps.length).to eq(1)
    end

    it "produces a non-empty text response with stop_reason :end_turn" do
      adapter = build_adapter(steps)
      resp = adapter.chat([user_message("Say hi")])

      expect(resp).to be_a(Dispatch::Adapter::Response)
      expect(resp.stop_reason).to eq(:end_turn)
      expect(resp.content).to be_a(String)
      expect(resp.content).not_to be_empty
    end
  end

  # ---------------------------------------------------------------------------
  # smoke_tool_use — register `add`, ask "What is 2+3?"
  # ---------------------------------------------------------------------------

  describe ".smoke_tool_use" do
    let(:steps) { described_class.smoke_tool_use }

    it "returns a one-step Array" do
      expect(steps.length).to eq(1)
    end

    it "produces stop_reason :tool_use" do
      adapter = build_adapter(steps)
      resp = adapter.chat([user_message("What is 2+3?")])

      expect(resp.stop_reason).to eq(:tool_use)
    end

    it "emits an `add` tool call with a==2 and b==3" do
      adapter = build_adapter(steps)
      resp = adapter.chat([user_message("What is 2+3?")])

      tc = resp.tool_calls.find { |t| t.name == "add" }
      expect(tc).not_to be_nil, "Expected an 'add' tool call"
      expect(tc.arguments["a"]).to eq(2)
      expect(tc.arguments["b"]).to eq(3)
    end

    it "tool call has a non-empty id" do
      adapter = build_adapter(steps)
      resp = adapter.chat([user_message("What is 2+3?")])

      tc = resp.tool_calls.find { |t| t.name == "add" }
      expect(tc.id).to be_a(String)
      expect(tc.id).not_to be_empty
    end
  end

  # ---------------------------------------------------------------------------
  # smoke_thinking — thinking-enabled request (tester mode)
  # ---------------------------------------------------------------------------

  describe ".smoke_thinking" do
    let(:steps) { described_class.smoke_thinking }

    it "returns a one-step Array" do
      expect(steps.length).to eq(1)
    end

    it "produces a non-empty text response (tester mode — thinking reflected in content)" do
      adapter = build_adapter(steps)
      resp = adapter.chat([user_message("Think carefully about 42")], thinking: "high")

      expect(resp.stop_reason).to eq(:end_turn)
      expect(resp.content).to be_a(String)
      expect(resp.content).not_to be_empty
    end

    it "records the thinking parameter in the call log" do
      adapter = build_adapter(steps)
      adapter.chat([user_message("Think carefully about 42")], thinking: "high")

      expect(adapter.call_log.first[:thinking]).to eq("high")
    end
  end

  # ---------------------------------------------------------------------------
  # smoke_usage — usage_report placeholder
  # ---------------------------------------------------------------------------

  describe ".smoke_usage" do
    let(:steps) { described_class.smoke_usage }

    it "returns a one-step Array" do
      expect(steps.length).to eq(1)
    end

    it "produces a non-empty text response (tester mode placeholder)" do
      adapter = build_adapter(steps)
      resp = adapter.chat([user_message("usage check")])

      expect(resp.stop_reason).to eq(:end_turn)
      expect(resp.content).to be_a(String)
      expect(resp.content).not_to be_empty
    end
  end

  # ---------------------------------------------------------------------------
  # smoke_pricing — cost.total > 0 in live mode; tester returns zeroed Usage
  # ---------------------------------------------------------------------------

  describe ".smoke_pricing" do
    let(:steps) { described_class.smoke_pricing }

    it "returns a one-step Array" do
      expect(steps.length).to eq(1)
    end

    it "produces a valid Response (tester mode — usage tokens are 0)" do
      adapter = build_adapter(steps)
      resp = adapter.chat([user_message("Hello")])

      expect(resp.stop_reason).to eq(:end_turn)
      expect(resp.content).not_to be_empty
      expect(resp.usage).to be_a(Dispatch::Adapter::Usage)
      expect(resp.usage.input_tokens).to eq(0)
      expect(resp.usage.output_tokens).to eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  # smoke_cache — two identical calls; second should cache in live mode
  # ---------------------------------------------------------------------------

  describe ".smoke_cache" do
    let(:steps) { described_class.smoke_cache }

    it "returns a two-step Array" do
      expect(steps.length).to eq(2)
    end

    it "produces two sequential responses from the playbook" do
      adapter = build_adapter(steps)

      resp1 = adapter.chat([user_message("Hello")])
      resp2 = adapter.chat([user_message("Hello")])

      expect(resp1.stop_reason).to eq(:end_turn)
      expect(resp1.content).not_to be_empty

      expect(resp2.stop_reason).to eq(:end_turn)
      expect(resp2.content).not_to be_empty
    end

    it "exhausts all steps after two calls" do
      adapter = build_adapter(steps)
      adapter.chat([user_message("Hello")])
      adapter.chat([user_message("Hello")])

      expect(adapter).to be_finished
      expect { adapter.verify_all_consumed! }.not_to raise_error
    end
  end

  # ---------------------------------------------------------------------------
  # Integration: each scenario builds a valid Playbook without errors
  # ---------------------------------------------------------------------------

  describe "all scenarios build valid Playbooks" do
    described_class.all.each do |name, steps|
      it "#{name} steps are valid Playbook JSON" do
        expect { Dispatch::Adapter::Tester::Playbook.new(steps_json: steps) }.not_to raise_error
      end
    end
  end
end
