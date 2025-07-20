defmodule VsmGoldrush do
  @moduledoc """
  VSM-aware wrapper for the goldrush event processing library.
  
  This library provides:
  - High-performance compiled event queries via goldrush
  - VSM cybernetic pattern detection
  - Event format conversion between VSM and goldrush
  - Built-in statistics and monitoring
  
  ## Architecture
  
  VsmGoldrush uses goldrush's compiled query approach where patterns are
  compiled into BEAM modules for maximum performance. Events flow through:
  
  1. VSM Event (map) -> Goldrush Event (property list)
  2. Compiled Query Module (native BEAM speed)
  3. Pattern Actions & Statistics
  
  ## Example
  
      # Compile a VSM pattern
      VsmGoldrush.compile_pattern(:high_variety, %{
        field: :variety_ratio,
        operator: :gt,
        value: 0.8
      })
      
      # Process events
      event = %{type: "channel_state", variety_ratio: 0.85, subsystem: "S1"}
      VsmGoldrush.process_event(:high_variety, event)
      # => {:match, event}
  """
  
  require Logger
  
  @type pattern_id :: atom()
  @type vsm_event :: map()
  @type pattern_spec :: map()
  @type match_result :: {:match, vsm_event()} | :no_match
  
  @doc """
  Initialize the VsmGoldrush system.
  """
  def init do
    :application.ensure_all_started(:goldrush)
    Logger.info("VsmGoldrush initialized with goldrush #{Application.spec(:goldrush, :vsn)}")
    :ok
  end
  
  @doc """
  Compile a VSM pattern into a high-performance goldrush query.
  
  ## Pattern Specifications
  
  Simple patterns:
      %{field: :latency, operator: :gt, value: 100}
      
  Compound patterns:
      %{all: [
        %{field: :type, operator: :eq, value: "failure"},
        %{field: :severity, operator: :gte, value: :high}
      ]}
      
  VSM-specific patterns:
      %{vsm_pattern: :variety_explosion}
  """
  @spec compile_pattern(pattern_id(), pattern_spec()) :: {:ok, pattern_id()} | {:error, term()}
  def compile_pattern(id, spec) when is_atom(id) do
    case VsmGoldrush.QueryBuilder.build_query(spec) do
      {:ok, query} ->
        # We need to use 'with' to get proper match detection
        # Create a simple output function that signals matches
        match_query = :glc.with(query, fn _event -> :matched end)
        
        try do
          {:ok, ^id} = :glc.compile(id, match_query)
          VsmGoldrush.PatternRegistry.register(id)
          Logger.info("Compiled VSM pattern: #{id}")
          {:ok, id}
        rescue
          e ->
            Logger.error("Failed to compile pattern #{id}: #{inspect(e)}")
            {:error, e}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Process an event through a compiled pattern.
  """
  @spec process_event(pattern_id(), vsm_event()) :: match_result()
  def process_event(pattern_id, event) when is_atom(pattern_id) and is_map(event) do
    gr_event = VsmGoldrush.EventConverter.to_goldrush(event)
    
    # Get current output count before processing
    before_count = try do
      :glc.output(pattern_id)
    catch
      _, _ -> 0
    end
    
    # Process the event
    :glc.handle(pattern_id, gr_event)
    
    # Check if output count increased (meaning it matched)
    after_count = try do
      :glc.output(pattern_id)
    catch  
      _, _ -> 0
    end
    
    if after_count > before_count do
      {:match, event}
    else
      :no_match
    end
  end
  
  @doc """
  Compile a pattern with an action function that executes on matches.
  """
  @spec compile_pattern_with_action(pattern_id(), pattern_spec(), (vsm_event() -> any())) :: 
    {:ok, pattern_id()} | {:error, term()}
  def compile_pattern_with_action(id, spec, action_fn) 
      when is_atom(id) and is_function(action_fn, 1) do
    case VsmGoldrush.QueryBuilder.build_query(spec) do
      {:ok, query} ->
        # Wrap the action to handle goldrush event format
        wrapped_action = fn gr_event ->
          vsm_event = VsmGoldrush.EventConverter.from_goldrush(gr_event)
          action_fn.(vsm_event)
        end
        
        query_with_action = :glc.with(query, wrapped_action)
        
        try do
          {:ok, ^id} = :glc.compile(id, query_with_action)
          VsmGoldrush.PatternRegistry.register(id)
          Logger.info("Compiled VSM pattern with action: #{id}")
          {:ok, id}
        rescue
          e ->
            Logger.error("Failed to compile pattern #{id}: #{inspect(e)}")
            {:error, e}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Get statistics for a pattern.
  """
  @spec get_stats(pattern_id()) :: map() | {:error, :not_found}
  def get_stats(pattern_id) when is_atom(pattern_id) do
    try do
      %{
        input_count: :glc.input(pattern_id),
        output_count: :glc.output(pattern_id),
        filter_count: :glc.filter(pattern_id),
        info: :glc.info(pattern_id)
      }
    catch
      _, _ -> {:error, :not_found}
    end
  end
  
  @doc """
  Reset statistics for a pattern.
  """
  @spec reset_stats(pattern_id()) :: :ok | {:error, :not_found}
  def reset_stats(pattern_id) when is_atom(pattern_id) do
    try do
      # Reset all counters
      :glc.reset_counters(pattern_id)
      :ok
    catch
      _, _ -> {:error, :not_found}
    end
  end
  
  @doc """
  Delete a compiled pattern.
  """
  @spec delete_pattern(pattern_id()) :: :ok | {:error, :not_found}
  def delete_pattern(pattern_id) when is_atom(pattern_id) do
    try do
      :ok = :glc.delete(pattern_id)
      VsmGoldrush.PatternRegistry.unregister(pattern_id)
      Logger.info("Deleted pattern: #{pattern_id}")
      :ok
    catch
      _, _ -> {:error, :not_found}
    end
  end
  
  @doc """
  List all compiled patterns.
  """
  @spec list_patterns() :: [pattern_id()]
  def list_patterns do
    VsmGoldrush.PatternRegistry.list_patterns()
  end
  
  @doc """
  Compile all VSM cybernetic patterns.
  """
  def compile_vsm_patterns do
    VsmGoldrush.Patterns.Cybernetic.compile_all()
  end
end