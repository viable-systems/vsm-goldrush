# VsmGoldrush

A high-performance VSM-aware wrapper for the [goldrush](https://github.com/DeadZen/goldrush) Erlang event processing library. This library provides compiled query patterns for detecting cybernetic failures in Viable System Model implementations.

## Key Features

- **Compiled Queries**: Patterns are compiled to BEAM bytecode for maximum performance
- **VSM Cybernetic Patterns**: Pre-defined patterns for variety explosion, channel saturation, algedonic signals, etc.
- **Native Goldrush Integration**: Actually uses goldrush's query compilation engine
- **Built-in Statistics**: Track pattern matches, misses, and performance
- **Event Format Conversion**: Seamless conversion between Elixir maps and goldrush events

## Installation

Add `vsm_goldrush` to your dependencies:

```elixir
def deps do
  [
    {:vsm_goldrush, "~> 0.1.0", organization: "viable_systems"}
  ]
end
```

## Usage

### Basic Pattern Matching

```elixir
# Initialize the system
VsmGoldrush.init()

# Compile a simple pattern
{:ok, _} = VsmGoldrush.compile_pattern(:high_latency, %{
  field: :latency,
  operator: :gt,
  value: 1000
})

# Process events
event = %{type: "api_call", latency: 1500, endpoint: "/users"}
case VsmGoldrush.process_event(:high_latency, event) do
  {:match, event} -> 
    Logger.warn("High latency detected: #{inspect(event)}")
  :no_match -> 
    :ok
end

# Check statistics
stats = VsmGoldrush.get_stats(:high_latency)
# => %{input_count: 1, output_count: 1, filter_count: 0, ...}
```

### Compound Patterns

```elixir
# ALL conditions must match
{:ok, _} = VsmGoldrush.compile_pattern(:critical_failure, %{
  all: [
    %{field: :severity, operator: :eq, value: :critical},
    %{field: :subsystem, operator: :eq, value: "S1"},
    %{field: :error_rate, operator: :gt, value: 0.1}
  ]
})

# ANY condition can match
{:ok, _} = VsmGoldrush.compile_pattern(:warning_or_error, %{
  any: [
    %{field: :level, operator: :eq, value: :warning},
    %{field: :level, operator: :eq, value: :error}
  ]
})
```

### VSM Cybernetic Patterns

```elixir
# Use pre-defined VSM patterns
{:ok, _} = VsmGoldrush.compile_pattern(:variety_explosion, %{
  vsm_pattern: :variety_explosion
})

# Or compile all cybernetic patterns at once
VsmGoldrush.compile_vsm_patterns()

# Available patterns:
# - :variety_explosion
# - :variety_imbalance
# - :channel_saturation
# - :s1_s3_breakdown
# - :s2_coordination_loop_failure
# - :algedonic_signal
# - :algedonic_channel_blocked
# - :recursion_violation
# - :meta_system_dominance
# - :homeostatic_failure
```

### Pattern Actions

Execute functions when patterns match:

```elixir
action_fn = fn event ->
  # Send to monitoring system
  Telemetry.execute([:vsm, :alert], %{event: event})
  
  # Trigger algedonic bypass
  AlgedonicChannel.send_alert(event)
end

{:ok, _} = VsmGoldrush.compile_pattern_with_action(
  :algedonic_bypass,
  %{
    all: [
      %{field: :type, operator: :eq, value: "algedonic"},
      %{field: :pain_level, operator: :gte, value: 0.8}
    ]
  },
  action_fn
)
```

### Pattern Management

```elixir
# List all compiled patterns
patterns = VsmGoldrush.list_patterns()
# => [:high_latency, :variety_explosion, :algedonic_signal]

# Delete a pattern
VsmGoldrush.delete_pattern(:high_latency)

# Reset statistics
VsmGoldrush.reset_stats(:variety_explosion)
```

## How It Works

1. **Pattern Compilation**: VSM pattern specifications are converted to goldrush queries
2. **Query Compilation**: Goldrush compiles queries into optimized BEAM modules
3. **Event Processing**: Events are converted from Elixir maps to goldrush format
4. **Native Matching**: Compiled modules perform pattern matching at native speed
5. **Statistics**: Each pattern tracks input/output/filter counts automatically

## Performance

Goldrush's compiled queries provide significant performance benefits:

- Pattern matching happens at native BEAM speed
- No interpreter overhead
- Compiled patterns can process 100,000+ events/second
- Statistics have minimal overhead via ETS counters

## Configuration

```elixir
# config/config.exs
config :vsm_goldrush,
  compile_patterns_on_start: true,  # Compile VSM patterns at startup
  cleanup_on_stop: true            # Delete patterns on shutdown
```

## License

MIT License - see LICENSE file for details