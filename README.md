# dispatch-adapter-tester

A deterministic playbook adapter for integration testing Dispatch agent flows.

`dispatch-adapter-tester` is a drop-in replacement for `dispatch-adapter-copilot`
that replays a scripted JSON sequence of AI responses, enabling deterministic
end-to-end testing of the full agent loop without calling any real LLM API.

## Installation

Add to your Gemfile (test group):

```ruby
group :test do
  gem "dispatch-adapter-tester", path: "reference/dispatch-adapter-tester"
end
```

## Usage

### Define a Playbook

A playbook is a JSON array of steps. Each step represents one response from the
fake AI:

```json
[
  {
    "step": 1,
    "type": "message",
    "content": "I will read the file now."
  },
  {
    "step": 2,
    "type": "tool_calls",
    "content": null,
    "tool_calls": [
      {
        "id": "tc_read_001",
        "name": "read_file",
        "arguments": { "path": "/some/file.rb" }
      }
    ]
  },
  {
    "step": 3,
    "type": "message",
    "content": "The file contains a Ruby class."
  }
]
```

### Step Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `step` | integer | yes | Unique step identifier for debug output |
| `type` | string | yes | `"message"` or `"tool_calls"` |
| `content` | string/null | yes for message, optional for tool_calls | Text content of the response |
| `tool_calls` | array | yes for tool_calls | Array of tool call objects |

Each tool call object:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Tool call ID (for tracing/debugging) |
| `name` | string | yes | Name of the tool to invoke |
| `arguments` | object | yes | Arguments to pass to the tool |

### Create the Adapter

```ruby
adapter = Dispatch::Adapter::Tester::Playbook.new(
  steps_json: steps_json,  # JSON string or Ruby array
  model: "gpt-4",          # optional, for interface compat
  max_tokens: 200_000,     # optional, absorbed but unused
  min_request_interval: 0, # optional, absorbed but unused
  rate_limit: nil           # optional, absorbed but unused
)
```

### Use in Tests

```ruby
# Each call to chat consumes the next step
response = adapter.chat(messages, system: system_prompt, tools: registry.to_a)

# After the test, verify all steps were consumed
adapter.verify_all_consumed!

# Inspect what was passed to each chat call
adapter.call_log.each do |entry|
  puts entry[:step]     # the Step object
  puts entry[:system]   # system prompt passed
  puts entry[:messages] # messages array passed
  puts entry[:tools]    # tools array passed
end
```

### Test Helpers

| Method | Description |
|--------|-------------|
| `finished?` | Returns true when all steps have been consumed |
| `remaining_steps` | Number of unconsumed steps |
| `verify_all_consumed!` | Raises `UnconsumedStepsError` if steps remain |
| `reset!` | Resets to step 0 and clears the call log |
| `call_log` | Array of recorded chat call details |
| `current_index` | Current position in the playbook |

### Error Types

| Error | When |
|-------|------|
| `InvalidPlaybookError` | Malformed JSON, missing fields, invalid types |
| `PlaybookExhaustedError` | `chat` called after all steps consumed |
| `UnconsumedStepsError` | `verify_all_consumed!` called with steps remaining |

All errors include step IDs for debugging.

## See Also

- `APP_INTEGRATION.md` — Required changes in the host application
- `dispatch-adapter-copilot` — The real adapter this replaces
