# frozen_string_literal: true

module Dispatch
  module Adapter
    module Tester
      class Error < StandardError; end

      # Raised when the playbook JSON schema is invalid
      class InvalidPlaybookError < Error; end

      # Raised when chat is called but no more steps remain
      class PlaybookExhaustedError < Error
        attr_reader :total_steps, :calls_made

        def initialize(total_steps:, calls_made:)
          @total_steps = total_steps
          @calls_made = calls_made
          super(
            "Playbook exhausted: all #{total_steps} steps have been consumed, " \
            "but chat was called a #{ordinalize(calls_made)} time"
          )
        end

        private

        def ordinalize(n)
          suffix = case n % 100
                   when 11, 12, 13 then "th"
                   else
                     case n % 10
                     when 1 then "st"
                     when 2 then "nd"
                     when 3 then "rd"
                     else "th"
                     end
                   end
          "#{n}#{suffix}"
        end
      end

      # Raised when not all steps were consumed after a test run
      class UnconsumedStepsError < Error
        attr_reader :total_steps, :consumed, :remaining_step_ids

        def initialize(total_steps:, consumed:, remaining_step_ids:)
          @total_steps = total_steps
          @consumed = consumed
          @remaining_step_ids = remaining_step_ids
          super(
            "Playbook has unconsumed steps: #{consumed}/#{total_steps} steps consumed. " \
            "Remaining steps: #{remaining_step_ids.inspect}"
          )
        end
      end
    end
  end
end
