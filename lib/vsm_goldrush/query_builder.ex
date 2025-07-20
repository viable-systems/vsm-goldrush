defmodule VsmGoldrush.QueryBuilder do
  @moduledoc """
  Builds goldrush queries from VSM pattern specifications.
  
  Supports:
  - Simple field comparisons (eq, gt, lt, etc.)
  - Compound queries (all, any)
  - VSM-specific patterns (variety explosion, channel saturation, etc.)
  - Temporal patterns with time windows
  """
  
  @type pattern_spec :: map()
  @type goldrush_query :: term()
  
  @doc """
  Build a goldrush query from a VSM pattern specification.
  
  ## Examples
  
      # Simple comparison
      iex> VsmGoldrush.QueryBuilder.build_query(%{field: :latency, operator: :gt, value: 100})
      {:ok, {:glc, :gt, [:latency, 100]}}
      
      # Compound query
      iex> VsmGoldrush.QueryBuilder.build_query(%{
      ...>   all: [
      ...>     %{field: :type, operator: :eq, value: "error"},
      ...>     %{field: :severity, operator: :gte, value: :high}
      ...>   ]
      ...> })
      {:ok, {:glc, :all, [[{:glc, :eq, [:type, "error"]}, {:glc, :gte, [:severity, :high]}]]}}
  """
  @spec build_query(pattern_spec()) :: {:ok, goldrush_query()} | {:error, String.t()}
  def build_query(%{field: field, operator: op, value: value}) do
    case build_operator(op, field, value) do
      {:ok, query} -> {:ok, query}
      :error -> {:error, "Unsupported operator: #{op}"}
    end
  end
  
  def build_query(%{all: conditions}) when is_list(conditions) do
    case build_compound_query(conditions) do
      {:ok, queries} -> {:ok, :glc.all(queries)}
      error -> error
    end
  end
  
  def build_query(%{any: conditions}) when is_list(conditions) do
    case build_compound_query(conditions) do
      {:ok, queries} -> {:ok, :glc.any(queries)}
      error -> error
    end
  end
  
  def build_query(%{vsm_pattern: pattern_name}) when is_atom(pattern_name) do
    build_vsm_pattern(pattern_name)
  end
  
  def build_query(%{temporal: %{pattern: pattern, window: window}}) do
    build_temporal_query(pattern, window)
  end
  
  def build_query(spec) do
    {:error, "Invalid pattern specification: #{inspect(spec)}"}
  end
  
  # Build operator queries
  defp build_operator(:eq, field, value), do: {:ok, :glc.eq(field, value)}
  defp build_operator(:neq, field, value), do: {:ok, :glc.neq(field, value)}
  defp build_operator(:gt, field, value), do: {:ok, :glc.gt(field, value)}
  defp build_operator(:gte, field, value), do: {:ok, :glc.gte(field, value)}
  defp build_operator(:lt, field, value), do: {:ok, :glc.lt(field, value)}
  defp build_operator(:lte, field, value), do: {:ok, :glc.lte(field, value)}
  defp build_operator(:exists, field, _), do: {:ok, :glc.wc(field)}
  defp build_operator(:not_exists, field, _), do: {:ok, :glc.nf(field)}
  defp build_operator(_, _, _), do: :error
  
  # Build compound queries
  defp build_compound_query(conditions) do
    results = Enum.map(conditions, &build_query/1)
    
    case Enum.find(results, fn
      {:error, _} -> true
      _ -> false
    end) do
      nil ->
        queries = Enum.map(results, fn {:ok, q} -> q end)
        {:ok, queries}
      error ->
        error
    end
  end
  
  # VSM-specific patterns
  defp build_vsm_pattern(:variety_explosion) do
    {:ok, :glc.all([
      :glc.eq(:type, "variety_state"),
      :glc.gt(:variety_ratio, 0.8),
      :glc.gt(:channel_load, 0.9)
    ])}
  end
  
  defp build_vsm_pattern(:channel_saturation) do
    {:ok, :glc.all([
      :glc.eq(:type, "channel_state"),
      :glc.any([
        :glc.gte(:queue_depth, 1000),
        :glc.gte(:latency, 5000),
        :glc.gte(:drop_rate, 0.05)
      ])
    ])}
  end
  
  defp build_vsm_pattern(:recursion_violation) do
    {:ok, :glc.all([
      :glc.eq(:type, "recursion_error"),
      :glc.any([
        :glc.eq(:error, "level_crossing"),
        :glc.eq(:error, "autonomy_breach"),
        :glc.eq(:error, "meta_interference")
      ])
    ])}
  end
  
  defp build_vsm_pattern(:algedonic_signal) do
    {:ok, :glc.all([
      :glc.eq(:type, "algedonic"),
      :glc.any([
        :glc.gte(:pain_level, 0.7),
        :glc.lte(:pleasure_level, 0.3)
      ])
    ])}
  end
  
  defp build_vsm_pattern(:s1_s3_breakdown) do
    {:ok, :glc.all([
      :glc.eq(:channel, "S1-S3"),
      :glc.any([
        :glc.eq(:state, "disconnected"),
        :glc.gt(:error_rate, 0.1),
        :glc.lt(:throughput, 0.5)
      ])
    ])}
  end
  
  defp build_vsm_pattern(pattern) do
    {:error, "Unknown VSM pattern: #{pattern}"}
  end
  
  @doc """
  Build temporal sequence query for detecting event patterns over time.
  """
  def build_temporal_query(%{type: :temporal_sequence, sequence: events}) do
    # For sequences, build a query that matches the first event
    # The actual sequence logic is handled by the temporal wrapper
    case List.first(events) do
      nil -> {:error, "Empty sequence"}
      first_event -> build_query(first_event)
    end
  end
  
  @doc """
  Build temporal frequency query for counting events in time windows.
  """
  def build_frequency_query(%{type: :temporal_frequency, filter: filter}) do
    # Build a base query for the event filter
    # Frequency counting is handled by the temporal wrapper
    build_query(filter)
  end
  
  @doc """
  Build temporal correlation query for trigger-response patterns.
  """
  def build_correlation_query(%{type: :temporal_correlation, trigger: trigger}) do
    # Build a query that matches the trigger event
    # Response correlation is handled by the temporal wrapper
    build_query(trigger)
  end
  
  # Legacy temporal patterns (kept for backward compatibility)
  defp build_temporal_query(:frequency, %{field: field, threshold: _threshold, window: _window}) do
    {:ok, :glc.all([
      :glc.wc(field),
      :glc.eq(:_temporal_marker, true)
    ])}
  end
  
  defp build_temporal_query(:sequence, %{events: events, window: _window}) do
    first_event = List.first(events)
    case build_query(first_event) do
      {:ok, query} -> {:ok, query}
      error -> error
    end
  end
  
  defp build_temporal_query(_, _) do
    {:error, "Temporal patterns require additional state management"}
  end
end