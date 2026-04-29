# frozen_string_literal: true

require "dispatch/adapter/interface"

require_relative "tester/version"
require_relative "tester/errors"
require_relative "tester/step"
require_relative "tester/playbook"
require_relative "tester/playbooks/claude"

module Dispatch
  module Adapter
    module Tester
    end
  end
end
