defmodule VsmGoldrush.TemporalBasicTest do
  use ExUnit.Case, async: false
  
  alias VsmGoldrush.Temporal
  
  setup do
    # Clean up any existing patterns
    VsmGoldrush.list_patterns()
    |> Enum.each(&VsmGoldrush.delete_pattern/1)
    
    :ok
  end
  
  test "temporal module can compile sequence patterns" do
    sequence = [
      %{field: :type, operator: :eq, value: :step_one},
      %{field: :type, operator: :eq, value: :step_two}
    ]
    
    {:ok, :test_sequence} = Temporal.compile_sequence_pattern(
      :test_sequence,
      sequence,
      5000
    )
    
    # Verify pattern was compiled
    assert :test_sequence in VsmGoldrush.list_patterns()
    
    # Clean up
    VsmGoldrush.delete_pattern(:test_sequence)
  end
  
  test "temporal module can compile frequency patterns" do
    {:ok, :test_frequency} = Temporal.compile_frequency_pattern(
      :test_frequency,
      %{field: :type, operator: :eq, value: :frequent_event},
      3,
      1000
    )
    
    # Verify pattern was compiled
    assert :test_frequency in VsmGoldrush.list_patterns()
    
    # Clean up
    VsmGoldrush.delete_pattern(:test_frequency)
  end
  
  test "temporal module can compile correlation patterns" do
    correlation_spec = %{
      trigger: %{field: :type, operator: :eq, value: :trigger_event},
      response: %{field: :type, operator: :eq, value: :response_event}
    }
    
    {:ok, :test_correlation} = Temporal.compile_correlation_pattern(
      :test_correlation,
      correlation_spec,
      2000
    )
    
    # Verify pattern was compiled
    assert :test_correlation in VsmGoldrush.list_patterns()
    
    # Clean up
    VsmGoldrush.delete_pattern(:test_correlation)
  end
  
  test "temporal state management handles non-existent patterns" do
    {:error, :pattern_not_found} = Temporal.get_temporal_stats(:non_existent)
    :ok = Temporal.clear_temporal_state(:non_existent)
  end
end