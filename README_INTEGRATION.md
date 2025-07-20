# VSM-Goldrush Integration Guide

## Overview

VSM-Goldrush is designed to integrate with VSM applications built using the vsm-starter template. Since vsm-starter is a foundation/template for building VSM apps (not a runtime dependency), the integration happens through telemetry events that VSM applications emit.

## Integration Architecture

```
┌─────────────────────────┐     Telemetry Events    ┌─────────────────────┐
│   Your VSM App          │ ─────────────────────>   │   vsm-goldrush      │
│  (built with            │                          │                     │
│   vsm-starter template) │                          │  Pattern Detection  │
│                         │ <─────────────────────   │  & Failure Analysis │
│  - System 1-5 impl      │   Algedonic Signals     │                     │
│  - Telemetry emission   │                          │  - Cybernetic       │
│  - Channel handling     │                          │    patterns         │
└─────────────────────────┘                          │  - Temporal         │
                                                     │    patterns         │
┌─────────────────────────┐                          │  - GenStage         │
│   vsm-telemetry         │ ─────────────────────>   │    pipeline         │
│  (monitoring service)   │      Metrics Data        └─────────────────────┘
└─────────────────────────┘
```

## How to Integrate

### 1. In Your VSM Application (built with vsm-starter)

Add vsm-goldrush to your dependencies:

```elixir
# mix.exs
def deps do
  [
    {:vsm_goldrush, "~> 0.1.0"},
    # ... other deps
  ]
end
```

### 2. Add Pattern Detection to Your Supervision Tree

```elixir
# lib/my_vsm_app/application.ex
def start(_type, _args) do
  children = [
    # Your existing VSM components from vsm-starter template
    MyVsmApp.Telemetry,
    {MyVsmApp.System1.Supervisor, name: MyVsmApp.System1.Supervisor},
    {MyVsmApp.System2, name: MyVsmApp.System2},
    {MyVsmApp.System3, name: MyVsmApp.System3},
    {MyVsmApp.System4, name: MyVsmApp.System4},
    {MyVsmApp.System5, name: MyVsmApp.System5},
    
    # Add vsm-goldrush pattern detector
    {MyVsmApp.PatternDetector, []}
  ]

  opts = [strategy: :one_for_one, name: MyVsmApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

### 3. Create Pattern Detector Module

```elixir
# lib/my_vsm_app/pattern_detector.ex
defmodule MyVsmApp.PatternDetector do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Initialize vsm-goldrush
    VsmGoldrush.init()
    
    # Compile cybernetic patterns
    VsmGoldrush.Patterns.Cybernetic.compile_all()
    
    # Attach to telemetry events (following vsm-starter conventions)
    attach_telemetry_handlers()
    
    {:ok, %{}}
  end

  defp attach_telemetry_handlers do
    # These are the standard events emitted by vsm-starter apps
    events = [
      [:vsm, :system1, :operation, :start],
      [:vsm, :system1, :operation, :complete],
      [:vsm, :system1, :operation, :error],
      [:vsm, :system2, :coordination, :conflict],
      [:vsm, :system2, :coordination, :resolved],
      [:vsm, :system3, :resource, :allocated],
      [:vsm, :system3, :audit, :performed],
      [:vsm, :system4, :environment, :scanned],
      [:vsm, :system4, :model, :updated],
      [:vsm, :system5, :policy, :set],
      [:vsm, :system5, :identity, :changed],
      [:vsm, :algedonic, :signal]
    ]
    
    :telemetry.attach_many(
      "vsm-goldrush-handler",
      events,
      &handle_telemetry_event/4,
      nil
    )
  end

  def handle_telemetry_event(event_name, measurements, metadata, _config) do
    # Convert telemetry to goldrush event
    event = build_event(event_name, measurements, metadata)
    
    # Check against all patterns
    Enum.each(VsmGoldrush.list_patterns(), fn pattern_id ->
      case VsmGoldrush.process_event(pattern_id, event) do
        {:match, _event} ->
          handle_pattern_match(pattern_id, event)
        :no_match ->
          :ok
      end
    end)
  end

  defp build_event(event_name, measurements, metadata) do
    %{
      event_path: event_name,
      event_type: List.last(event_name),
      system: Enum.at(event_name, 1),
      timestamp: System.system_time(:millisecond)
    }
    |> Map.merge(measurements)
    |> Map.merge(metadata)
  end

  defp handle_pattern_match(:variety_explosion, event) do
    Logger.error("🚨 Variety explosion detected!")
    # Send algedonic signal using vsm-starter's API
    VsmStarter.algedonic_signal(MyVsmApp.VSM, :critical, %{
      source: :pattern_detector,
      pattern: :variety_explosion,
      event: event
    })
  end

  defp handle_pattern_match(pattern_id, event) do
    Logger.warning("Pattern matched: #{pattern_id}")
    # Handle other patterns...
  end
end
```

## Example: Detecting VSM Failures

### 1. System Overload Detection

When your System 1 operations emit error events:

```elixir
# In your System 1 operation (following vsm-starter pattern)
:telemetry.execute(
  [:vsm, :system1, :operation, :error],
  %{count: 1, duration: 5000},
  %{operation: :process_order, error: :timeout}
)
```

VSM-Goldrush can detect cascade failures:

```elixir
# Pattern: Multiple S1 errors followed by S2 conflicts
VsmGoldrush.Temporal.compile_sequence_pattern(
  :cascade_failure,
  [
    %{field: :system, operator: :eq, value: :system1},
    %{field: :event_type, operator: :eq, value: :error},
    %{field: :system, operator: :eq, value: :system2},
    %{field: :event_type, operator: :eq, value: :conflict}
  ],
  5000  # 5 second window
)
```

### 2. Variety Management

Your VSM app calculates variety (following vsm-starter patterns):

```elixir
# From VsmStarter.Telemetry.variety_metrics/0
metrics = %{
  environmental_variety: 2000,
  system_variety: 1600,
  variety_ratio: 0.8
}

# Emit as telemetry
:telemetry.execute(
  [:vsm, :variety, :calculated],
  metrics,
  %{source: :variety_calculator}
)
```

VSM-Goldrush detects when variety is out of control:

```elixir
# Automatically detects variety explosion
if variety_ratio > 0.8 and channel_load > 0.9 do
  # Pattern matches! Triggers algedonic signal
end
```

## Working with vsm-telemetry

If you're also using vsm-telemetry for monitoring:

```elixir
# vsm-telemetry collects metrics
# vsm-goldrush analyzes them for patterns

# In your pattern detector:
def handle_telemetry_event([:vsm_telemetry, :metrics, :collected], measurements, metadata, _) do
  # Check metrics for cybernetic failures
  if measurements[:variety_ratio] > 0.85 do
    # Potential variety explosion
    check_variety_patterns(measurements)
  end
end
```

## Key Integration Points

1. **Telemetry Events**: VSM-Goldrush consumes the standard telemetry events that vsm-starter-based apps emit

2. **Algedonic Signals**: When patterns are detected, use `VsmStarter.algedonic_signal/3` to alert your VSM

3. **Variety Metrics**: Use the variety calculations from your VSM app to detect variety-related failures

4. **Channel Monitoring**: Track channel saturation through resource allocation events

## Benefits

- **Zero Code Changes**: Works with existing vsm-starter telemetry
- **Real-time Detection**: Patterns detected as events occur
- **Cybernetic Patterns**: Pre-built patterns for VSM failures
- **Extensible**: Add custom patterns for your domain

## Next Steps

1. Review the [cybernetic patterns](lib/vsm_goldrush/patterns/cybernetic.ex) available
2. Create custom patterns for your specific VSM implementation
3. Set up GenStage pipeline for high-volume event processing
4. Configure temporal patterns for complex failure scenarios