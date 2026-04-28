# App Integration Requirements

This document describes the changes required in the main `dispatch-api` application
to support `dispatch-adapter-tester` as a drop-in replacement for
`dispatch-adapter-copilot`.

---

## 1. Make the Adapter Class Configurable

`AgentJob#build_adapter` currently hardcodes `Dispatch::Adapter::Copilot`. This needs
to be changed so the adapter class is resolved dynamically — either from a
configuration setting, an environment variable, or a method that can be overridden
in the test environment.

The tester adapter's class is `Dispatch::Adapter::Tester::Playbook`. It accepts the
same constructor keyword arguments as `Copilot` (model, max_tokens,
min_request_interval, rate_limit) and silently absorbs any it does not use.

---

## 2. Add the Gem to the Gemfile

The gem needs to be added to the application's `Gemfile`, scoped to the test group,
with a local path reference.

---

## 3. Provide a Way to Pass the Playbook Script (Per-Agent)

The `Playbook` adapter requires a `steps_json:` keyword argument containing the JSON
script. Each agent instance needs its **own** playbook — multiple agents running
concurrently will each have independent `Playbook` instances with separate step
lists, indices, and call logs.

The app's adapter construction path needs a per-agent mechanism to supply the
playbook JSON. Some approaches:

- An attribute on the `Agent` model (e.g. `playbook_json`) that is only populated
  in the test environment.
- A test helper registry keyed by agent ID that maps each agent to its playbook.
- A factory/fixture that associates a playbook with each agent before the test runs.

The chosen mechanism must ensure that when `build_adapter` constructs a `Playbook`
for agent A, it receives agent A's script — not agent B's.

---

## 4. No Changes to the Agent Loop

The agent loop (`AgentJob#run_loop`) does **not** need any changes. The `Playbook`
adapter returns the same `Dispatch::Adapter::Response` struct with the same fields
(`content`, `tool_calls`, `model`, `stop_reason`, `usage`), so the existing loop
logic will work unmodified.

---

## 5. Test Verification Helpers

After a test run, call `adapter.verify_all_consumed!` to assert that the full
playbook script was exercised. This raises
`Dispatch::Adapter::Tester::UnconsumedStepsError` if any steps were not consumed,
which helps catch cases where the agent loop exited early unexpectedly.

The `adapter.call_log` array can also be inspected to verify what messages, system
prompts, and tools were passed to each `chat` call.
