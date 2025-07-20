#!/usr/bin/env elixir

# Basic usage example for vsm-goldrush
# Run with: elixir examples/basic_usage.exs

# Add the parent directory to the code path so we can use vsm_goldrush
Code.prepend_path("_build/dev/lib/vsm_goldrush/ebin")
Code.prepend_path("_build/dev/lib/goldrush/ebin")

# Start the required applications
Application.ensure_all_started(:goldrush)
Application.ensure_all_started(:vsm_goldrush)

defmodule BasicExample do
  require Logger
  
  def run do
    Logger.info("Starting VSM-Goldrush basic example")
    
    # Initialize
    :ok = VsmGoldrush.init()
    
    # Compile a simple pattern
    Logger.info("Compiling high temperature pattern...")
    {:ok, :high_temp} = VsmGoldrush.compile_pattern(:high_temp, %{
      field: :temperature,
      operator: :gt,
      value: 30
    })
    
    # Compile a compound pattern
    Logger.info("Compiling critical system state pattern...")
    {:ok, :critical_state} = VsmGoldrush.compile_pattern(:critical_state, %{
      all: [
        %{field: :system, operator: :eq, value: "cooling"},
        %{field: :temperature, operator: :gt, value: 40},
        %{field: :pressure, operator: :gt, value: 100}
      ]
    })
    
    # Compile a VSM cybernetic pattern
    Logger.info("Compiling variety explosion pattern...")
    {:ok, :variety_explosion} = VsmGoldrush.compile_pattern(:variety_explosion, %{
      vsm_pattern: :variety_explosion
    })
    
    # Test events
    events = [
      %{temperature: 25, location: "office"},
      %{temperature: 35, location: "server_room"},
      %{system: "cooling", temperature: 45, pressure: 120},
      %{system: "cooling", temperature: 45, pressure: 80},
      %{type: "variety_state", variety_ratio: 0.85, channel_load: 0.95},
      %{type: "variety_state", variety_ratio: 0.6, channel_load: 0.7}
    ]
    
    # Process events
    Logger.info("\nProcessing events...")
    Enum.each(events, fn event ->
      IO.puts("\nEvent: #{inspect(event)}")
      
      # Test against high_temp pattern
      case VsmGoldrush.process_event(:high_temp, event) do
        {:match, _} -> IO.puts("  ✓ Matches high_temp pattern")
        :no_match -> IO.puts("  ✗ Does not match high_temp pattern")
      end
      
      # Test against critical_state pattern
      case VsmGoldrush.process_event(:critical_state, event) do
        {:match, _} -> IO.puts("  ✓ Matches critical_state pattern")
        :no_match -> IO.puts("  ✗ Does not match critical_state pattern")
      end
      
      # Test against variety_explosion pattern
      case VsmGoldrush.process_event(:variety_explosion, event) do
        {:match, _} -> IO.puts("  ✓ Matches variety_explosion pattern")
        :no_match -> IO.puts("  ✗ Does not match variety_explosion pattern")
      end
    end)
    
    # Show statistics
    Logger.info("\nPattern statistics:")
    [:high_temp, :critical_state, :variety_explosion]
    |> Enum.each(fn pattern ->
      stats = VsmGoldrush.get_stats(pattern)
      IO.puts("\n#{pattern}:")
      IO.puts("  Input events: #{stats.input_count}")
      IO.puts("  Matched events: #{stats.output_count}")
      IO.puts("  Filtered events: #{stats.filter_count}")
    end)
    
    # List all patterns
    patterns = VsmGoldrush.list_patterns()
    Logger.info("\nAll compiled patterns: #{inspect(patterns)}")
    
    # Clean up
    Logger.info("\nCleaning up patterns...")
    Enum.each(patterns, &VsmGoldrush.delete_pattern/1)
    
    Logger.info("Example completed!")
  end
end

# Run the example
BasicExample.run()