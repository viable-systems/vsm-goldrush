defmodule VsmGoldrush.Application do
  @moduledoc """
  OTP Application for VsmGoldrush.
  
  Starts the goldrush application and optionally compiles VSM patterns on startup.
  """
  
  use Application
  require Logger
  
  @impl true
  def start(_type, _args) do
    children = [
      # Pattern registry to track compiled patterns
      VsmGoldrush.PatternRegistry
    ]
    
    opts = [strategy: :one_for_one, name: VsmGoldrush.Supervisor]
    
    # Initialize goldrush
    case VsmGoldrush.init() do
      :ok ->
        Logger.info("VsmGoldrush application started")
        
        # Optionally compile VSM patterns on startup
        if Application.get_env(:vsm_goldrush, :compile_patterns_on_start, false) do
          spawn(fn ->
            Process.sleep(1000)  # Give the system time to stabilize
            Logger.info("Compiling VSM cybernetic patterns...")
            VsmGoldrush.compile_vsm_patterns()
          end)
        end
        
      error ->
        Logger.error("Failed to initialize VsmGoldrush: #{inspect(error)}")
    end
    
    Supervisor.start_link(children, opts)
  end
  
  @impl true
  def stop(_state) do
    # Clean up compiled patterns if needed
    if Application.get_env(:vsm_goldrush, :cleanup_on_stop, true) do
      patterns = VsmGoldrush.list_patterns()
      Logger.info("Cleaning up #{length(patterns)} compiled patterns")
      
      Enum.each(patterns, fn pattern_id ->
        VsmGoldrush.delete_pattern(pattern_id)
      end)
    end
    
    :ok
  end
end