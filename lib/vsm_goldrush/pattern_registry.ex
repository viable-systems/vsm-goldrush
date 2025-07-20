defmodule VsmGoldrush.PatternRegistry do
  @moduledoc """
  Registry for tracking compiled goldrush patterns.
  
  Since goldrush doesn't provide a way to list all compiled patterns,
  we maintain our own registry.
  """
  
  use GenServer
  
  @table_name :vsm_goldrush_patterns
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def register(pattern_id) when is_atom(pattern_id) do
    GenServer.call(__MODULE__, {:register, pattern_id})
  end
  
  def unregister(pattern_id) when is_atom(pattern_id) do
    GenServer.call(__MODULE__, {:unregister, pattern_id})
  end
  
  def list_patterns do
    GenServer.call(__MODULE__, :list)
  end
  
  def clear_all do
    GenServer.call(__MODULE__, :clear)
  end
  
  # Server callbacks
  
  @impl true
  def init(_opts) do
    table = :ets.new(@table_name, [:set, :protected])
    {:ok, %{table: table}}
  end
  
  @impl true
  def handle_call({:register, pattern_id}, _from, %{table: table} = state) do
    :ets.insert(table, {pattern_id, :os.timestamp()})
    {:reply, :ok, state}
  end
  
  @impl true
  def handle_call({:unregister, pattern_id}, _from, %{table: table} = state) do
    :ets.delete(table, pattern_id)
    {:reply, :ok, state}
  end
  
  @impl true
  def handle_call(:list, _from, %{table: table} = state) do
    patterns = :ets.tab2list(table)
    |> Enum.map(fn {pattern_id, _timestamp} -> pattern_id end)
    |> Enum.sort()
    
    {:reply, patterns, state}
  end
  
  @impl true
  def handle_call(:clear, _from, %{table: table} = state) do
    :ets.delete_all_objects(table)
    {:reply, :ok, state}
  end
end