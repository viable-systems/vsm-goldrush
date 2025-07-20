#!/usr/bin/env elixir

# Test script to demonstrate vsm-goldrush working with vsm-starter telemetry events
# Run with: elixir test_integration.exs

Mix.install([
  {:vsm_goldrush, path: "."},
  {:telemetry, "~> 1.2"}
])

defmodule TestIntegration do
  require Logger
  
  def run do
    Logger.info("Starting VSM integration test...")
    
    # Initialize VsmGoldrush
    VsmGoldrush.init()
    
    # Compile some patterns
    setup_patterns()
    
    # Setup telemetry handler
    setup_telemetry()
    
    # Simulate vsm-starter events
    simulate_events()
    
    Logger.info("Test complete!")
  end
  
  defp setup_patterns do
    # Compile variety explosion pattern
    {:ok, :variety_explosion} = VsmGoldrush.compile_pattern(:variety_explosion, %{
      all: [
        %{field: :type, operator: :eq, value: "variety_state"},
        %{field: :variety_ratio, operator: :gt, value: 0.8},
        %{field: :channel_load, operator: :gt, value: 0.9}
      ]
    })
    
    # Compile algedonic signal pattern
    {:ok, :algedonic_signal} = VsmGoldrush.compile_pattern(:algedonic_signal, %{
      all: [
        %{field: :type, operator: :eq, value: "algedonic"},
        %{any: [
          %{field: :pain_level, operator: :gte, value: 0.7},
          %{field: :pleasure_level, operator: :lte, value: 0.3}
        ]}
      ]
    })
    
    # Compile S1 operation error pattern
    {:ok, :s1_error} = VsmGoldrush.compile_pattern(:s1_error, %{
      all: [
        %{field: :event, operator: :eq, value: "system1.operation.error"},
        %{field: :severity, operator: :gte, value: :high}
      ]
    })
    
    Logger.info("Compiled #{length(VsmGoldrush.list_patterns())} patterns")
  end
  
  defp setup_telemetry do
    # Attach handler that processes telemetry through goldrush
    :telemetry.attach(
      "test-vsm-handler",
      [:vsm, :test, :event],
      &handle_telemetry/4,
      nil
    )
    
    Logger.info("Telemetry handler attached")
  end
  
  def handle_telemetry(_event_name, measurements, metadata, _config) do
    # Convert telemetry to goldrush event
    event = Map.merge(measurements, metadata)
    
    # Check all patterns
    Enum.each(VsmGoldrush.list_patterns(), fn pattern ->
      case VsmGoldrush.process_event(pattern, event) do
        {:match, _event} ->
          Logger.warning("🚨 Pattern '#{pattern}' matched! Event: #{inspect(event)}")
        :no_match ->
          :ok
      end
    end)
  end
  
  defp simulate_events do
    Logger.info("\n=== Simulating VSM events ===\n")
    
    # Normal operation
    Logger.info("1. Normal operation event...")
    :telemetry.execute(
      [:vsm, :test, :event],
      %{type: "variety_state", variety_ratio: 0.5, channel_load: 0.6},
      %{source: :test}
    )
    Process.sleep(100)
    
    # Variety explosion!
    Logger.info("\n2. Variety explosion event...")
    :telemetry.execute(
      [:vsm, :test, :event],
      %{type: "variety_state", variety_ratio: 0.85, channel_load: 0.95},
      %{source: :test, system: :s1}
    )
    Process.sleep(100)
    
    # Algedonic signal
    Logger.info("\n3. Algedonic signal event...")
    :telemetry.execute(
      [:vsm, :test, :event],
      %{type: "algedonic", pain_level: 0.8},
      %{source: :test, urgency: :critical}
    )
    Process.sleep(100)
    
    # S1 error
    Logger.info("\n4. System 1 error event...")
    :telemetry.execute(
      [:vsm, :test, :event],
      %{event: "system1.operation.error", severity: :high},
      %{error: :timeout, operation: :process_order}
    )
    Process.sleep(100)
    
    # Low severity error (should not match)
    Logger.info("\n5. Low severity error (should not match)...")
    :telemetry.execute(
      [:vsm, :test, :event],
      %{event: "system1.operation.error", severity: :low},
      %{error: :validation, operation: :check_input}
    )
    Process.sleep(100)
  end
end

# Run the test
TestIntegration.run()