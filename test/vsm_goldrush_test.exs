defmodule VsmGoldrushTest do
  use ExUnit.Case
  doctest VsmGoldrush
  
  setup do
    # Ensure goldrush is started
    :ok = VsmGoldrush.init()
    
    # Clean up any existing patterns
    VsmGoldrush.list_patterns()
    |> Enum.each(&VsmGoldrush.delete_pattern/1)
    
    # Also clear the registry in case of orphaned entries
    if Process.whereis(VsmGoldrush.PatternRegistry) do
      VsmGoldrush.PatternRegistry.clear_all()
    end
    
    :ok
  end
  
  describe "pattern compilation" do
    test "compiles simple field comparison pattern" do
      assert {:ok, :high_latency} = VsmGoldrush.compile_pattern(:high_latency, %{
        field: :latency,
        operator: :gt,
        value: 100
      })
      
      # Verify it's in the list
      assert :high_latency in VsmGoldrush.list_patterns()
    end
    
    test "compiles compound ALL pattern" do
      assert {:ok, :critical_error} = VsmGoldrush.compile_pattern(:critical_error, %{
        all: [
          %{field: :type, operator: :eq, value: "error"},
          %{field: :severity, operator: :gte, value: :high}
        ]
      })
    end
    
    test "compiles compound ANY pattern" do
      assert {:ok, :warning_or_error} = VsmGoldrush.compile_pattern(:warning_or_error, %{
        any: [
          %{field: :type, operator: :eq, value: "warning"},
          %{field: :type, operator: :eq, value: "error"}
        ]
      })
    end
    
    test "compiles VSM-specific pattern" do
      assert {:ok, :variety_explosion} = VsmGoldrush.compile_pattern(:variety_explosion, %{
        vsm_pattern: :variety_explosion
      })
    end
    
    test "returns error for invalid pattern" do
      assert {:error, _} = VsmGoldrush.compile_pattern(:invalid, %{
        invalid_key: "invalid_value"
      })
    end
  end
  
  describe "event processing" do
    setup do
      {:ok, _} = VsmGoldrush.compile_pattern(:test_pattern, %{
        field: :value,
        operator: :gt,
        value: 10
      })
      :ok
    end
    
    test "matches events that satisfy the pattern" do
      event = %{type: "test", value: 15}
      assert {:match, ^event} = VsmGoldrush.process_event(:test_pattern, event)
    end
    
    test "doesn't match events that don't satisfy the pattern" do
      event = %{type: "test", value: 5}
      assert :no_match = VsmGoldrush.process_event(:test_pattern, event)
    end
    
    test "handles events with nested data" do
      {:ok, _} = VsmGoldrush.compile_pattern(:nested_pattern, %{
        field: :"data.temperature",
        operator: :gt,
        value: 30
      })
      
      event = %{type: "sensor", data: %{temperature: 35, humidity: 60}}
      assert {:match, ^event} = VsmGoldrush.process_event(:nested_pattern, event)
    end
  end
  
  describe "pattern with actions" do
    test "executes action function on match" do
      # Use a process to capture action execution
      test_pid = self()
      
      action_fn = fn event ->
        send(test_pid, {:action_executed, event})
      end
      
      assert {:ok, :action_pattern} = VsmGoldrush.compile_pattern_with_action(
        :action_pattern,
        %{field: :trigger, operator: :eq, value: true},
        action_fn
      )
      
      # Process matching event
      event = %{id: 1, trigger: true}
      VsmGoldrush.process_event(:action_pattern, event)
      
      # Verify action was called
      assert_receive {:action_executed, ^event}, 1000
    end
  end
  
  describe "statistics" do
    setup do
      {:ok, _} = VsmGoldrush.compile_pattern(:stats_pattern, %{
        field: :value,
        operator: :gt,
        value: 50
      })
      :ok
    end
    
    test "tracks input and output counts" do
      # Process some events
      VsmGoldrush.process_event(:stats_pattern, %{value: 60})  # match
      VsmGoldrush.process_event(:stats_pattern, %{value: 40})  # no match
      VsmGoldrush.process_event(:stats_pattern, %{value: 70})  # match
      
      stats = VsmGoldrush.get_stats(:stats_pattern)
      assert stats.input_count == 3
      assert stats.output_count == 2
      assert stats.filter_count == 1
    end
    
    test "resets statistics" do
      # Process some events
      VsmGoldrush.process_event(:stats_pattern, %{value: 60})
      VsmGoldrush.process_event(:stats_pattern, %{value: 70})
      
      # Reset stats
      assert :ok = VsmGoldrush.reset_stats(:stats_pattern)
      
      # Check they're zeroed
      stats = VsmGoldrush.get_stats(:stats_pattern)
      assert stats.input_count == 0
      assert stats.output_count == 0
    end
  end
  
  describe "pattern management" do
    test "lists compiled patterns" do
      # Start with empty list
      assert [] = VsmGoldrush.list_patterns()
      
      # Compile some patterns
      {:ok, _} = VsmGoldrush.compile_pattern(:pattern1, %{field: :a, operator: :eq, value: 1})
      {:ok, _} = VsmGoldrush.compile_pattern(:pattern2, %{field: :b, operator: :eq, value: 2})
      
      patterns = VsmGoldrush.list_patterns()
      assert :pattern1 in patterns
      assert :pattern2 in patterns
      assert length(patterns) == 2
    end
    
    test "deletes patterns" do
      {:ok, _} = VsmGoldrush.compile_pattern(:to_delete, %{field: :x, operator: :eq, value: 1})
      assert :to_delete in VsmGoldrush.list_patterns()
      
      assert :ok = VsmGoldrush.delete_pattern(:to_delete)
      refute :to_delete in VsmGoldrush.list_patterns()
    end
    
    test "returns error for non-existent pattern" do
      assert {:error, :not_found} = VsmGoldrush.get_stats(:non_existent)
      assert {:error, :not_found} = VsmGoldrush.delete_pattern(:non_existent)
    end
  end
  
  describe "VSM cybernetic patterns" do
    test "compiles all cybernetic patterns" do
      results = VsmGoldrush.compile_vsm_patterns()
      
      # Should compile all patterns successfully
      successful = Enum.count(results, fn
        {:ok, _} -> true
        _ -> false
      end)
      
      assert successful == length(results)
      assert successful > 0
    end
    
    test "variety explosion pattern detects high variety states" do
      {:ok, _} = VsmGoldrush.Patterns.Cybernetic.compile_pattern(:variety_explosion)
      
      # This should match
      high_variety_event = %{
        type: "variety_state",
        variety_ratio: 0.85,
        channel_load: 0.95
      }
      
      assert {:match, _} = VsmGoldrush.process_event(:variety_explosion, high_variety_event)
      
      # This should not match
      normal_variety_event = %{
        type: "variety_state",
        variety_ratio: 0.5,
        channel_load: 0.6
      }
      
      assert :no_match = VsmGoldrush.process_event(:variety_explosion, normal_variety_event)
    end
    
    test "algedonic signal pattern detects pain signals" do
      {:ok, _} = VsmGoldrush.Patterns.Cybernetic.compile_pattern(:algedonic_signal)
      
      # High pain should trigger
      pain_event = %{
        type: "algedonic",
        pain_level: 0.8,
        pleasure_level: 0.2,
        source: "S1"
      }
      
      assert {:match, _} = VsmGoldrush.process_event(:algedonic_signal, pain_event)
      
      # Normal state should not trigger
      normal_event = %{
        type: "algedonic",
        pain_level: 0.3,
        pleasure_level: 0.7,
        source: "S1"
      }
      
      assert :no_match = VsmGoldrush.process_event(:algedonic_signal, normal_event)
    end
  end
end