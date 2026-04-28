# frozen_string_literal: true

module Dispatch
  module Adapter
    module Tester
      # Immutable value object representing a single step in a playbook.
      # Validated at parse time so errors surface early.
      class Step
        VALID_TYPES = %w[message tool_calls].freeze

        attr_reader :step_id, :type, :content, :tool_calls

        def initialize(data)
          validate_and_assign!(data)
          freeze
        end

        def message?
          @type == "message"
        end

        def tool_calls?
          @type == "tool_calls"
        end

        def to_s
          "Step ##{@step_id} (#{@type})"
        end

        private

        def validate_and_assign!(data)
          validate_hash!(data)
          @step_id = extract_step_id!(data)
          @type = extract_type!(data)
          @content = data["content"]

          if tool_calls?
            @tool_calls = extract_tool_calls!(data)
          else
            @tool_calls = []
            validate_message_has_content!
          end
        end

        def validate_hash!(data)
          return if data.is_a?(Hash)

          raise InvalidPlaybookError, "Each step must be a JSON object, got #{data.class}"
        end

        def extract_step_id!(data)
          step_id = data["step"]
          raise InvalidPlaybookError, "Step is missing required field 'step'" if step_id.nil?
          unless step_id.is_a?(Integer)
            raise InvalidPlaybookError, "Step 'step' field must be an integer, got #{step_id.inspect}"
          end

          step_id
        end

        def extract_type!(data)
          type = data["type"]
          raise InvalidPlaybookError, "Step ##{@step_id} is missing required field 'type'" if type.nil?
          unless VALID_TYPES.include?(type)
            raise InvalidPlaybookError,
                  "Step ##{@step_id} has invalid type #{type.inspect}. " \
                  "Must be one of: #{VALID_TYPES.join(", ")}"
          end
          type
        end

        def extract_tool_calls!(data)
          raw = data["tool_calls"]
          if raw.nil? || !raw.is_a?(Array) || raw.empty?
            raise InvalidPlaybookError,
                  "Step ##{@step_id} (tool_calls) requires a non-empty 'tool_calls' array"
          end

          raw.map.with_index do |tc, idx|
            validate_tool_call!(tc, idx)
          end
        end

        def validate_tool_call!(tc, idx)
          unless tc.is_a?(Hash)
            raise InvalidPlaybookError,
                  "Step ##{@step_id}, tool_call[#{idx}] must be a JSON object"
          end

          %w[id name arguments].each do |field|
            if tc[field].nil?
              raise InvalidPlaybookError,
                    "Step ##{@step_id}, tool_call[#{idx}] is missing required field '#{field}'"
            end
          end

          unless tc["id"].is_a?(String)
            raise InvalidPlaybookError,
                  "Step ##{@step_id}, tool_call[#{idx}] 'id' must be a string"
          end

          unless tc["name"].is_a?(String)
            raise InvalidPlaybookError,
                  "Step ##{@step_id}, tool_call[#{idx}] 'name' must be a string"
          end

          unless tc["arguments"].is_a?(Hash)
            raise InvalidPlaybookError,
                  "Step ##{@step_id}, tool_call[#{idx}] 'arguments' must be a JSON object"
          end

          tc
        end

        def validate_message_has_content!
          return if @content.is_a?(String) && !@content.empty?

          raise InvalidPlaybookError,
                "Step ##{@step_id} (message) requires a non-empty 'content' string"
        end
      end
    end
  end
end
