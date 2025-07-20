defmodule VsmGoldrush.Temporal do
  @moduledoc """
  Temporal pattern detection using goldrush for time-based event analysis.
  
  This module provides functionality to detect patterns across time windows,
  sequences of events, and temporal relationships between VSM system events.
  """
  
  require Logger
  
  @doc """
  Compile a temporal pattern that detects event sequences within time windows.
  
  ## Examples
  
      # Detect variety explosion followed by algedonic signal within 5 seconds
      {:ok, :cascade_failure} = VsmGoldrush.Temporal.compile_sequence_pattern(
        :cascade_failure,
        [
          %{type: :variety_explosion, system: :s1},
          %{type: :algedonic_signal, severity: :high}
        ],
        5000  # 5 second window
      )
  
  """
  def compile_sequence_pattern(pattern_id, event_sequence, time_window_ms) when is_list(event_sequence) do
    # Create a goldrush query that tracks temporal sequences
    # We use goldrush's time-based filtering with custom logic
    
    query_spec = %{
      type: :temporal_sequence,
      sequence: event_sequence,
      time_window: time_window_ms,
      state: :initial
    }
    
    case VsmGoldrush.QueryBuilder.build_temporal_query(query_spec) do
      {:ok, query} ->
        # Wrap with temporal state tracking
        temporal_query = wrap_with_temporal_logic(query, pattern_id, query_spec)
        
        case :glc.compile(pattern_id, temporal_query) do
          {:ok, ^pattern_id} ->
            # Initialize temporal state for this pattern
            init_temporal_state(pattern_id, query_spec)
            
            # Register with the main pattern registry
            VsmGoldrush.PatternRegistry.register(pattern_id)
            
            Logger.info("Compiled temporal sequence pattern: #{pattern_id}")
            {:ok, pattern_id}
          
          error ->
            Logger.error("Failed to compile temporal pattern #{pattern_id}: #{inspect(error)}")
            error
        end
      
      error ->
        error
    end
  end
  
  @doc """
  Compile a frequency-based temporal pattern (events per time window).
  
  ## Examples
  
      # Detect more than 10 variety explosions in 30 seconds
      {:ok, :variety_storm} = VsmGoldrush.Temporal.compile_frequency_pattern(
        :variety_storm,
        %{type: :variety_explosion},
        10,    # threshold count
        30000  # 30 second window
      )
  
  """
  def compile_frequency_pattern(pattern_id, event_filter, threshold_count, time_window_ms) do
    query_spec = %{
      type: :temporal_frequency,
      filter: event_filter,
      threshold: threshold_count,
      window: time_window_ms
    }
    
    case VsmGoldrush.QueryBuilder.build_frequency_query(query_spec) do
      {:ok, query} ->
        # Wrap with frequency counting logic
        frequency_query = wrap_with_frequency_logic(query, pattern_id, query_spec)
        
        case :glc.compile(pattern_id, frequency_query) do
          {:ok, ^pattern_id} ->
            # Initialize frequency tracking for this pattern
            init_frequency_state(pattern_id, query_spec)
            
            # Register with the main pattern registry
            VsmGoldrush.PatternRegistry.register(pattern_id)
            
            Logger.info("Compiled temporal frequency pattern: #{pattern_id}")
            {:ok, pattern_id}
          
          error ->
            Logger.error("Failed to compile frequency pattern #{pattern_id}: #{inspect(error)}")
            error
        end
      
      error ->
        error
    end
  end
  
  @doc """
  Compile a pattern that detects temporal correlations between different systems.
  
  ## Examples
  
      # Detect S1 overload followed by S3 intervention within 2 seconds
      {:ok, :control_response} = VsmGoldrush.Temporal.compile_correlation_pattern(
        :control_response,
        %{trigger: %{system: :s1, type: :overload}, response: %{system: :s3, type: :intervention}},
        2000  # 2 second correlation window
      )
  
  """
  def compile_correlation_pattern(pattern_id, correlation_spec, time_window_ms) do
    query_spec = %{
      type: :temporal_correlation,
      trigger: Map.get(correlation_spec, :trigger),
      response: Map.get(correlation_spec, :response),
      window: time_window_ms
    }
    
    case VsmGoldrush.QueryBuilder.build_correlation_query(query_spec) do
      {:ok, query} ->
        # Wrap with correlation tracking logic
        correlation_query = wrap_with_correlation_logic(query, pattern_id, query_spec)
        
        case :glc.compile(pattern_id, correlation_query) do
          {:ok, ^pattern_id} ->
            # Initialize correlation tracking for this pattern
            init_correlation_state(pattern_id, query_spec)
            
            # Register with the main pattern registry
            VsmGoldrush.PatternRegistry.register(pattern_id)
            
            Logger.info("Compiled temporal correlation pattern: #{pattern_id}")
            {:ok, pattern_id}
          
          error ->
            Logger.error("Failed to compile correlation pattern #{pattern_id}: #{inspect(error)}")
            error
        end
      
      error ->
        error
    end
  end
  
  @doc """
  Get temporal statistics for a pattern (events in time windows, frequencies, etc.).
  """
  def get_temporal_stats(pattern_id) do
    case :ets.whereis(:vsm_temporal_state) do
      :undefined ->
        {:error, :pattern_not_found}
      
      _table ->
        case :ets.lookup(:vsm_temporal_state, pattern_id) do
          [{^pattern_id, state}] ->
            {:ok, format_temporal_stats(state)}
          
          [] ->
            {:error, :pattern_not_found}
        end
    end
  end
  
  @doc """
  Clear temporal state for a pattern (useful for testing or reset).
  """
  def clear_temporal_state(pattern_id) do
    case :ets.whereis(:vsm_temporal_state) do
      :undefined ->
        :ok
      
      _table ->
        :ets.delete(:vsm_temporal_state, pattern_id)
        :ok
    end
  end
  
  # Private helper functions
  
  defp wrap_with_temporal_logic(base_query, pattern_id, query_spec) do
    # Create a function that tracks sequence state
    temporal_fn = fn event ->
      update_sequence_state(pattern_id, event, query_spec)
    end
    
    :glc.with(base_query, temporal_fn)
  end
  
  defp wrap_with_frequency_logic(base_query, pattern_id, query_spec) do
    # Create a function that tracks event frequency
    frequency_fn = fn event ->
      update_frequency_state(pattern_id, event, query_spec)
    end
    
    :glc.with(base_query, frequency_fn)
  end
  
  defp wrap_with_correlation_logic(base_query, pattern_id, query_spec) do
    # Create a function that tracks trigger-response correlations
    correlation_fn = fn event ->
      update_correlation_state(pattern_id, event, query_spec)
    end
    
    :glc.with(base_query, correlation_fn)
  end
  
  defp init_temporal_state(pattern_id, query_spec) do
    ensure_temporal_table()
    
    state = %{
      type: :sequence,
      spec: query_spec,
      current_step: 0,
      sequence_start: nil,
      events: [],
      matches: 0,
      created_at: System.system_time(:millisecond)
    }
    
    :ets.insert(:vsm_temporal_state, {pattern_id, state})
  end
  
  defp init_frequency_state(pattern_id, query_spec) do
    ensure_temporal_table()
    
    state = %{
      type: :frequency,
      spec: query_spec,
      events: [],
      current_count: 0,
      matches: 0,
      created_at: System.system_time(:millisecond)
    }
    
    :ets.insert(:vsm_temporal_state, {pattern_id, state})
  end
  
  defp init_correlation_state(pattern_id, query_spec) do
    ensure_temporal_table()
    
    state = %{
      type: :correlation,
      spec: query_spec,
      pending_triggers: [],
      matches: 0,
      created_at: System.system_time(:millisecond)
    }
    
    :ets.insert(:vsm_temporal_state, {pattern_id, state})
  end
  
  defp ensure_temporal_table do
    case :ets.whereis(:vsm_temporal_state) do
      :undefined ->
        :ets.new(:vsm_temporal_state, [:named_table, :public, :set])
      
      _table ->
        :ok
    end
  end
  
  defp update_sequence_state(pattern_id, event, _query_spec) do
    case :ets.lookup(:vsm_temporal_state, pattern_id) do
      [{^pattern_id, state}] ->
        new_state = process_sequence_event(state, event)
        :ets.insert(:vsm_temporal_state, {pattern_id, new_state})
        
        # Return whether this event completed the sequence
        case new_state do
          %{current_step: step, spec: %{sequence: sequence}} when step >= length(sequence) ->
            :sequence_matched
          
          _ ->
            :sequence_continue
        end
      
      [] ->
        :pattern_not_found
    end
  end
  
  defp update_frequency_state(pattern_id, event, _query_spec) do
    current_time = System.system_time(:millisecond)
    
    case :ets.lookup(:vsm_temporal_state, pattern_id) do
      [{^pattern_id, state}] ->
        new_state = process_frequency_event(state, event, current_time)
        :ets.insert(:vsm_temporal_state, {pattern_id, new_state})
        
        # Check if threshold was exceeded
        %{current_count: count, spec: %{threshold: threshold}} = new_state
        if count >= threshold do
          :frequency_threshold_exceeded
        else
          :frequency_continue
        end
      
      [] ->
        :pattern_not_found
    end
  end
  
  defp update_correlation_state(pattern_id, event, _query_spec) do
    current_time = System.system_time(:millisecond)
    
    case :ets.lookup(:vsm_temporal_state, pattern_id) do
      [{^pattern_id, state}] ->
        new_state = process_correlation_event(state, event, current_time)
        :ets.insert(:vsm_temporal_state, {pattern_id, new_state})
        
        # Check if we found a correlation
        case new_state do
          %{matches: matches} when matches > state.matches ->
            :correlation_found
          
          _ ->
            :correlation_continue
        end
      
      [] ->
        :pattern_not_found
    end
  end
  
  defp process_sequence_event(state, event) do
    %{
      current_step: step,
      spec: %{sequence: sequence, time_window: window},
      sequence_start: start_time,
      events: events
    } = state
    
    current_time = System.system_time(:millisecond)
    
    # Check if we're starting a new sequence or continuing one
    cond do
      step >= length(sequence) ->
        # Sequence complete, reset for next sequence
        %{state | current_step: 0, sequence_start: nil, events: []}
      
      step == 0 ->
        # Starting new sequence
        if event_matches_step(event, Enum.at(sequence, 0)) do
          %{state | 
            current_step: 1, 
            sequence_start: current_time, 
            events: [%{event: event, timestamp: current_time}]
          }
        else
          state
        end
      
      start_time && (current_time - start_time) > window ->
        # Time window expired, reset
        %{state | current_step: 0, sequence_start: nil, events: []}
      
      true ->
        # Continue sequence
        if event_matches_step(event, Enum.at(sequence, step)) do
          new_events = [%{event: event, timestamp: current_time} | events]
          new_step = step + 1
          
          if new_step >= length(sequence) do
            # Sequence complete!
            %{state | 
              current_step: new_step, 
              events: new_events, 
              matches: state.matches + 1
            }
          else
            %{state | current_step: new_step, events: new_events}
          end
        else
          # Event doesn't match, reset sequence
          %{state | current_step: 0, sequence_start: nil, events: []}
        end
    end
  end
  
  defp process_frequency_event(state, event, current_time) do
    %{
      events: events,
      spec: %{window: window, filter: filter}
    } = state
    
    # Add current event if it matches filter
    new_events = if event_matches_filter(event, filter) do
      [%{event: event, timestamp: current_time} | events]
    else
      events
    end
    
    # Remove events outside time window
    cutoff_time = current_time - window
    recent_events = Enum.filter(new_events, fn %{timestamp: ts} -> ts >= cutoff_time end)
    
    %{state | events: recent_events, current_count: length(recent_events)}
  end
  
  defp process_correlation_event(state, event, current_time) do
    %{
      pending_triggers: triggers,
      spec: %{trigger: trigger_spec, response: response_spec, window: window}
    } = state
    
    # Remove expired triggers
    cutoff_time = current_time - window
    active_triggers = Enum.filter(triggers, fn %{timestamp: ts} -> ts >= cutoff_time end)
    
    cond do
      event_matches_filter(event, trigger_spec) ->
        # This is a trigger event
        new_trigger = %{event: event, timestamp: current_time}
        %{state | pending_triggers: [new_trigger | active_triggers]}
      
      event_matches_filter(event, response_spec) && length(active_triggers) > 0 ->
        # This is a response event and we have pending triggers
        %{state | 
          pending_triggers: [], 
          matches: state.matches + 1
        }
      
      true ->
        # Neither trigger nor response, just clean up expired triggers
        %{state | pending_triggers: active_triggers}
    end
  end
  
  defp event_matches_step(event, step_spec) do
    event_matches_filter(event, step_spec)
  end
  
  defp event_matches_filter(event, filter) when is_map(event) and is_map(filter) do
    Enum.all?(filter, fn {key, expected_value} ->
      Map.get(event, key) == expected_value
    end)
  end
  
  defp event_matches_filter(_, _), do: false
  
  defp format_temporal_stats(%{type: :sequence} = state) do
    %{
      type: :sequence,
      current_step: state.current_step,
      total_matches: state.matches,
      sequence_active: state.sequence_start != nil,
      events_in_sequence: length(state.events)
    }
  end
  
  defp format_temporal_stats(%{type: :frequency} = state) do
    %{
      type: :frequency,
      current_count: state.current_count,
      total_matches: state.matches,
      events_in_window: length(state.events),
      threshold: state.spec.threshold
    }
  end
  
  defp format_temporal_stats(%{type: :correlation} = state) do
    %{
      type: :correlation,
      pending_triggers: length(state.pending_triggers),
      total_matches: state.matches,
      window_ms: state.spec.window
    }
  end
end