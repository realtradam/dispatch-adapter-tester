# frozen_string_literal: true

require "json"

module Dispatch
  module Adapter
    module Tester
      # A deterministic, scriptable adapter for integration testing.
      #
      # Playbook is a drop-in replacement for Dispatch::Adapter::Copilot.
      # Instead of calling a real LLM API, it replays a pre-defined sequence
      # of steps from a JSON script. Each call to #chat consumes the next step
      # and returns a Dispatch::Adapter::Response built from it.
      #
      # Usage:
      #   steps_json = '[{"step":1,"type":"message","content":"Hello"}]'
      #   adapter = Dispatch::Adapter::Tester::Playbook.new(steps_json: steps_json)
      #   response = adapter.chat(messages, system: "...", tools: [...])
      #   response.content  # => "Hello"
      #
      class Playbook < Dispatch::Adapter::Base
        MODEL_NAME = "tester-playbook"
        PROVIDER_NAME = "Tester Playbook"
        MAX_CONTEXT_TOKENS = 1_000_000

        attr_reader :steps, :current_index, :call_log

        # @param steps_json [String] JSON string containing an array of step objects
        # @param model [String] model name to report (default: "tester-playbook")
        # @param max_tokens [Integer] reported max tokens (unused, for interface compat)
        # @param kwargs [Hash] absorbs any extra keyword arguments for drop-in compat
        #   (e.g. min_request_interval, rate_limit, etc.)
        def initialize(steps_json: "[]", model: MODEL_NAME, max_tokens: 200_000, **_kwargs)
          super()
          @model = model
          @max_tokens = max_tokens
          @steps = parse_steps(steps_json)
          @current_index = 0
          @call_log = []
          @mutex = Mutex.new

          validate_step_ids_unique!
        end

        # Consume the next step and return a Response.
        #
        # Accepts the same signature as Dispatch::Adapter::Base#chat.
        # The messages, system, tools, stream, max_tokens, and thinking
        # parameters are recorded in the call_log for assertion purposes
        # but do not affect the response (which is entirely driven by the script).
        #
        # @return [Dispatch::Adapter::Response]
        def chat(messages, system: nil, tools: [], stream: false, max_tokens: nil, thinking: nil, &_block)
          @mutex.synchronize do
            if @current_index >= @steps.length
              raise PlaybookExhaustedError.new(
                total_steps: @steps.length,
                calls_made: @current_index + 1
              )
            end

            step = @steps[@current_index]
            @current_index += 1

            @call_log << {
              step: step,
              messages: messages,
              system: system,
              tools: tools,
              stream: stream,
              max_tokens: max_tokens,
              thinking: thinking
            }

            build_response_from_step(step)
          end
        end

        def model_name
          @model
        end

        def provider_name
          PROVIDER_NAME
        end

        def max_context_tokens
          MAX_CONTEXT_TOKENS
        end

        def list_models
          [
            Dispatch::Adapter::ModelInfo.new(
              id: MODEL_NAME,
              name: "Tester Playbook",
              max_context_tokens: MAX_CONTEXT_TOKENS,
              supports_vision: false,
              supports_tool_use: true,
              supports_streaming: false
            )
          ]
        end

        # --- Test helper methods ---

        # Check if all steps have been consumed.
        # @return [Boolean]
        def finished?
          @current_index >= @steps.length
        end

        # Returns the number of remaining unconsumed steps.
        # @return [Integer]
        def remaining_steps
          @steps.length - @current_index
        end

        # Raises UnconsumedStepsError if there are steps left.
        # Call this at the end of a test to ensure the full script was exercised.
        def verify_all_consumed!
          return if finished?

          remaining_ids = @steps[@current_index..].map(&:step_id)
          raise UnconsumedStepsError.new(
            total_steps: @steps.length,
            consumed: @current_index,
            remaining_step_ids: remaining_ids
          )
        end

        # Resets the playbook to the beginning.
        # Useful if you need to replay the same script.
        def reset!
          @mutex.synchronize do
            @current_index = 0
            @call_log.clear
          end
        end

        private

        def parse_steps(steps_json)
          raw = if steps_json.is_a?(String)
                  parsed = JSON.parse(steps_json)
                  unless parsed.is_a?(Array)
                    raise InvalidPlaybookError, "Playbook JSON must be an array, got #{parsed.class}"
                  end

                  parsed
                elsif steps_json.is_a?(Array)
                  steps_json
                else
                  raise InvalidPlaybookError,
                        "steps_json must be a JSON string or Array, got #{steps_json.class}"
                end

          raw.map { |data| Step.new(data) }
        rescue JSON::ParserError => e
          raise InvalidPlaybookError, "Failed to parse playbook JSON: #{e.message}"
        end

        def validate_step_ids_unique!
          ids = @steps.map(&:step_id)
          duplicates = ids.group_by(&:itself).select { |_, v| v.size > 1 }.keys
          return if duplicates.empty?

          raise InvalidPlaybookError,
                "Duplicate step IDs found: #{duplicates.inspect}. Each step must have a unique 'step' value."
        end

        def build_response_from_step(step)
          tool_calls = step.tool_calls.map do |tc|
            Dispatch::Adapter::ToolUseBlock.new(
              id: tc["id"],
              name: tc["name"],
              arguments: tc["arguments"]
            )
          end

          stop_reason = tool_calls.any? ? :tool_use : :end_turn

          Dispatch::Adapter::Response.new(
            content: step.content,
            tool_calls: tool_calls,
            model: @model,
            stop_reason: stop_reason,
            usage: Dispatch::Adapter::Usage.new(
              input_tokens: 0,
              output_tokens: 0
            )
          )
        end
      end
    end
  end
end
