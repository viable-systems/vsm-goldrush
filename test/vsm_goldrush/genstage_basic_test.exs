defmodule VsmGoldrush.GenStageBasicTest do
  use ExUnit.Case, async: false
  
  alias VsmGoldrush.{Producer, Consumer}
  
  setup do
    # Clean up any existing patterns
    VsmGoldrush.list_patterns()
    |> Enum.each(&VsmGoldrush.delete_pattern/1)
    
    # Create test pattern
    {:ok, :test_pattern} = VsmGoldrush.compile_pattern(:test_pattern, %{
      field: :type, operator: :eq, value: :test_event
    })
    
    on_exit(fn ->
      VsmGoldrush.delete_pattern(:test_pattern)
      
      # Stop any running producer/consumer
      if pid = Process.whereis(Producer), do: GenStage.stop(pid)
      if pid = Process.whereis(Consumer), do: GenStage.stop(pid)
    end)
    
    %{pattern: :test_pattern}
  end
  
  test "producer can be started and stopped", %{pattern: pattern} do
    {:ok, producer} = Producer.start_link(patterns: [pattern])
    assert Process.alive?(producer)
    
    GenStage.stop(producer)
    refute Process.alive?(producer)
  end
  
  test "consumer can be started and stopped", %{pattern: pattern} do
    {:ok, producer} = Producer.start_link(patterns: [pattern])
    {:ok, consumer} = Consumer.start_link(patterns: [pattern])
    
    assert Process.alive?(consumer)
    
    GenStage.stop(consumer)
    GenStage.stop(producer)
    
    refute Process.alive?(consumer)
  end
  
  test "producer generates events with correct structure", %{pattern: pattern} do
    # Create a simple event generator for testing
    test_event = %{type: :test_event, value: 42}
    event_generator = fn -> test_event end
    
    {:ok, producer} = Producer.start_link(
      patterns: [pattern], 
      event_generator: event_generator,
      demand_limit: 1
    )
    
    # Start a simple test consumer
    {:ok, test_consumer} = start_test_consumer(producer)
    
    # Wait for event generation
    Process.sleep(100)
    
    # Check we got events
    events = get_test_events(test_consumer)
    assert length(events) > 0
    
    # Verify event structure
    first_event = hd(events)
    assert Map.has_key?(first_event, :event)
    assert Map.has_key?(first_event, :timestamp)
    assert first_event.event == test_event
    
    GenStage.stop(test_consumer)
    GenStage.stop(producer)
  end
  
  test "consumer processes events and tracks statistics", %{pattern: pattern} do
    test_event = %{type: :test_event, id: 123}
    event_generator = fn -> test_event end
    
    {:ok, producer} = Producer.start_link(
      patterns: [pattern],
      event_generator: event_generator,
      demand_limit: 3
    )
    
    {:ok, consumer} = Consumer.start_link(patterns: [pattern])
    
    # Wait for processing
    Process.sleep(150)
    
    # Get statistics
    stats = Consumer.get_stats()
    
    # Should have processed some events
    assert stats.total_events > 0
    assert Map.has_key?(stats, :patterns)
    assert Map.has_key?(stats.patterns, pattern)
    
    GenStage.stop(consumer)
    GenStage.stop(producer)
  end
  
  # Helper functions for testing
  
  defp start_test_consumer(producer) do
    GenStage.start_link(SimpleTestConsumer, producer)
  end
  
  defp get_test_events(consumer) do
    GenStage.call(consumer, :get_events)
  end
end

defmodule SimpleTestConsumer do
  use GenStage
  
  def init(producer) do
    {:consumer, [], subscribe_to: [producer]}
  end
  
  def handle_events(events, _from, state) do
    # Store events in process state
    new_state = state ++ events
    {:noreply, [], new_state}
  end
  
  def handle_call(:get_events, _from, state) do
    {:reply, state, [], state}
  end
end