# Multi-LLM Adapter Design

## Overview

Extend the existing `LlmAdapter` to support multiple LLM providers (Anthropic, OpenAI, Google Gemini, Ollama, OpenRouter) with a unified interface. All providers communicate via Faraday HTTP client with consistent error handling and timeout behavior.

## Motivation

The current `AnthropicLlmAdapter` is a stub. Before implementing the real API connection, the adapter layer should support provider switching so users can choose the best LLM for their needs (cost, speed, privacy via local Ollama, etc.).

## Scope

**In scope:**
- Refactor `LlmAdapter` into `Llm::` namespace with base class
- Implement 5 provider adapters (Anthropic, OpenAI, Gemini, Ollama, OpenRouter)
- Provider selection via `LLM_PROVIDER` env var
- API key lookup: Rails credentials first, ENV fallback
- Model override via `LLM_MODEL` env var
- Faraday-based HTTP with 30s timeout
- Add `faraday` gem

**Out of scope:**
- Streaming responses
- Token counting / cost tracking
- Retry logic (fallback to InspectionRunner handles failures)
- Provider-specific features (function calling, vision, etc.)

## Architecture

```
LlmAdapter.for
  ├── USE_MOCK=true  → Llm::Mock
  ├── anthropic      → Llm::Anthropic
  ├── openai         → Llm::OpenAi
  ├── gemini         → Llm::Gemini
  ├── ollama         → Llm::Ollama
  └── openrouter     → Llm::OpenRouter
```

## Component Design

### 1. Llm::Base (`app/adapters/llm/base.rb`)

Replaces current `LlmAdapter`. Factory method + shared utilities.

```ruby
module Llm
  class Base
    TIMEOUT_SECONDS = 30

    def self.for
      return Llm::Mock.new if ENV["USE_MOCK"] == "true"

      provider = ENV.fetch("LLM_PROVIDER", "anthropic")
      case provider
      when "anthropic"   then Llm::Anthropic.new
      when "openai"      then Llm::OpenAi.new
      when "gemini"      then Llm::Gemini.new
      when "ollama"      then Llm::Ollama.new
      when "openrouter"  then Llm::OpenRouter.new
      else raise ArgumentError, "Unknown LLM provider: #{provider}"
      end
    end

    def analyze(system:, prompt:)
      raise NotImplementedError
    end

    private

    def api_key(provider_name, env_key)
      Rails.application.credentials.dig(provider_name.to_sym, :api_key) || ENV[env_key]
    end

    def model_name(default)
      ENV.fetch("LLM_MODEL", default)
    end

    def connection(base_url)
      Faraday.new(url: base_url) do |f|
        f.options.timeout = TIMEOUT_SECONDS
        f.options.open_timeout = 10
        f.request :json
        f.response :json
      end
    end

    def sanitize_and_parse_json(raw)
      cleaned = raw.strip
        .gsub(/\A```(?:json)?\s*\n?/, "")
        .gsub(/\n?```\s*\z/, "")
      JSON.parse(cleaned)
    end

    def handle_response(response)
      unless response.success?
        raise "LLM API error (#{response.status}): #{response.body}"
      end
    end
  end
end
```

### 2. Llm::Anthropic (`app/adapters/llm/anthropic.rb`)

```ruby
module Llm
  class Anthropic < Base
    BASE_URL = "https://api.anthropic.com"
    DEFAULT_MODEL = "claude-sonnet-4-20250514"

    def analyze(system:, prompt:)
      key = api_key("anthropic", "ANTHROPIC_API_KEY")
      raise "ANTHROPIC_API_KEY not configured" unless key

      conn = connection(BASE_URL)
      response = conn.post("/v1/messages") do |req|
        req.headers["x-api-key"] = key
        req.headers["anthropic-version"] = "2023-06-01"
        req.body = {
          model: model_name(DEFAULT_MODEL),
          max_tokens: 4096,
          system: system,
          messages: [{ role: "user", content: prompt }]
        }
      end
      handle_response(response)
      sanitize_and_parse_json(response.body["content"][0]["text"])
    end
  end
end
```

### 3. Llm::OpenAi (`app/adapters/llm/openai.rb`)

POST `/v1/chat/completions`. Default model: `gpt-4o-mini`.

### 4. Llm::Gemini (`app/adapters/llm/gemini.rb`)

POST `/v1beta/models/{model}:generateContent` with API key as query param. Default model: `gemini-2.0-flash`.

### 5. Llm::Ollama (`app/adapters/llm/ollama.rb`)

POST `http://localhost:11434/api/chat`. No API key needed. Default model: `llama3.1`. Response format differs — uses `message.content` from response.

### 6. Llm::OpenRouter (`app/adapters/llm/openrouter.rb`)

OpenAI-compatible API at `https://openrouter.ai/api`. Uses `OPENROUTER_API_KEY`. Default model: `anthropic/claude-sonnet-4-20250514`.

### 7. Llm::Mock (`app/adapters/llm/mock.rb`)

Existing `MockLlmAdapter` moved to namespace. No behavioral change.

## Configuration

### Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `USE_MOCK` | Use mock adapter | `true` |
| `LLM_PROVIDER` | Provider selection | `anthropic` |
| `LLM_MODEL` | Model override | Provider-specific default |
| `ANTHROPIC_API_KEY` | Anthropic API key | — |
| `OPENAI_API_KEY` | OpenAI API key | — |
| `GEMINI_API_KEY` | Google Gemini API key | — |
| `OPENROUTER_API_KEY` | OpenRouter API key | — |
| `OLLAMA_BASE_URL` | Ollama server URL | `http://localhost:11434` |

### Rails Credentials (priority over ENV)

```yaml
anthropic:
  api_key: sk-ant-xxx
openai:
  api_key: sk-xxx
gemini:
  api_key: AIza-xxx
openrouter:
  api_key: sk-or-xxx
```

## Migration Plan

- Rename `LlmAdapter` → `Llm::Base`
- Rename `MockLlmAdapter` → `Llm::Mock`
- Rename `AnthropicLlmAdapter` → `Llm::Anthropic`
- Update `AiInspectionRunner` to use `Llm::Base.for`
- Keep backward compatibility alias `LlmAdapter = Llm::Base` temporarily
- Update all tests

## File Structure

```
app/adapters/
  llm/
    base.rb           # Factory + shared utilities (was llm_adapter.rb)
    mock.rb           # Fixture-based (was mock_llm_adapter.rb)
    anthropic.rb      # Claude API (was anthropic_llm_adapter.rb)
    openai.rb         # GPT API (new)
    gemini.rb         # Gemini API (new)
    ollama.rb         # Local Ollama (new)
    open_router.rb    # OpenRouter API (new)
  llm_adapter.rb      # DELETE (moved to llm/base.rb)
  mock_llm_adapter.rb # DELETE (moved to llm/mock.rb)
  anthropic_llm_adapter.rb # DELETE (moved to llm/anthropic.rb)
```

## Testing Strategy

- Unit test each adapter with WebMock stubs for HTTP calls
- Test factory method with all provider values
- Test credential lookup priority (credentials > ENV)
- Test timeout and error handling
- Integration test unchanged (MockLlmAdapter behavior preserved)
