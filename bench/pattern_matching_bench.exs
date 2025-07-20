# Benchmark comparing goldrush compiled patterns vs naive pattern matching
# Run with: mix run bench/pattern_matching_bench.exs

Application.ensure_all_started(:vsm_goldrush)

defmodule NaivePatternMatcher do
  @doc """
  Naive pattern matching implementation for comparison
  """
  def match_high_variety(event) do
    event[:type] == "variety_state" and
    event[:variety_ratio] > 0.8 and
    event[:channel_load] > 0.9
  end
  
  def match_complex(event) do
    event[:type] == "system_state" and
    event[:severity] == :critical and
    (event[:error_rate] > 0.5 or event[:response_time] > 1000) and
    event[:subsystem] in ["S1", "S2", "S3"]
  end
end

# Compile goldrush patterns
{:ok, _} = VsmGoldrush.compile_pattern(:bench_high_variety, %{
  all: [
    %{field: :type, operator: :eq, value: "variety_state"},
    %{field: :variety_ratio, operator: :gt, value: 0.8},
    %{field: :channel_load, operator: :gt, value: 0.9}
  ]
})

{:ok, _} = VsmGoldrush.compile_pattern(:bench_complex, %{
  all: [
    %{field: :type, operator: :eq, value: "system_state"},
    %{field: :severity, operator: :eq, value: :critical},
    %{any: [
      %{field: :error_rate, operator: :gt, value: 0.5},
      %{field: :response_time, operator: :gt, value: 1000}
    ]},
    %{field: :subsystem, operator: :exists, value: true}
  ]
})

# Generate test events
events = for i <- 1..10_000 do
  %{
    type: Enum.random(["variety_state", "system_state", "normal_state"]),
    variety_ratio: :rand.uniform(),
    channel_load: :rand.uniform(),
    severity: Enum.random([:low, :medium, :high, :critical]),
    error_rate: :rand.uniform(),
    response_time: :rand.uniform(2000),
    subsystem: Enum.random(["S1", "S2", "S3", "S4", "S5"])
  }
end

IO.puts("Benchmarking pattern matching with #{length(events)} events...\n")

Benchee.run(%{
  "Naive High Variety" => fn ->
    Enum.filter(events, &NaivePatternMatcher.match_high_variety/1)
  end,
  "Goldrush High Variety" => fn ->
    Enum.filter(events, fn event ->
      case VsmGoldrush.process_event(:bench_high_variety, event) do
        {:match, _} -> true
        :no_match -> false
      end
    end)
  end,
  "Naive Complex" => fn ->
    Enum.filter(events, &NaivePatternMatcher.match_complex/1)
  end,
  "Goldrush Complex" => fn ->
    Enum.filter(events, fn event ->
      case VsmGoldrush.process_event(:bench_complex, event) do
        {:match, _} -> true
        :no_match -> false
      end
    end)
  end
}, time: 10, memory_time: 2)

# Show pattern statistics
IO.puts("\nPattern Statistics:")
[:bench_high_variety, :bench_complex] |> Enum.each(fn pattern ->
  stats = VsmGoldrush.get_stats(pattern)
  IO.puts("\n#{pattern}:")
  IO.puts("  Total events processed: #{stats.input_count}")
  IO.puts("  Matched events: #{stats.output_count}")
  IO.puts("  Match rate: #{Float.round(stats.output_count / stats.input_count * 100, 2)}%")
end)

# Cleanup
VsmGoldrush.delete_pattern(:bench_high_variety)
VsmGoldrush.delete_pattern(:bench_complex)