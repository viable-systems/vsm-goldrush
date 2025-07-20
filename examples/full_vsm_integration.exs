# Full VSM Integration Example
# 
# This example demonstrates how vsm-starter, vsm-telemetry, and vsm-goldrush
# work together to create a complete VSM monitoring and failure detection system.

# To run this example, you need all three packages installed:
# mix deps.get
# iex -S mix
# Then paste or run this file

defmodule FullVsmIntegration do
  @moduledoc """
  Complete integration of VSM packages:
  - vsm-starter: Base VSM implementation
  - vsm-telemetry: Metrics and monitoring  
  - vsm-goldrush: Pattern detection
  """
  
  require Logger
  
  def setup do
    Logger.info("Setting up full VSM integration...")
    
    # 1. Initialize vsm-goldrush patterns
    setup_goldrush_patterns()
    
    # 2. Attach telemetry handlers
    setup_telemetry_handlers()
    
    # 3. Setup pattern detection pipeline
    setup_pattern_pipeline()
    
    Logger.info("VSM integration ready!")
  end
  
  defp setup_goldrush_patterns do
    # Initialize goldrush
    VsmGoldrush.init()
    
    # Compile all cybernetic patterns
    compiled = VsmGoldrush.Patterns.Cybernetic.compile_all()
    Logger.info("Compiled #{length(compiled)} cybernetic patterns")
    
    # Add custom patterns for integrated detection
    compile_integration_patterns()
  end
  
  defp compile_integration_patterns do
    # Pattern: High system load across multiple subsystems
    VsmGoldrush.compile_pattern(:system_overload, %{
      all: [
        %{field: :source, operator: :eq, value: :vsm_telemetry},
        %{field: :metric_type, operator: :eq, value: :system_load},
        %{field: :value, operator: :gt, value: 0.8}
      ]
    })
    
    # Pattern: Metrics collection failure
    VsmGoldrush.compile_pattern(:telemetry_failure, %{
      all: [
        %{field: :source, operator: :eq, value: :vsm_telemetry},
        %{field: :error_type, operator: :eq, value: :collection_failed}
      ]
    })
    
    # Temporal: Degrading performance
    VsmGoldrush.Temporal.compile_sequence_pattern(
      :performance_degradation,
      [
        %{field: :latency, operator: :gt, value: 100},
        %{field: :latency, operator: :gt, value: 200},
        %{field: :latency, operator: :gt, value: 500}
      ],
      10000  # 10 second window
    )
  end
  
  defp setup_telemetry_handlers do
    # Handler for vsm-starter events
    :telemetry.attach_many(
      "goldrush-vsm-starter",
      [
        [:vsm, :system1, :operation, :start],
        [:vsm, :system1, :operation, :complete],
        [:vsm, :system1, :operation, :error],
        [:vsm, :system2, :coordination, :conflict],
        [:vsm, :system3, :resource, :allocated],
        [:vsm, :system4, :environment, :scanned],
        [:vsm, :system5, :policy, :set],
        [:vsm, :algedonic, :signal]
      ],
      &handle_vsm_starter_event/4,
      %{source: :vsm_starter}
    )
    
    # Handler for vsm-telemetry metrics
    :telemetry.attach_many(
      "goldrush-vsm-telemetry",
      [
        [:vsm_telemetry, :metrics, :collected],
        [:vsm_telemetry, :variety, :calculated],
        [:vsm_telemetry, :alert, :triggered]
      ],
      &handle_vsm_telemetry_event/4,
      %{source: :vsm_telemetry}
    )
    
    Logger.info("Telemetry handlers attached")
  end
  
  def handle_vsm_starter_event(event_name, measurements, metadata, config) do
    # Convert to goldrush event format
    event = build_event(event_name, measurements, metadata, config)
    
    # Process through all patterns
    check_patterns(event, event_name)
  end
  
  def handle_vsm_telemetry_event(event_name, measurements, metadata, config) do
    # Special handling for telemetry metrics
    event = build_event(event_name, measurements, metadata, config)
    
    # Check for variety metrics
    if measurements[:variety_ratio] do
      check_variety_patterns(measurements)
    end
    
    # Process through patterns
    check_patterns(event, event_name)
  end
  
  defp build_event(event_name, measurements, metadata, config) do
    %{
      event: Enum.join(event_name, "."),
      timestamp: System.system_time(:millisecond),
      source: config[:source]
    }
    |> Map.merge(measurements)
    |> Map.merge(metadata)
  end
  
  defp check_patterns(event, event_name) do
    patterns = VsmGoldrush.list_patterns()
    
    Enum.each(patterns, fn pattern_id ->
      case VsmGoldrush.process_event(pattern_id, event) do
        {:match, _event} ->
          handle_pattern_match(pattern_id, event, event_name)
        :no_match ->
          :ok
      end
    end)
  end
  
  defp check_variety_patterns(measurements) do
    event = %{
      type: :variety_state,
      variety_ratio: measurements[:variety_ratio],
      channel_load: measurements[:channel_load] || measurements[:variety_ratio],
      environmental_variety: measurements[:environmental_variety],
      system_variety: measurements[:system_variety]
    }
    
    case VsmGoldrush.process_event(:variety_explosion, event) do
      {:match, _} ->
        handle_variety_explosion(measurements)
      :no_match ->
        :ok
    end
  end
  
  defp handle_pattern_match(pattern_id, event, event_name) do
    severity = determine_severity(pattern_id)
    
    Logger.log(severity, """
    🚨 VSM Pattern Detected: #{pattern_id}
    Event: #{inspect(event_name)}
    Details: #{inspect(event, pretty: true)}
    """)
    
    # Take action based on pattern
    case pattern_id do
      :variety_explosion ->
        # Notify vsm-telemetry to trigger variety attenuation
        send_to_telemetry(:variety_attenuation_required, event)
        
      :algedonic_signal ->
        # Forward to System 5 immediately
        send_algedonic_bypass(event)
        
      :cascade_failure ->
        # Activate emergency protocols
        activate_emergency_mode(event)
        
      :system_overload ->
        # Request resource reallocation
        request_resource_reallocation(event)
        
      _ ->
        # Log for monitoring
        :ok
    end
  end
  
  defp handle_variety_explosion(measurements) do
    Logger.error("""
    🚨 VARIETY EXPLOSION DETECTED!
    Environmental Variety: #{measurements[:environmental_variety]}
    System Variety: #{measurements[:system_variety]}
    Ratio: #{Float.round(measurements[:variety_ratio], 3)}
    
    Action: Initiating variety attenuation protocols
    """)
    
    # Would trigger actual variety management here
  end
  
  # Integration with GenStage pipeline
  defp setup_pattern_pipeline do
    # Create a producer that combines events from both sources
    {:ok, _producer} = VsmGoldrush.Producer.start_link(
      patterns: VsmGoldrush.list_patterns(),
      event_generator: &generate_combined_events/0,
      demand_limit: 10
    )
    
    # Consumer with integrated actions
    actions = build_integrated_actions()
    
    {:ok, _consumer} = VsmGoldrush.Consumer.start_link(
      patterns: VsmGoldrush.list_patterns(),
      actions: actions
    )
    
    Logger.info("GenStage pipeline started")
  end
  
  defp generate_combined_events do
    # In production, this would pull from event queues
    # For demo, generate realistic events
    Enum.random([
      # vsm-starter events
      %{source: :vsm_starter, event: "system1.operation.start", latency: :rand.uniform(1000)},
      %{source: :vsm_starter, event: "system2.coordination.conflict", attempts: :rand.uniform(10)},
      %{source: :vsm_starter, event: "algedonic.signal", severity: Enum.random([:low, :medium, :high, :critical])},
      
      # vsm-telemetry events  
      %{source: :vsm_telemetry, metric_type: :system_load, value: :rand.uniform()},
      %{source: :vsm_telemetry, type: :variety_state, variety_ratio: :rand.uniform(), channel_load: :rand.uniform()},
      
      # Integrated events
      %{source: :integrated, event: "cascade.potential", risk_score: :rand.uniform()}
    ])
  end
  
  defp build_integrated_actions do
    %{
      variety_explosion: fn pattern, event ->
        Logger.error("[GenStage] Variety explosion detected: #{inspect(event)}")
        {:action_taken, :variety_attenuation}
      end,
      
      algedonic_signal: fn pattern, event ->
        Logger.error("[GenStage] Algedonic signal: #{inspect(event)}")
        {:action_taken, :bypass_activated}
      end,
      
      cascade_failure: fn pattern, event ->
        Logger.error("[GenStage] CASCADE FAILURE: #{inspect(event)}")
        {:action_taken, :emergency_mode}
      end,
      
      system_overload: fn pattern, event ->
        Logger.warning("[GenStage] System overload: #{inspect(event)}")
        {:action_taken, :resources_reallocated}
      end
    }
  end
  
  # Helper functions
  
  defp determine_severity(pattern_id) do
    case pattern_id do
      p when p in [:variety_explosion, :algedonic_signal, :cascade_failure] -> :error
      p when p in [:system_overload, :s1_s3_breakdown] -> :warning
      _ -> :info
    end
  end
  
  defp send_to_telemetry(action, event) do
    # Would send to vsm-telemetry GenServer
    Logger.info("→ Sending to vsm-telemetry: #{action}")
  end
  
  defp send_algedonic_bypass(event) do
    # Would bypass hierarchy and go direct to S5
    Logger.alert("⚡ ALGEDONIC BYPASS ACTIVATED → System 5")
  end
  
  defp activate_emergency_mode(event) do
    Logger.alert("🚨 EMERGENCY MODE ACTIVATED")
    # Would trigger emergency protocols
  end
  
  defp request_resource_reallocation(event) do
    Logger.info("→ Requesting resource reallocation from System 3")
  end
end

# Demonstration module
defmodule VsmIntegrationDemo do
  require Logger
  
  def run do
    # Setup the integration
    FullVsmIntegration.setup()
    
    # Simulate some events
    Logger.info("\n=== Starting VSM Integration Demo ===\n")
    
    # Simulate normal operations
    simulate_normal_operations()
    
    # Simulate variety explosion scenario
    Process.sleep(1000)
    simulate_variety_explosion()
    
    # Simulate cascade failure
    Process.sleep(1000) 
    simulate_cascade_failure()
    
    # Show statistics
    Process.sleep(1000)
    show_statistics()
  end
  
  defp simulate_normal_operations do
    Logger.info("📊 Simulating normal operations...")
    
    :telemetry.execute(
      [:vsm, :system1, :operation, :complete],
      %{duration: 45, count: 1},
      %{operation: :process_order}
    )
    
    :telemetry.execute(
      [:vsm_telemetry, :metrics, :collected],
      %{variety_ratio: 0.6, system_load: 0.5},
      %{collector: :metrics_collector}
    )
  end
  
  defp simulate_variety_explosion do
    Logger.info("\n📈 Simulating variety explosion...")
    
    :telemetry.execute(
      [:vsm_telemetry, :variety, :calculated],
      %{
        variety_ratio: 0.9,
        channel_load: 0.95,
        environmental_variety: 2000,
        system_variety: 1800
      },
      %{source: :variety_calculator}
    )
  end
  
  defp simulate_cascade_failure do
    Logger.info("\n💥 Simulating cascade failure...")
    
    # S1 error
    :telemetry.execute(
      [:vsm, :system1, :operation, :error],
      %{count: 1, latency: 5000},
      %{error: :timeout}
    )
    
    # S2 conflict
    Process.sleep(100)
    :telemetry.execute(
      [:vsm, :system2, :coordination, :conflict],
      %{attempts: 7},
      %{conflict_type: :resource_contention}
    )
    
    # S3 resource exhaustion
    Process.sleep(100)
    :telemetry.execute(
      [:vsm, :system3, :resource, :allocated],
      %{amount: 0, available: 0},
      %{resource_type: :memory, status: :exhausted}
    )
  end
  
  defp show_statistics do
    Logger.info("\n📊 Pattern Detection Statistics:")
    
    # Get stats from consumer if running
    if consumer = Process.whereis(VsmGoldrush.Consumer) do
      stats = VsmGoldrush.Consumer.get_stats(consumer)
      Logger.info("Total events processed: #{stats.total_events}")
      Logger.info("Total pattern matches: #{stats.total_matches}")
      Logger.info("Patterns: #{inspect(stats.patterns)}")
    end
  end
end

# To run the demo:
# VsmIntegrationDemo.run()