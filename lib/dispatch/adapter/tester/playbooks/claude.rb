# frozen_string_literal: true

module Dispatch
  module Adapter
    module Tester
      module Playbooks
        # Pre-built playbook scripts for smoke-testing against the Claude adapter.
        #
        # This module provides scripted step sequences that mimic realistic Claude
        # API responses for six common scenarios. Each method returns a plain Ruby
        # Array of step hashes suitable for passing directly to
        # `Dispatch::Adapter::Tester::Playbook.new(steps_json: ...)`.
        #
        # ## Usage (recorded / CI mode)
        #
        # Use any playbook method to create a deterministic Playbook adapter:
        #
        #   steps   = Dispatch::Adapter::Tester::Playbooks::Claude.smoke_text
        #   adapter = Dispatch::Adapter::Tester::Playbook.new(steps_json: steps)
        #   msgs    = [Dispatch::Adapter::Message.new(role: "user",
        #                content: [Dispatch::Adapter::TextBlock.new(text: "Say hi")])]
        #   resp = adapter.chat(msgs)
        #   raise "unexpected stop_reason" unless resp.stop_reason == :end_turn
        #   raise "empty content" if resp.content.to_s.empty?
        #
        # ## Usage (live mode against the real Claude API)
        #
        # To run the same scenarios against the real Claude adapter, substitute
        # `Dispatch::Adapter::Tester::Playbook` with `Dispatch::Adapter::Claude`:
        #
        #   require "dispatch/adapter/claude"
        #   require "dispatch/adapter/tester/playbooks/claude"
        #
        #   adapter = Dispatch::Adapter::Claude.new(
        #     model:   "claude-sonnet-4-5-20250929",
        #     api_key: ENV.fetch("ANTHROPIC_API_KEY"),
        #     min_request_interval: 1.0
        #   )
        #
        #   # smoke_text
        #   msgs = [Dispatch::Adapter::Message.new(
        #     role: "user",
        #     content: [Dispatch::Adapter::TextBlock.new(text: "Say hi")]
        #   )]
        #   resp = adapter.chat(msgs)
        #   raise unless resp.stop_reason == :end_turn
        #   raise if resp.content.to_s.empty?
        #
        #   # smoke_tool_use
        #   add_tool = Dispatch::Adapter::ToolDefinition.new(
        #     name: "add",
        #     description: "Returns the sum of two numbers",
        #     parameters: { type: "object",
        #                   properties: { a: { type: "integer" }, b: { type: "integer" } },
        #                   required: %w[a b] }
        #   )
        #   msgs = [Dispatch::Adapter::Message.new(
        #     role: "user",
        #     content: [Dispatch::Adapter::TextBlock.new(text: "What is 2+3?")]
        #   )]
        #   resp = adapter.chat(msgs, tools: [add_tool])
        #   raise unless resp.stop_reason == :tool_use
        #   tc = resp.tool_calls.find { |t| t.name == "add" }
        #   raise "expected add tool call" unless tc
        #   raise unless tc.arguments["a"] == 2 && tc.arguments["b"] == 3
        #
        #   # smoke_thinking — requires Opus 4.7+ with thinking enabled
        #   msgs = [Dispatch::Adapter::Message.new(
        #     role: "user",
        #     content: [Dispatch::Adapter::TextBlock.new(text: "Think carefully about 42")]
        #   )]
        #   resp = adapter.chat(msgs, thinking: "high",
        #                       max_tokens: 16_000,
        #                       # Use Opus 4.7 for adaptive thinking:
        #                       # Dispatch::Adapter::Claude.new(model: "claude-opus-4-7", ...)
        #                       )
        #   raise unless resp.content.any? { |c| c.is_a?(Dispatch::Adapter::ThinkingBlock) }
        #
        #   # smoke_usage — OAuth only
        #   # adapter = Dispatch::Adapter::Claude.new(token_path: "~/.config/dispatch/claude_oauth.json")
        #   # report = adapter.usage_report
        #   # raise unless report.limits.any? { |e| e.id == "anthropic:5h" }
        #
        #   # smoke_pricing
        #   msgs = [Dispatch::Adapter::Message.new(
        #     role: "user",
        #     content: [Dispatch::Adapter::TextBlock.new(text: "Hello")]
        #   )]
        #   resp = adapter.chat(msgs)
        #   raise unless resp.usage.cost.total > 0
        #
        #   # smoke_cache — run the same request twice within 5 minutes
        #   resp2 = adapter.chat(msgs, cache_retention: :short)
        #   raise if resp2.usage.cache_read_tokens.to_i == 0
        #
        module Claude
          # Scripted response for a simple "Say hi" text request.
          #
          # Expected adapter behaviour:
          #   - stop_reason == :end_turn
          #   - content (string) is non-empty
          #
          # @return [Array<Hash>] steps array for Playbook
          def self.smoke_text
            [
              {
                "step" => 1,
                "type" => "message",
                "content" => "Hi there! How can I help you today?"
              }
            ]
          end

          # Scripted response for tool-use with an `add` function.
          #
          # Expected adapter behaviour:
          #   - stop_reason == :tool_use
          #   - tool_calls contains one entry with name "add"
          #   - arguments["a"] == 2, arguments["b"] == 3
          #
          # @return [Array<Hash>] steps array for Playbook
          def self.smoke_tool_use
            [
              {
                "step" => 1,
                "type" => "tool_calls",
                "content" => nil,
                "tool_calls" => [
                  {
                    "id" => "toolu_smoke_add_01",
                    "name" => "add",
                    "arguments" => { "a" => 2, "b" => 3 }
                  }
                ]
              }
            ]
          end

          # Scripted response for a thinking-enabled request.
          #
          # In the recorded (tester) mode, the "ThinkingBlock" is represented
          # as a synthetic message confirming thinking was requested.
          # In live mode, use claude-opus-4-7 with thinking: "high".
          #
          # Expected adapter behaviour (tester mode):
          #   - stop_reason == :end_turn
          #   - content is non-empty
          #
          # Expected adapter behaviour (live mode, Opus 4.7+ with thinking):
          #   - stop_reason == :end_turn
          #   - Response.content includes at least one ThinkingBlock
          #
          # @return [Array<Hash>] steps array for Playbook
          def self.smoke_thinking
            [
              {
                "step" => 1,
                "type" => "message",
                "content" => "[thinking] The number 42 is the answer to life, the universe, and everything."
              }
            ]
          end

          # Scripted response for usage_report (OAuth mode).
          #
          # In tester mode, usage_report is not driven by the Playbook (it is a
          # separate API call). This step collection is a placeholder that confirms
          # a text response is returned; live tests must use an OAuth-authenticated
          # Claude adapter and call adapter.usage_report directly.
          #
          # Expected adapter behaviour (live OAuth mode):
          #   - usage_report returns a UsageReport
          #   - limits.any? { |e| e.id == "anthropic:5h" }
          #
          # @return [Array<Hash>] steps array for Playbook
          def self.smoke_usage
            [
              {
                "step" => 1,
                "type" => "message",
                "content" => "Usage report smoke test placeholder."
              }
            ]
          end

          # Scripted response for verifying that pricing is calculated.
          #
          # In tester mode the Usage struct has 0 tokens and nil cost.
          # Live mode asserts response.usage.cost.total > 0.
          #
          # @return [Array<Hash>] steps array for Playbook
          def self.smoke_pricing
            [
              {
                "step" => 1,
                "type" => "message",
                "content" => "Hello!"
              }
            ]
          end

          # Scripted response for cache smoke test.
          #
          # Two identical calls with cache_retention: :short should result in
          # cache_read_tokens > 0 on the second call when using the real adapter.
          # In tester mode, both calls are separate steps with identical content.
          #
          # @return [Array<Hash>] steps array for Playbook (two identical steps)
          def self.smoke_cache
            [
              {
                "step" => 1,
                "type" => "message",
                "content" => "Hello! (first call)"
              },
              {
                "step" => 2,
                "type" => "message",
                "content" => "Hello! (second call — cache hit expected in live mode)"
              }
            ]
          end

          # Returns all six scenarios as a Hash keyed by scenario name.
          #
          # Useful for iterating over all smoke scenarios:
          #
          #   Dispatch::Adapter::Tester::Playbooks::Claude.all.each do |name, steps|
          #     adapter = Dispatch::Adapter::Tester::Playbook.new(steps_json: steps)
          #     # run scenario named `name`
          #   end
          #
          # @return [Hash<Symbol, Array<Hash>>]
          def self.all
            {
              smoke_text: smoke_text,
              smoke_tool_use: smoke_tool_use,
              smoke_thinking: smoke_thinking,
              smoke_usage: smoke_usage,
              smoke_pricing: smoke_pricing,
              smoke_cache: smoke_cache
            }
          end
        end
      end
    end
  end
end
