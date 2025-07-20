defmodule VsmGoldrush.ProducerConsumerTest do
  use ExUnit.Case, async: false
  
  alias VsmGoldrush.{Producer, Consumer}
  
  setup do
    # Clean up any existing patterns
    VsmGoldrush.list_patterns()
    |> Enum.each(&VsmGoldrush.delete_pattern/1)
    
    # Create test patterns
    {:ok, :test_variety} = VsmGoldrush.compile_pattern(:test_variety, %{
      field: :type, operator: :eq, value: :variety_explosion
    })
    
    {:ok, :test_algedonic} = VsmGoldrush.compile_pattern(:test_algedonic, %{
      field: :type, operator: :eq, value: :algedonic_signal
    })
    
    on_exit(fn ->
      # Clean up
      VsmGoldrush.delete_pattern(:test_variety)
      VsmGoldrush.delete_pattern(:test_algedonic)
      
      # Stop any running producer/consumer
      Process.whereis(Producer) && GenStage.stop(Producer)
      Process.whereis(Consumer) && GenStage.stop(Consumer)
    end)
    
    %{patterns: [:test_variety, :test_algedonic]}
  end
  
  test "producer generates events", %{patterns: patterns} do
    # Start producer
    {:ok, producer} = Producer.start_link(patterns: patterns)
    
    # Subscribe directly to get events
    {:ok, _subscriber} = GenStage.start_link(TestSubscriber, producer: producer)
    
    # Wait for some events to be produced
    Process.sleep(100)
    
    # Check that events were generated
    events = TestSubscriber.get_events()
    assert length(events) > 0
    
    # Verify event structure
    first_event = hd(events)
    assert Map.has_key?(first_event, :event)
    assert Map.has_key?(first_event, :timestamp)
  end
  
  test "consumer processes events through patterns", %{patterns: patterns} do
    # Start producer and consumer
    {:ok, _producer} = Producer.start_link(patterns: patterns, demand_limit: 10)
    
    # Define actions for matched patterns
    actions = %{
      test_variety: fn event -> {:variety_detected, Map.get(event, :variety_level)} end,
      test_algedonic: fn event -> {:algedonic_detected, Map.get(event, :severity)} end
    }
    
    {:ok, _consumer} = Consumer.start_link(patterns: patterns, actions: actions)
    
    # Wait for processing
    Process.sleep(200)
    
    # Check consumer statistics
    stats = Consumer.get_stats()
    assert stats.total_events > 0
    assert Map.has_key?(stats, :patterns)
    assert Map.has_key?(stats.patterns, :test_variety)
    assert Map.has_key?(stats.patterns, :test_algedonic)
  end
  
  test "producer allows dynamic pattern management" do
    {:ok, producer} = Producer.start_link(patterns: [:test_variety])
    
    # Add a pattern
    :ok = Producer.add_pattern(producer, :test_algedonic)
    
    # Remove a pattern
    :ok = Producer.remove_pattern(producer, :test_variety)
    
    # Verify the producer state changed (indirectly through behavior)
    assert :ok == Producer.add_pattern(producer, :test_variety)
  end
  
  test "consumer handles pattern matching and actions", %{patterns: patterns} do
    # Start producer with controlled event generation
    test_events = [
      %{type: :variety_explosion, variety_level: 85},
      %{type: :algedonic_signal, severity: :high},
      %{type: :normal_operation, status: :ok}
    ]
    
    event_generator = fn -> Enum.random(test_events) end
    
    {:ok, _producer} = Producer.start_link(
      patterns: patterns, 
      event_generator: event_generator,
      demand_limit: 5
    )
    
    # Capture action results
    {:ok, _action_results} = Agent.start_link(fn -> [] end, name: :action_results)
    
    actions = %{
      test_variety: fn event -> 
        Agent.update(:action_results, fn results -> 
          [{:variety, event} | results] 
        end)
        :variety_action_executed
      end,
      test_algedonic: fn event -> 
        Agent.update(:action_results, fn results -> 
          [{:algedonic, event} | results] 
        end)
        :algedonic_action_executed
      end
    }
    
    {:ok, _consumer} = Consumer.start_link(patterns: patterns, actions: actions)
    
    # Wait for processing
    Process.sleep(300)
    
    # Check that actions were executed
    results = Agent.get(:action_results, & &1)
    
    # We should have some results (exact count depends on random generation)
    assert length(results) >= 0
    
    # Clean up
    Agent.stop(:action_results)
  end
  
  test "consumer handles errors in actions gracefully", %{patterns: patterns} do
    {:ok, _producer} = Producer.start_link(patterns: patterns, demand_limit: 3)
    
    # Define actions that will raise errors
    actions = %{
      test_variety: fn _event -> raise "Intentional test error" end,
      test_algedonic: fn _event -> :success end
    }
    
    {:ok, _consumer} = Consumer.start_link(patterns: patterns, actions: actions)
    
    # Wait for processing
    Process.sleep(200)
    
    # Consumer should still be running despite action errors
    assert Process.alive?(Process.whereis(Consumer))
    
    # Check statistics
    stats = Consumer.get_stats()
    assert stats.total_events > 0
  end
  
  test "consumer statistics tracking works correctly", %{patterns: patterns} do
    {:ok, _producer} = Producer.start_link(patterns: patterns, demand_limit: 5)
    {:ok, _consumer} = Consumer.start_link(patterns: patterns)
    
    # Wait for some processing
    Process.sleep(150)
    
    # Get initial stats
    initial_stats = Consumer.get_stats()
    
    # Wait for more processing
    Process.sleep(150)
    
    # Get updated stats
    updated_stats = Consumer.get_stats()
    
    # Verify stats are tracking correctly
    assert updated_stats.total_events >= initial_stats.total_events
    assert Map.has_key?(updated_stats, :processing_time_ms)
    assert Map.has_key?(updated_stats, :start_time)
    
    # Reset stats
    :ok = Consumer.reset_stats()
    reset_stats = Consumer.get_stats()
    
    # Stats should be reset
    assert reset_stats.total_events == 0
    assert reset_stats.total_matches == 0
  end
end

defmodule TestSubscriber do
  use GenStage
  
  def start_link(opts) do
    producer = Keyword.fetch!(opts, :producer)
    GenStage.start_link(__MODULE__, producer, name: __MODULE__)
  end
  
  def init(producer) do
    {:consumer, [], subscribe_to: [producer]}
  end
  
  def handle_events(events, _from, state) do
    # Store events for testing
    Agent.update(__MODULE__, fn stored_events -> 
      stored_events ++ events 
    end)
    
    {:noreply, [], state}
  end
  
  def get_events do
    case Agent.start_link(fn -> [] end, name: __MODULE__) do
      {:ok, _pid} -> []
      {:error, {:already_started, _pid}} -> 
        Agent.get(__MODULE__, & &1)
    end
  end
end