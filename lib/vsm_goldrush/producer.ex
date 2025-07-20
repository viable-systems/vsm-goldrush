defmodule VsmGoldrush.Producer do
  @moduledoc """
  GenStage producer that generates VSM events and processes them through
  compiled goldrush patterns.
  
  This producer can be used as part of a GenStage pipeline to stream
  events through goldrush pattern matching in real-time.
  """
  
  use GenStage
  require Logger
  
  defstruct [:patterns, :event_generator, :state, :demand]
  
  @doc """
  Start a new producer with optional event generator function.
  
  ## Options
  
    * `:patterns` - List of pattern IDs to match against events
    * `:event_generator` - Function that generates events (defaults to cybernetic events)
    * `:demand_limit` - Maximum events to generate per demand (default: 100)
  
  """
  def start_link(opts \\ []) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(opts) do
    patterns = Keyword.get(opts, :patterns, [])
    event_generator = Keyword.get(opts, :event_generator, &default_event_generator/0)
    demand_limit = Keyword.get(opts, :demand_limit, 100)
    
    state = %__MODULE__{
      patterns: patterns,
      event_generator: event_generator,
      state: %{demand_limit: demand_limit},
      demand: 0
    }
    
    Logger.info("VsmGoldrush.Producer started with #{length(patterns)} patterns")
    
    {:producer, state}
  end
  
  @impl true
  def handle_demand(demand, %__MODULE__{demand: existing_demand} = state) do
    total_demand = existing_demand + demand
    events = generate_events(state, total_demand)
    
    remaining_demand = max(0, total_demand - length(events))
    
    {:noreply, events, %{state | demand: remaining_demand}}
  end
  
  @doc """
  Add a pattern to the producer's active patterns.
  """
  def add_pattern(producer \\ __MODULE__, pattern_id) do
    GenStage.call(producer, {:add_pattern, pattern_id})
  end
  
  @doc """
  Remove a pattern from the producer's active patterns.
  """
  def remove_pattern(producer \\ __MODULE__, pattern_id) do
    GenStage.call(producer, {:remove_pattern, pattern_id})
  end
  
  @impl true
  def handle_call({:add_pattern, pattern_id}, _from, %__MODULE__{patterns: patterns} = state) do
    new_patterns = [pattern_id | patterns] |> Enum.uniq()
    new_state = %{state | patterns: new_patterns}
    
    Logger.info("Added pattern #{pattern_id} to producer")
    {:reply, :ok, [], new_state}
  end
  
  @impl true
  def handle_call({:remove_pattern, pattern_id}, _from, %__MODULE__{patterns: patterns} = state) do
    new_patterns = List.delete(patterns, pattern_id)
    new_state = %{state | patterns: new_patterns}
    
    Logger.info("Removed pattern #{pattern_id} from producer")
    {:reply, :ok, [], new_state}
  end
  
  # Private functions
  
  defp generate_events(%__MODULE__{event_generator: generator, state: %{demand_limit: limit}}, demand) do
    count = min(demand, limit)
    
    for _i <- 1..count do
      event = generator.()
      %{event: event, timestamp: System.system_time(:millisecond)}
    end
  end
  
  defp default_event_generator do
    events = [
      %{type: :variety_explosion, system: :s1, variety_level: :rand.uniform(100), threshold: 50},
      %{type: :algedonic_signal, severity: :high, system: :s3, message: "Critical resource depletion"},
      %{type: :channel_saturation, channel: :s1_s3, utilization: 95, capacity: 100},
      %{type: :coordination_failure, systems: [:s2, :s3], correlation_id: :crypto.strong_rand_bytes(16) |> Base.encode16()},
      %{type: :homeostatic_drift, variable: :temperature, current: 75, target: 70, tolerance: 2},
      %{type: :recursion_violation, level: 3, violating_system: :s4, target_level: 2},
      %{type: :meta_system_dominance, higher_level: 2, lower_level: 1, interference_type: :autonomy_override}
    ]
    
    Enum.random(events)
  end
end