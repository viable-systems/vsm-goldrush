defmodule VsmGoldrush.Consumer do
  @moduledoc """
  GenStage consumer that processes events from VsmGoldrush.Producer
  through compiled goldrush patterns.
  
  This consumer receives events and runs them through all active
  goldrush patterns, executing configured actions when patterns match.
  """
  
  use GenStage
  require Logger
  
  defstruct [:patterns, :actions, :stats]
  
  @doc """
  Start a new consumer.
  
  ## Options
  
    * `:patterns` - List of pattern IDs to match against (required)
    * `:actions` - Map of pattern_id => action_function for matched events
    * `:subscribe_to` - Producer to subscribe to (defaults to VsmGoldrush.Producer)
  
  """
  def start_link(opts \\ []) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(opts) do
    patterns = Keyword.get(opts, :patterns, [])
    actions = Keyword.get(opts, :actions, %{})
    subscribe_to = Keyword.get(opts, :subscribe_to, [VsmGoldrush.Producer])
    
    # Validate that all patterns exist
    missing_patterns = patterns -- VsmGoldrush.list_patterns()
    if missing_patterns != [] do
      Logger.warning("Missing patterns: #{inspect(missing_patterns)}")
    end
    
    state = %__MODULE__{
      patterns: patterns,
      actions: actions,
      stats: init_stats(patterns)
    }
    
    Logger.info("VsmGoldrush.Consumer started with patterns: #{inspect(patterns)}")
    
    {:consumer, state, subscribe_to: subscribe_to}
  end
  
  @impl true
  def handle_events(events, _from, %__MODULE__{patterns: patterns, actions: actions, stats: stats} = state) do
    {processed_events, new_stats} = process_events(events, patterns, actions, stats)
    
    log_processing_stats(processed_events, new_stats)
    
    {:noreply, [], %{state | stats: new_stats}}
  end
  
  @doc """
  Get processing statistics for the consumer.
  """
  def get_stats(consumer \\ __MODULE__) do
    GenStage.call(consumer, :get_stats)
  end
  
  @doc """
  Reset processing statistics.
  """
  def reset_stats(consumer \\ __MODULE__) do
    GenStage.call(consumer, :reset_stats)
  end
  
  @impl true
  def handle_call(:get_stats, _from, %__MODULE__{stats: stats} = state) do
    {:reply, stats, [], state}
  end
  
  @impl true
  def handle_call(:reset_stats, _from, %__MODULE__{patterns: patterns} = state) do
    new_stats = init_stats(patterns)
    {:reply, :ok, [], %{state | stats: new_stats}}
  end
  
  # Private functions
  
  defp init_stats(patterns) do
    base_stats = %{
      total_events: 0,
      total_matches: 0,
      processing_time_ms: 0,
      start_time: System.system_time(:millisecond)
    }
    
    pattern_stats = 
      patterns
      |> Enum.map(fn pattern -> {pattern, %{matches: 0, last_match: nil}} end)
      |> Map.new()
    
    Map.put(base_stats, :patterns, pattern_stats)
  end
  
  defp process_events(events, patterns, actions, stats) do
    start_time = System.monotonic_time(:millisecond)
    
    {processed_events, pattern_matches} = 
      Enum.reduce(events, {[], %{}}, fn event_data, {acc_events, acc_matches} ->
        event = Map.get(event_data, :event, event_data)
        
        # Test event against all patterns
        matches = test_event_against_patterns(event, patterns)
        
        # Execute actions for matched patterns
        executed_actions = execute_pattern_actions(matches, event, actions)
        
        processed_event = %{
          original: event_data,
          event: event,
          matches: matches,
          actions_executed: executed_actions,
          timestamp: System.system_time(:millisecond)
        }
        
        # Accumulate pattern matches
        updated_matches = 
          Enum.reduce(matches, acc_matches, fn pattern, acc ->
            Map.update(acc, pattern, 1, &(&1 + 1))
          end)
        
        {[processed_event | acc_events], updated_matches}
      end)
    
    end_time = System.monotonic_time(:millisecond)
    processing_time = end_time - start_time
    
    # Update statistics
    total_matches = pattern_matches |> Map.values() |> Enum.sum()
    
    new_stats = stats
    |> Map.update!(:total_events, &(&1 + length(events)))
    |> Map.update!(:total_matches, &(&1 + total_matches))
    |> Map.update!(:processing_time_ms, &(&1 + processing_time))
    |> update_pattern_stats(pattern_matches)
    
    {Enum.reverse(processed_events), new_stats}
  end
  
  defp test_event_against_patterns(event, patterns) do
    Enum.filter(patterns, fn pattern_id ->
      case VsmGoldrush.test_event(pattern_id, event) do
        {:ok, true} -> true
        {:ok, false} -> false
      end
    end)
  end
  
  defp execute_pattern_actions(matched_patterns, event, actions) do
    Enum.reduce(matched_patterns, [], fn pattern_id, acc ->
      case Map.get(actions, pattern_id) do
        nil -> acc
        action_fn when is_function(action_fn, 2) ->
          try do
            result = action_fn.(pattern_id, event)
            [{pattern_id, :ok, result} | acc]
          rescue
            error ->
              Logger.error("Action failed for pattern #{pattern_id}: #{inspect(error)}")
              [{pattern_id, :error, error} | acc]
          end
        action_fn when is_function(action_fn, 1) ->
          try do
            result = action_fn.(event)
            [{pattern_id, :ok, result} | acc]
          rescue
            error ->
              Logger.error("Action failed for pattern #{pattern_id}: #{inspect(error)}")
              [{pattern_id, :error, error} | acc]
          end
        _ ->
          Logger.warning("Invalid action for pattern #{pattern_id}")
          acc
      end
    end)
  end
  
  defp update_pattern_stats(stats, pattern_matches) do
    current_time = System.system_time(:millisecond)
    
    Map.update!(stats, :patterns, fn pattern_stats ->
      Enum.reduce(pattern_matches, pattern_stats, fn {pattern_id, count}, acc ->
        Map.update(acc, pattern_id, %{matches: count, last_match: current_time}, fn existing ->
          %{
            matches: existing.matches + count,
            last_match: current_time
          }
        end)
      end)
    end)
  end
  
  defp log_processing_stats(processed_events, _stats) do
    if length(processed_events) > 0 do
      total_matches = processed_events |> Enum.map(&length(&1.matches)) |> Enum.sum()
      match_rate = if length(processed_events) > 0, do: total_matches / length(processed_events) * 100, else: 0
      
      Logger.debug("Processed #{length(processed_events)} events, #{total_matches} total matches (#{Float.round(match_rate, 2)}% match rate)")
    end
  end
end