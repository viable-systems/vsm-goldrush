defmodule VsmGoldrush.TemporalTest do
  use ExUnit.Case, async: false
  
  alias VsmGoldrush.Temporal
  
  setup do
    # Clean up any existing patterns and temporal state
    VsmGoldrush.list_patterns()
    |> Enum.each(&VsmGoldrush.delete_pattern/1)
    
    # Clean up temporal state table
    case :ets.whereis(:vsm_temporal_state) do
      :undefined -> :ok
      table -> :ets.delete_all_objects(table)
    end
    
    :ok
  end
  
  describe "sequence pattern detection" do
    test "compiles and detects simple event sequences" do
      # Define a sequence: variety explosion followed by algedonic signal
      sequence = [
        %{type: :variety_explosion, system: :s1},
        %{type: :algedonic_signal, severity: :high}
      ]
      
      # Compile the temporal pattern
      {:ok, :cascade_failure} = Temporal.compile_sequence_pattern(
        :cascade_failure, 
        sequence, 
        5000  # 5 second window
      )
      
      # Test that pattern was compiled
      assert :cascade_failure in VsmGoldrush.list_patterns()
      
      # Test sequence detection
      event1 = %{type: :variety_explosion, system: :s1, timestamp: 1000}
      event2 = %{type: :algedonic_signal, severity: :high, timestamp: 2000}
      event3 = %{type: :normal_operation, status: :ok, timestamp: 3000}
      
      # First event should start sequence
      {:ok, false} = VsmGoldrush.test_event(:cascade_failure, event1)
      
      # Second event should complete sequence
      {:ok, true} = VsmGoldrush.test_event(:cascade_failure, event2)
      
      # Third event should not match
      {:ok, false} = VsmGoldrush.test_event(:cascade_failure, event3)
      
      # Check temporal statistics
      {:ok, stats} = Temporal.get_temporal_stats(:cascade_failure)
      assert stats.type == :sequence
      assert stats.total_matches >= 1
      
      # Clean up
      VsmGoldrush.delete_pattern(:cascade_failure)
    end
    
    test "sequence detection respects time windows" do
      sequence = [
        %{type: :event_a, value: 1},
        %{type: :event_b, value: 2}
      ]
      
      {:ok, :time_sensitive} = Temporal.compile_sequence_pattern(
        :time_sensitive, 
        sequence, 
        1000  # 1 second window
      )
      
      # Simulate events with timing
      event1 = %{type: :event_a, value: 1}
      event2 = %{type: :event_b, value: 2}
      
      # Start sequence
      {:ok, false} = VsmGoldrush.test_event(:time_sensitive, event1)
      
      # Wait longer than time window
      Process.sleep(1100)
      
      # Second event should not complete sequence (window expired)
      {:ok, false} = VsmGoldrush.test_event(:time_sensitive, event2)
      
      # Clean up
      VsmGoldrush.delete_pattern(:time_sensitive)
    end
    
    test "sequence detection handles out-of-order events" do
      sequence = [
        %{type: :first, order: 1},
        %{type: :second, order: 2},
        %{type: :third, order: 3}
      ]
      
      {:ok, :ordered_sequence} = Temporal.compile_sequence_pattern(
        :ordered_sequence, 
        sequence, 
        10000
      )
      
      # Send events out of order
      event2 = %{type: :second, order: 2}
      event1 = %{type: :first, order: 1}
      event3 = %{type: :third, order: 3}
      
      # Wrong order should not trigger sequence
      {:ok, false} = VsmGoldrush.test_event(:ordered_sequence, event2)
      
      # Correct order should work
      {:ok, false} = VsmGoldrush.test_event(:ordered_sequence, event1)
      {:ok, false} = VsmGoldrush.test_event(:ordered_sequence, event2)
      {:ok, true} = VsmGoldrush.test_event(:ordered_sequence, event3)
      
      # Clean up
      VsmGoldrush.delete_pattern(:ordered_sequence)
    end
  end
  
  describe "frequency pattern detection" do
    test "compiles and detects event frequency thresholds" do
      # Detect more than 3 variety explosions in 2 seconds
      {:ok, :variety_storm} = Temporal.compile_frequency_pattern(
        :variety_storm,
        %{type: :variety_explosion},
        3,     # threshold
        2000   # 2 second window
      )
      
      # Test frequency detection
      event = %{type: :variety_explosion, system: :s1}
      
      # First two events should not trigger
      {:ok, false} = VsmGoldrush.test_event(:variety_storm, event)
      {:ok, false} = VsmGoldrush.test_event(:variety_storm, event)
      
      # Third event should trigger threshold
      {:ok, true} = VsmGoldrush.test_event(:variety_storm, event)
      
      # Check temporal statistics
      {:ok, stats} = Temporal.get_temporal_stats(:variety_storm)
      assert stats.type == :frequency
      assert stats.current_count >= 3
      assert stats.threshold == 3
      
      # Clean up
      VsmGoldrush.delete_pattern(:variety_storm)
    end
    
    test "frequency detection handles time window expiration" do
      {:ok, :short_burst} = Temporal.compile_frequency_pattern(
        :short_burst,
        %{type: :test_event},
        2,     # threshold
        500    # 0.5 second window
      )
      
      event = %{type: :test_event, id: 1}
      
      # Send first event
      {:ok, false} = VsmGoldrush.test_event(:short_burst, event)
      
      # Wait for window to expire
      Process.sleep(600)
      
      # Send second event (should not trigger due to expired window)
      {:ok, false} = VsmGoldrush.test_event(:short_burst, event)
      
      # Clean up
      VsmGoldrush.delete_pattern(:short_burst)
    end
    
    test "frequency detection ignores non-matching events" do
      {:ok, :selective_frequency} = Temporal.compile_frequency_pattern(
        :selective_frequency,
        %{type: :specific_event, category: :important},
        2,
        5000
      )
      
      matching_event = %{type: :specific_event, category: :important}
      non_matching_event = %{type: :specific_event, category: :normal}
      
      # Non-matching event should be ignored
      {:ok, false} = VsmGoldrush.test_event(:selective_frequency, non_matching_event)
      
      # First matching event
      {:ok, false} = VsmGoldrush.test_event(:selective_frequency, matching_event)
      
      # Another non-matching event
      {:ok, false} = VsmGoldrush.test_event(:selective_frequency, non_matching_event)
      
      # Second matching event should trigger
      {:ok, true} = VsmGoldrush.test_event(:selective_frequency, matching_event)
      
      # Clean up
      VsmGoldrush.delete_pattern(:selective_frequency)
    end
  end
  
  describe "correlation pattern detection" do
    test "compiles and detects trigger-response correlations" do
      # Detect S1 overload followed by S3 intervention within 2 seconds
      correlation_spec = %{
        trigger: %{system: :s1, type: :overload},
        response: %{system: :s3, type: :intervention}
      }
      
      {:ok, :control_response} = Temporal.compile_correlation_pattern(
        :control_response,
        correlation_spec,
        2000
      )
      
      trigger_event = %{system: :s1, type: :overload, severity: :high}
      response_event = %{system: :s3, type: :intervention, action: :resource_reallocation}
      unrelated_event = %{system: :s2, type: :coordination, status: :normal}
      
      # Trigger event should be recorded but not match
      {:ok, false} = VsmGoldrush.test_event(:control_response, trigger_event)
      
      # Unrelated event should not affect correlation
      {:ok, false} = VsmGoldrush.test_event(:control_response, unrelated_event)
      
      # Response event should trigger correlation
      {:ok, true} = VsmGoldrush.test_event(:control_response, response_event)
      
      # Check temporal statistics
      {:ok, stats} = Temporal.get_temporal_stats(:control_response)
      assert stats.type == :correlation
      assert stats.total_matches >= 1
      
      # Clean up
      VsmGoldrush.delete_pattern(:control_response)
    end
    
    test "correlation detection respects time windows" do
      correlation_spec = %{
        trigger: %{event: :trigger},
        response: %{event: :response}
      }
      
      {:ok, :timed_correlation} = Temporal.compile_correlation_pattern(
        :timed_correlation,
        correlation_spec,
        1000  # 1 second window
      )
      
      trigger_event = %{event: :trigger, id: 1}
      response_event = %{event: :response, id: 2}
      
      # Send trigger
      {:ok, false} = VsmGoldrush.test_event(:timed_correlation, trigger_event)
      
      # Wait longer than correlation window
      Process.sleep(1100)
      
      # Response should not correlate (window expired)
      {:ok, false} = VsmGoldrush.test_event(:timed_correlation, response_event)
      
      # Clean up
      VsmGoldrush.delete_pattern(:timed_correlation)
    end
    
    test "correlation detection handles multiple triggers" do
      correlation_spec = %{
        trigger: %{type: :alert},
        response: %{type: :acknowledgment}
      }
      
      {:ok, :multi_trigger} = Temporal.compile_correlation_pattern(
        :multi_trigger,
        correlation_spec,
        5000
      )
      
      trigger1 = %{type: :alert, source: :system_a}
      trigger2 = %{type: :alert, source: :system_b}
      response = %{type: :acknowledgment, operator: :admin}
      
      # Send multiple triggers
      {:ok, false} = VsmGoldrush.test_event(:multi_trigger, trigger1)
      {:ok, false} = VsmGoldrush.test_event(:multi_trigger, trigger2)
      
      # Single response should correlate with any pending trigger
      {:ok, true} = VsmGoldrush.test_event(:multi_trigger, response)
      
      # Clean up
      VsmGoldrush.delete_pattern(:multi_trigger)
    end
  end
  
  describe "temporal state management" do
    test "temporal statistics provide useful information" do
      {:ok, :test_sequence} = Temporal.compile_sequence_pattern(
        :test_sequence,
        [%{step: 1}, %{step: 2}],
        5000
      )
      
      # Get initial stats
      {:ok, stats} = Temporal.get_temporal_stats(:test_sequence)
      assert stats.type == :sequence
      assert stats.current_step == 0
      assert stats.total_matches == 0
      
      # Send first event
      {:ok, false} = VsmGoldrush.test_event(:test_sequence, %{step: 1})
      
      # Check updated stats
      {:ok, updated_stats} = Temporal.get_temporal_stats(:test_sequence)
      assert updated_stats.current_step == 1
      assert updated_stats.sequence_active == true
      
      # Clean up
      VsmGoldrush.delete_pattern(:test_sequence)
    end
    
    test "temporal state can be cleared" do
      {:ok, :clearable_pattern} = Temporal.compile_frequency_pattern(
        :clearable_pattern,
        %{type: :test},
        5,
        10000
      )
      
      # Generate some state
      event = %{type: :test, value: 123}
      {:ok, false} = VsmGoldrush.test_event(:clearable_pattern, event)
      
      # Verify state exists
      {:ok, stats} = Temporal.get_temporal_stats(:clearable_pattern)
      assert stats.current_count > 0
      
      # Clear state
      :ok = Temporal.clear_temporal_state(:clearable_pattern)
      
      # Verify state is cleared
      {:error, :pattern_not_found} = Temporal.get_temporal_stats(:clearable_pattern)
      
      # Clean up
      VsmGoldrush.delete_pattern(:clearable_pattern)
    end
    
    test "handles non-existent patterns gracefully" do
      {:error, :pattern_not_found} = Temporal.get_temporal_stats(:non_existent)
      :ok = Temporal.clear_temporal_state(:non_existent)
    end
  end
end