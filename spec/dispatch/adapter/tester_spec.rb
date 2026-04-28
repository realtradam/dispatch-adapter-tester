# frozen_string_literal: true

RSpec.describe Dispatch::Adapter::Tester do
  it "has a version number" do
    expect(Dispatch::Adapter::Tester::VERSION).not_to be_nil
  end

  it "exposes the Playbook class" do
    expect(Dispatch::Adapter::Tester::Playbook).to be_a(Class)
  end

  it "exposes the Step class" do
    expect(Dispatch::Adapter::Tester::Step).to be_a(Class)
  end

  it "exposes error classes" do
    expect(Dispatch::Adapter::Tester::Error).to be < StandardError
    expect(Dispatch::Adapter::Tester::InvalidPlaybookError).to be < Dispatch::Adapter::Tester::Error
    expect(Dispatch::Adapter::Tester::PlaybookExhaustedError).to be < Dispatch::Adapter::Tester::Error
    expect(Dispatch::Adapter::Tester::UnconsumedStepsError).to be < Dispatch::Adapter::Tester::Error
  end
end
