# frozen_string_literal: true

RSpec.describe Dispatch::Adapter::Tester::Step do
  describe "validation" do
    it "parses a valid message step" do
      step = described_class.new("step" => 1, "type" => "message", "content" => "Hello")

      expect(step.step_id).to eq(1)
      expect(step.type).to eq("message")
      expect(step.content).to eq("Hello")
      expect(step).to be_message
      expect(step).not_to be_tool_calls
      expect(step.tool_calls).to be_empty
    end

    it "parses a valid tool_calls step" do
      step = described_class.new(
        "step" => 2,
        "type" => "tool_calls",
        "tool_calls" => [
          { "id" => "tc_001", "name" => "read_file", "arguments" => { "path" => "/a.rb" } }
        ]
      )

      expect(step.step_id).to eq(2)
      expect(step).to be_tool_calls
      expect(step.tool_calls.length).to eq(1)
      expect(step.tool_calls.first["id"]).to eq("tc_001")
    end

    it "allows content on tool_calls steps" do
      step = described_class.new(
        "step" => 3,
        "type" => "tool_calls",
        "content" => "I will do something",
        "tool_calls" => [
          { "id" => "tc_001", "name" => "test", "arguments" => {} }
        ]
      )

      expect(step.content).to eq("I will do something")
    end

    it "is frozen after initialization" do
      step = described_class.new("step" => 1, "type" => "message", "content" => "hi")
      expect(step).to be_frozen
    end

    it "has a useful to_s" do
      step = described_class.new("step" => 42, "type" => "message", "content" => "hi")
      expect(step.to_s).to eq("Step #42 (message)")
    end

    context "missing fields" do
      it "raises when step ID is missing" do
        expect do
          described_class.new("type" => "message", "content" => "hi")
        end.to raise_error(Dispatch::Adapter::Tester::InvalidPlaybookError, /missing required field 'step'/)
      end

      it "raises when step ID is not an integer" do
        expect do
          described_class.new("step" => "one", "type" => "message", "content" => "hi")
        end.to raise_error(Dispatch::Adapter::Tester::InvalidPlaybookError, /must be an integer/)
      end

      it "raises when type is missing" do
        expect do
          described_class.new("step" => 1, "content" => "hi")
        end.to raise_error(Dispatch::Adapter::Tester::InvalidPlaybookError, /missing required field 'type'/)
      end

      it "raises when type is invalid" do
        expect do
          described_class.new("step" => 1, "type" => "invalid", "content" => "hi")
        end.to raise_error(Dispatch::Adapter::Tester::InvalidPlaybookError, /invalid type/)
      end
    end

    context "message step validation" do
      it "raises when content is missing" do
        expect do
          described_class.new("step" => 1, "type" => "message")
        end.to raise_error(Dispatch::Adapter::Tester::InvalidPlaybookError, /requires a non-empty 'content'/)
      end

      it "raises when content is empty string" do
        expect do
          described_class.new("step" => 1, "type" => "message", "content" => "")
        end.to raise_error(Dispatch::Adapter::Tester::InvalidPlaybookError, /requires a non-empty 'content'/)
      end

      it "raises when content is not a string" do
        expect do
          described_class.new("step" => 1, "type" => "message", "content" => 123)
        end.to raise_error(Dispatch::Adapter::Tester::InvalidPlaybookError, /requires a non-empty 'content'/)
      end
    end

    context "tool_calls step validation" do
      it "raises when tool_calls array is missing" do
        expect do
          described_class.new("step" => 1, "type" => "tool_calls")
        end.to raise_error(Dispatch::Adapter::Tester::InvalidPlaybookError, /requires a non-empty 'tool_calls' array/)
      end

      it "raises when tool_calls array is empty" do
        expect do
          described_class.new("step" => 1, "type" => "tool_calls", "tool_calls" => [])
        end.to raise_error(Dispatch::Adapter::Tester::InvalidPlaybookError, /requires a non-empty 'tool_calls' array/)
      end

      it "raises when tool_call is missing 'id'" do
        expect do
          described_class.new(
            "step" => 1, "type" => "tool_calls",
            "tool_calls" => [{ "name" => "test", "arguments" => {} }]
          )
        end.to raise_error(Dispatch::Adapter::Tester::InvalidPlaybookError, /missing required field 'id'/)
      end

      it "raises when tool_call is missing 'name'" do
        expect do
          described_class.new(
            "step" => 1, "type" => "tool_calls",
            "tool_calls" => [{ "id" => "tc_001", "arguments" => {} }]
          )
        end.to raise_error(Dispatch::Adapter::Tester::InvalidPlaybookError, /missing required field 'name'/)
      end

      it "raises when tool_call is missing 'arguments'" do
        expect do
          described_class.new(
            "step" => 1, "type" => "tool_calls",
            "tool_calls" => [{ "id" => "tc_001", "name" => "test" }]
          )
        end.to raise_error(Dispatch::Adapter::Tester::InvalidPlaybookError, /missing required field 'arguments'/)
      end

      it "raises when tool_call 'id' is not a string" do
        expect do
          described_class.new(
            "step" => 1, "type" => "tool_calls",
            "tool_calls" => [{ "id" => 1, "name" => "test", "arguments" => {} }]
          )
        end.to raise_error(Dispatch::Adapter::Tester::InvalidPlaybookError, /'id' must be a string/)
      end

      it "raises when tool_call 'name' is not a string" do
        expect do
          described_class.new(
            "step" => 1, "type" => "tool_calls",
            "tool_calls" => [{ "id" => "tc_001", "name" => 123, "arguments" => {} }]
          )
        end.to raise_error(Dispatch::Adapter::Tester::InvalidPlaybookError, /'name' must be a string/)
      end

      it "raises when tool_call 'arguments' is not a hash" do
        expect do
          described_class.new(
            "step" => 1, "type" => "tool_calls",
            "tool_calls" => [{ "id" => "tc_001", "name" => "test", "arguments" => "bad" }]
          )
        end.to raise_error(Dispatch::Adapter::Tester::InvalidPlaybookError, /'arguments' must be a JSON object/)
      end

      it "raises when tool_call entry is not a hash" do
        expect do
          described_class.new(
            "step" => 1, "type" => "tool_calls",
            "tool_calls" => ["not a hash"]
          )
        end.to raise_error(Dispatch::Adapter::Tester::InvalidPlaybookError, /must be a JSON object/)
      end
    end

    context "non-hash input" do
      it "raises when step data is not a hash" do
        expect do
          described_class.new("just a string")
        end.to raise_error(Dispatch::Adapter::Tester::InvalidPlaybookError, /must be a JSON object/)
      end
    end
  end
end
