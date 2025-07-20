defmodule VsmGoldrush.EventConverter do
  @moduledoc """
  Converts between VSM event format (Elixir maps) and goldrush event format (Erlang property lists).
  
  ## Event Formats
  
  VSM Event (Elixir map):
      %{
        type: "channel_failure",
        severity: :high,
        timestamp: ~U[2024-01-20 10:30:00Z],
        data: %{channel: "S1-S3", metrics: [1, 2, 3]}
      }
      
  Goldrush Event (Erlang tuple):
      {:list, [
        {:type, "channel_failure"},
        {:severity, :high},
        {:timestamp, ~U[2024-01-20 10:30:00Z]},
        {:data, %{channel: "S1-S3", metrics: [1, 2, 3]}}
      ]}
  """
  
  @type vsm_event :: map()
  @type goldrush_event :: {:list, [{atom(), term()}]}
  
  @doc """
  Convert a VSM event (Elixir map) to goldrush event format.
  
  ## Examples
  
      iex> VsmGoldrush.EventConverter.to_goldrush(%{type: "test", value: 42})
      {:list, [{:type, "test"}, {:value, 42}]}
  """
  @spec to_goldrush(vsm_event()) :: goldrush_event()
  def to_goldrush(event) when is_map(event) do
    proplist = event
    |> Map.to_list()
    |> Enum.map(&convert_key_value/1)
    |> List.flatten()
    
    :gre.make(proplist, [:list])
  end
  
  @doc """
  Convert a goldrush event back to VSM format.
  
  ## Examples
  
      iex> VsmGoldrush.EventConverter.from_goldrush({:list, [{:type, "test"}, {:value, 42}]})
      %{type: "test", value: 42}
  """
  @spec from_goldrush(goldrush_event()) :: vsm_event()
  def from_goldrush({:list, proplist}) when is_list(proplist) do
    proplist
    |> Enum.map(fn {k, v} -> {k, v} end)
    |> Map.new()
  end
  
  # Handle nested maps by flattening with dot notation
  defp convert_key_value({key, value}) when is_map(value) do
    value
    |> Map.to_list()
    |> Enum.map(fn {sub_key, sub_value} ->
      {:"#{key}.#{sub_key}", sub_value}
    end)
  end
  
  # Convert string keys to atoms for goldrush
  defp convert_key_value({key, value}) when is_binary(key) do
    {String.to_atom(key), value}
  end
  
  # Pass through atom keys
  defp convert_key_value({key, value}) when is_atom(key) do
    {key, value}
  end
  
  @doc """
  Validate that an event can be converted to goldrush format.
  
  Returns {:ok, event} if valid, {:error, reason} otherwise.
  """
  @spec validate_event(vsm_event()) :: {:ok, vsm_event()} | {:error, String.t()}
  def validate_event(event) when is_map(event) do
    case check_keys(Map.keys(event)) do
      :ok -> {:ok, event}
      error -> error
    end
  end
  
  def validate_event(_), do: {:error, "Event must be a map"}
  
  # Check that all keys can be converted to atoms safely
  defp check_keys([]), do: :ok
  
  defp check_keys([key | rest]) when is_atom(key) do
    check_keys(rest)
  end
  
  defp check_keys([key | rest]) when is_binary(key) do
    if String.length(key) > 255 do
      {:error, "Key '#{key}' is too long (max 255 characters)"}
    else
      check_keys(rest)
    end
  end
  
  defp check_keys([key | _]) do
    {:error, "Invalid key type: #{inspect(key)}"}
  end
end