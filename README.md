# vsm_goldrush

Elixir wrapper around the Erlang [goldrush](https://github.com/DeadZen/goldrush) event processing library. Compiles pattern-matching queries into BEAM modules via goldrush, then runs VSM-specific cybernetic failure detection against those compiled queries.

## Status

- Version: 0.1.0
- OTP app with supervision tree
- Depends on goldrush ~> 0.1.9 and gen_stage ~> 1.2
- Published to Hex under the `viable_systems` organization
- Tests exist but coverage is unknown

## What it does

1. Takes a pattern spec (field/operator/value map, compound `all`/`any`, or named VSM pattern)
2. Converts it to a goldrush query via `VsmGoldrush.QueryBuilder`
3. Compiles the query into a BEAM module with `:glc.compile/2`
4. Processes events by converting Elixir maps to goldrush proplists, running them through the compiled module, and checking output counters to determine match/no-match

## Modules

| Module | Purpose |
|--------|---------|
| `VsmGoldrush` | Main API: compile_pattern, process_event, get_stats |
| `VsmGoldrush.QueryBuilder` | Converts pattern specs to goldrush query terms |
| `VsmGoldrush.EventConverter` | Converts between Elixir maps and goldrush proplists |
| `VsmGoldrush.PatternRegistry` | Tracks which patterns are currently compiled |
| `VsmGoldrush.Patterns.Cybernetic` | 10 pre-defined VSM failure patterns |
| `VsmGoldrush.Producer` | GenStage producer for streaming integration |
| `VsmGoldrush.Consumer` | GenStage consumer for streaming integration |
| `VsmGoldrush.Temporal` | Temporal pattern analysis |

## Pre-defined cybernetic patterns

| Pattern | Detects |
|---------|---------|
| `variety_explosion` | Environmental variety exceeding regulatory capacity |
| `variety_imbalance` | Controller/environment variety mismatch |
| `channel_saturation` | Queue depth >= 1000, latency >= 5s, or drop rate >= 5% |
| `s1_s3_breakdown` | Operations-to-management channel failure |
| `s2_coordination_loop_failure` | Sync failures > 10, conflict rate > 20% |
| `algedonic_signal` | Pain level >= 0.7 or pleasure level <= 0.3 |
| `algedonic_channel_blocked` | Critical algedonic bypass non-functional |
| `recursion_violation` | Recursive system boundary violations |
| `meta_system_dominance` | Higher recursion level interfering with lower |
| `homeostatic_failure` | System unable to maintain essential variables |

## Installation

```elixir
def deps do
  [{:vsm_goldrush, "~> 0.1.0", organization: "viable_systems"}]
end
```

Depends on `vsm_core` via path dependency when used standalone. In the umbrella project, that dependency is omitted.

## Usage

```elixir
VsmGoldrush.init()

# Compile a pattern
{:ok, _} = VsmGoldrush.compile_pattern(:high_latency, %{
  field: :latency, operator: :gt, value: 1000
})

# Process an event
case VsmGoldrush.process_event(:high_latency, %{latency: 1500}) do
  {:match, event} -> handle_match(event)
  :no_match -> :ok
end

# Or compile all 10 cybernetic patterns at once
VsmGoldrush.compile_vsm_patterns()

# Check per-pattern statistics
VsmGoldrush.get_stats(:high_latency)
# => %{input_count: 1, output_count: 1, filter_count: 0, info: ...}
```

## Limitations

- Match detection works by comparing goldrush output counters before and after processing, which is not thread-safe under concurrent event processing
- `vsm_core` path dependency means this cannot be installed from Hex alone without also having vsm_core locally
- No property-based or fuzz testing
- Temporal module exists but test coverage is minimal

## License

MIT
