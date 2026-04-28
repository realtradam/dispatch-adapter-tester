# frozen_string_literal: true

RSpec.describe Dispatch::Adapter::Tester do
  describe "error hierarchy" do
    it "Error inherits from StandardError" do
      expect(Dispatch::Adapter::Tester::Error.superclass).to eq(StandardError)
    end

    it "InvalidPlaybookError inherits from Error" do
      expect(Dispatch::Adapter::Tester::InvalidPlaybookError.superclass).to eq(Dispatch::Adapter::Tester::Error)
    end

    it "PlaybookExhaustedError inherits from Error" do
      expect(Dispatch::Adapter::Tester::PlaybookExhaustedError.superclass).to eq(Dispatch::Adapter::Tester::Error)
    end

    it "UnconsumedStepsError inherits from Error" do
      expect(Dispatch::Adapter::Tester::UnconsumedStepsError.superclass).to eq(Dispatch::Adapter::Tester::Error)
    end
  end

  describe Dispatch::Adapter::Tester::PlaybookExhaustedError do
    it "includes step details in the message" do
      error = described_class.new(total_steps: 3, calls_made: 4)

      expect(error.total_steps).to eq(3)
      expect(error.calls_made).to eq(4)
      expect(error.message).to include("all 3 steps")
      expect(error.message).to include("4th time")
    end

    it "handles ordinal suffixes correctly" do
      expect(described_class.new(total_steps: 1, calls_made: 1).message).to include("1st")
      expect(described_class.new(total_steps: 1, calls_made: 2).message).to include("2nd")
      expect(described_class.new(total_steps: 1, calls_made: 3).message).to include("3rd")
      expect(described_class.new(total_steps: 1, calls_made: 11).message).to include("11th")
      expect(described_class.new(total_steps: 1, calls_made: 12).message).to include("12th")
      expect(described_class.new(total_steps: 1, calls_made: 13).message).to include("13th")
      expect(described_class.new(total_steps: 1, calls_made: 21).message).to include("21st")
    end
  end

  describe Dispatch::Adapter::Tester::UnconsumedStepsError do
    it "includes remaining step details in the message" do
      error = described_class.new(total_steps: 5, consumed: 2, remaining_step_ids: [3, 4, 5])

      expect(error.total_steps).to eq(5)
      expect(error.consumed).to eq(2)
      expect(error.remaining_step_ids).to eq([3, 4, 5])
      expect(error.message).to include("2/5 steps consumed")
      expect(error.message).to include("[3, 4, 5]")
    end
  end
end
