# VSM-Starter Integration Example
# 
# This example shows how to use vsm-goldrush with vsm-starter to detect
# cybernetic failures in real-time from telemetry events.

# First, add vsm-goldrush to your vsm-starter project's mix.exs:
# {:vsm_goldrush, "~> 0.1.0"}
# or for local development:
# {:vsm_goldrush, path: "../vsm-goldrush"}

defmodule VsmStarterIntegration do
  @moduledoc """
  Integration between vsm-starter telemetry and vsm-goldrush pattern detection.
  
  This module:
  1. Attaches to vsm-starter telemetry events
  2. Converts them to vsm-goldrush event format
  3. Runs them through cybernetic failure patterns
  4. Takes action when failures are detected
  """
  
  require Logger
  
  def setup do
    # Initialize vsm-goldrush
    VsmGoldrush.init()
    
    # Compile cybernetic patterns
    compile_vsm_patterns()
    
    # Attach telemetry handlers
    attach_telemetry_handlers()
    
    Logger.info("VSM-Goldrush integration initialized")
  end
  
  defp compile_vsm_patterns do
    # Use the pre-built cybernetic patterns
    patterns = VsmGoldrush.Patterns.Cybernetic.compile_all()
    Logger.info("Compiled #{length(patterns)} cybernetic patterns")
    
    # Add custom patterns for vsm-starter specific events
    compile_custom_patterns()
  end
  
  defp compile_custom_patterns do
    # Pattern: System 1 overload (too many operations)
    VsmGoldrush.compile_pattern(:s1_overload, %{
      all: [
        %{field: :event_type, operator: :eq, value: :system1_operation_start},
        %{field: :queue_length, operator: :gt, value: 100}
      ]
    })
    
    # Pattern: System 2 coordination breakdown
    VsmGoldrush.compile_pattern(:s2_breakdown, %{
      all: [
        %{field: :event_type, operator: :eq, value: :system2_coordination_conflict},
        %{field: :resolution_attempts, operator: :gt, value: 5}
      ]
    })
    
    # Pattern: Algedonic bypass activated
    VsmGoldrush.compile_pattern(:algedonic_bypass, %{
      all: [
        %{field: :event_type, operator: :eq, value: :algedonic_signal},
        %{field: :severity, operator: :gte, value: :critical}
      ]
    })
    
    # Temporal pattern: Cascading failure
    VsmGoldrush.Temporal.compile_sequence_pattern(
      :cascade_failure,
      [
        %{field: :event_type, operator: :eq, value: :system1_operation_error},
        %{field: :event_type, operator: :eq, value: :system2_coordination_conflict},
        %{field: :event_type, operator: :eq, value: :system3_resource_exhausted}
      ],
      5000  # 5 second window
    )
    
    Logger.info("Compiled custom VSM patterns")
  end
  
  defp attach_telemetry_handlers do
    # System 1 events
    :telemetry.attach(
      "vsm-goldrush-s1-operation",
      [:vsm, :system1, :operation, :start],
      &handle_telemetry_event/4,
      %{event_type: :system1_operation_start}
    )
    
    :telemetry.attach(
      "vsm-goldrush-s1-error",
      [:vsm, :system1, :operation, :error],
      &handle_telemetry_event/4,
      %{event_type: :system1_operation_error}
    )
    
    # System 2 events
    :telemetry.attach(
      "vsm-goldrush-s2-conflict",
      [:vsm, :system2, :coordination, :conflict],
      &handle_telemetry_event/4,
      %{event_type: :system2_coordination_conflict}
    )
    
    # System 3 events
    :telemetry.attach(
      "vsm-goldrush-s3-resource",
      [:vsm, :system3, :resource, :allocated],
      &handle_telemetry_event/4,
      %{event_type: :system3_resource_allocated}
    )
    
    # Algedonic events
    :telemetry.attach(
      "vsm-goldrush-algedonic",
      [:vsm, :algedonic, :signal],
      &handle_telemetry_event/4,
      %{event_type: :algedonic_signal}
    )
    
    # Variety metrics
    :telemetry.attach(
      "vsm-goldrush-variety",
      [:vsm, :vm, :metrics],
      &handle_variety_metrics/4,
      nil
    )
    
    Logger.info("Attached telemetry handlers")
  end
  
  def handle_telemetry_event(_event_name, measurements, metadata, config) do
    # Convert telemetry event to vsm-goldrush format
    event = %{
      event_type: config.event_type,
      timestamp: System.system_time(:millisecond)
    }
    |> Map.merge(measurements)
    |> Map.merge(metadata)
    
    # Process through all patterns
    patterns = VsmGoldrush.list_patterns()
    
    Enum.each(patterns, fn pattern_id ->
      case VsmGoldrush.process_event(pattern_id, event) do
        {:match, _event} ->
          handle_pattern_match(pattern_id, event)
        
        :no_match ->
          :ok
      end
    end)
  end
  
  def handle_variety_metrics(_event_name, measurements, _metadata, _config) do
    # Extract variety measurements
    env_variety = Keyword.get(measurements, :vsm_variety_environmental, 0)
    sys_variety = Keyword.get(measurements, :vsm_variety_system, 0)
    
    # Check for variety explosion
    if env_variety > 0 do
      ratio = sys_variety / env_variety
      
      event = %{
        type: :variety_state,
        variety_ratio: ratio,
        channel_load: ratio,  # Simplified assumption
        environmental_variety: env_variety,
        system_variety: sys_variety,
        timestamp: System.system_time(:millisecond)
      }
      
      case VsmGoldrush.process_event(:variety_explosion, event) do
        {:match, _} ->
          Logger.warning("⚠️  VARIETY EXPLOSION DETECTED! Ratio: #{Float.round(ratio, 2)}")
          # In production, trigger variety amplification or attenuation
        
        :no_match ->
          :ok
      end
    end
  end
  
  defp handle_pattern_match(pattern_id, event) do
    case pattern_id do
      :variety_explosion ->
        Logger.error("🚨 VSM FAILURE: Variety explosion detected!")
        Logger.error("   Environmental variety exceeds system capacity")
        notify_system3_control(event)
      
      :algedonic_signal ->
        Logger.error("🚨 VSM FAILURE: Algedonic signal!")
        Logger.error("   Pain signal requiring immediate attention")
        notify_system5_policy(event)
      
      :s1_s3_breakdown ->
        Logger.error("🚨 VSM FAILURE: S1-S3 communication breakdown!")
        Logger.error("   Operations to management channel failure")
        initiate_emergency_protocol(event)
      
      :s2_breakdown ->
        Logger.warning("⚠️  System 2 coordination breakdown")
        increase_coordination_resources(event)
      
      :cascade_failure ->
        Logger.error("🚨 CRITICAL: Cascading system failure detected!")
        Logger.error("   Multiple subsystems failing in sequence")
        activate_crisis_management(event)
      
      :algedonic_bypass ->
        Logger.error("🚨 Algedonic bypass activated!")
        bypass_normal_channels(event)
      
      pattern ->
        Logger.warning("Pattern matched: #{pattern}")
        Logger.debug("Event: #{inspect(event)}")
    end
  end
  
  # Action functions that would integrate with vsm-starter
  
  defp notify_system3_control(event) do
    # In a real system, this would notify System 3
    # For now, just emit a telemetry event
    VsmStarter.Telemetry.emit_event(
      [:system3, :notification, :variety_explosion],
      %{severity: :critical},
      event
    )
  end
  
  defp notify_system5_policy(event) do
    VsmStarter.Telemetry.emit_event(
      [:system5, :notification, :algedonic],
      %{action_required: true},
      event
    )
  end
  
  defp initiate_emergency_protocol(event) do
    Logger.alert("Initiating emergency protocol for S1-S3 breakdown")
    # Would trigger actual emergency procedures
  end
  
  defp increase_coordination_resources(event) do
    # Would dynamically allocate more resources to System 2
    Logger.info("Increasing System 2 coordination resources")
  end
  
  defp activate_crisis_management(event) do
    Logger.alert("ACTIVATING CRISIS MANAGEMENT MODE")
    # Would switch to crisis management protocols
  end
  
  defp bypass_normal_channels(event) do
    # Direct communication to System 5, bypassing hierarchy
    Logger.alert("Bypassing normal channels - direct to System 5")
  end
end

# Example usage with a GenServer that monitors vsm-starter

defmodule VsmMonitor do
  use GenServer
  require Logger
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    # Setup the integration
    VsmStarterIntegration.setup()
    
    # Start monitoring with GenStage if desired
    if Application.get_env(:vsm_goldrush, :use_genstage, false) do
      setup_genstage_pipeline()
    end
    
    {:ok, %{start_time: System.system_time(:second)}}
  end
  
  defp setup_genstage_pipeline do
    # Start a producer that generates events from telemetry
    {:ok, _producer} = VsmGoldrush.Producer.start_link(
      patterns: VsmGoldrush.list_patterns(),
      event_generator: &generate_from_telemetry/0
    )
    
    # Start a consumer with actions for pattern matches
    actions = %{
      variety_explosion: &handle_variety_explosion/2,
      algedonic_signal: &handle_algedonic_signal/2,
      cascade_failure: &handle_cascade_failure/2
    }
    
    {:ok, _consumer} = VsmGoldrush.Consumer.start_link(
      patterns: VsmGoldrush.list_patterns(),
      actions: actions
    )
    
    Logger.info("GenStage pipeline started for continuous monitoring")
  end
  
  defp generate_from_telemetry do
    # This would pull from a queue of telemetry events
    # For demo, generate synthetic events
    Enum.random([
      %{type: :variety_state, variety_ratio: :rand.uniform(), channel_load: :rand.uniform()},
      %{type: :algedonic, pain_level: :rand.uniform(), system: :s1},
      %{event_type: :system1_operation_error, error: :timeout},
      %{event_type: :system2_coordination_conflict, attempts: :rand.uniform(10)}
    ])
  end
  
  defp handle_variety_explosion(_pattern, event) do
    GenServer.cast(__MODULE__, {:variety_explosion, event})
  end
  
  defp handle_algedonic_signal(_pattern, event) do
    GenServer.cast(__MODULE__, {:algedonic_signal, event})
  end
  
  defp handle_cascade_failure(_pattern, event) do
    GenServer.cast(__MODULE__, {:cascade_failure, event})
  end
  
  def handle_cast({:variety_explosion, event}, state) do
    Logger.error("GenStage detected variety explosion: #{inspect(event)}")
    {:noreply, state}
  end
  
  def handle_cast({:algedonic_signal, event}, state) do
    Logger.error("GenStage detected algedonic signal: #{inspect(event)}")
    {:noreply, state}
  end
  
  def handle_cast({:cascade_failure, event}, state) do
    Logger.error("GenStage detected cascade failure: #{inspect(event)}")
    {:noreply, state}
  end
end

# To use this integration:
# 
# 1. Add to your vsm-starter supervision tree:
#    children = [
#      # ... other children
#      VsmMonitor
#    ]
#
# 2. Or start it manually:
#    VsmMonitor.start_link()
#
# 3. The monitor will automatically:
#    - Compile VSM cybernetic patterns
#    - Attach to vsm-starter telemetry events
#    - Detect failures in real-time
#    - Take appropriate actions