defmodule VsmGoldrush.Patterns.Cybernetic do
  @moduledoc """
  Pre-defined VSM cybernetic failure patterns compiled into goldrush queries.
  
  These patterns detect common failure modes in Viable System Model implementations:
  - Variety engineering failures
  - Communication channel breakdowns
  - Recursion level violations
  - Algedonic signal detection
  - Autonomy-cohesion imbalances
  """
  
  require Logger
  
  @patterns [
    # Variety Engineering Patterns
    {:variety_explosion, %{
      description: "Environmental variety exceeds system's regulatory capacity",
      query: %{
        all: [
          %{field: :type, operator: :eq, value: "variety_state"},
          %{field: :variety_ratio, operator: :gt, value: 0.8},
          %{field: :channel_load, operator: :gt, value: 0.9}
        ]
      }
    }},
    
    {:variety_imbalance, %{
      description: "Mismatch between controller and environment variety",
      query: %{
        all: [
          %{field: :type, operator: :eq, value: "variety_state"},
          %{any: [
            %{field: :controller_variety, operator: :lt, value: 0.3},
            %{field: :environment_variety, operator: :gt, value: 0.7}
          ]}
        ]
      }
    }},
    
    # Communication Channel Patterns
    {:channel_saturation, %{
      description: "Communication channel at or beyond capacity",
      query: %{
        all: [
          %{field: :type, operator: :eq, value: "channel_state"},
          %{any: [
            %{field: :queue_depth, operator: :gte, value: 1000},
            %{field: :latency, operator: :gte, value: 5000},
            %{field: :drop_rate, operator: :gte, value: 0.05}
          ]}
        ]
      }
    }},
    
    {:s1_s3_breakdown, %{
      description: "Operations to management channel failure",
      query: %{
        all: [
          %{field: :channel, operator: :eq, value: "S1-S3"},
          %{any: [
            %{field: :state, operator: :eq, value: "disconnected"},
            %{field: :error_rate, operator: :gt, value: 0.1},
            %{field: :throughput, operator: :lt, value: 0.5}
          ]}
        ]
      }
    }},
    
    {:s2_coordination_loop_failure, %{
      description: "Coordination mechanism breakdown",
      query: %{
        all: [
          %{field: :subsystem, operator: :eq, value: "S2"},
          %{any: [
            %{field: :sync_failures, operator: :gt, value: 10},
            %{field: :conflict_rate, operator: :gt, value: 0.2},
            %{field: :coordination_latency, operator: :gt, value: 1000}
          ]}
        ]
      }
    }},
    
    # Algedonic Patterns
    {:algedonic_signal, %{
      description: "Pain/pleasure signal requiring immediate attention",
      query: %{
        all: [
          %{field: :type, operator: :eq, value: "algedonic"},
          %{any: [
            %{field: :pain_level, operator: :gte, value: 0.7},
            %{field: :pleasure_level, operator: :lte, value: 0.3}
          ]}
        ]
      }
    }},
    
    {:algedonic_channel_blocked, %{
      description: "Critical algedonic bypass is non-functional",
      query: %{
        all: [
          %{field: :channel, operator: :eq, value: "algedonic"},
          %{field: :state, operator: :eq, value: "blocked"},
          %{field: :priority, operator: :eq, value: :critical}
        ]
      }
    }},
    
    # Recursion Patterns
    {:recursion_violation, %{
      description: "Violation of recursive system boundaries",
      query: %{
        all: [
          %{field: :type, operator: :eq, value: "recursion_error"},
          %{any: [
            %{field: :error, operator: :eq, value: "level_crossing"},
            %{field: :error, operator: :eq, value: "autonomy_breach"},
            %{field: :error, operator: :eq, value: "meta_interference"}
          ]}
        ]
      }
    }},
    
    {:meta_system_dominance, %{
      description: "Higher recursion level interfering with lower level autonomy",
      query: %{
        all: [
          %{field: :type, operator: :eq, value: "autonomy_violation"},
          %{field: :source_level, operator: :gt, value: :target_level},
          %{field: :interference_score, operator: :gt, value: 0.6}
        ]
      }
    }},
    
    # Homeostatic Patterns
    {:homeostatic_failure, %{
      description: "System unable to maintain essential variables",
      query: %{
        all: [
          %{field: :type, operator: :eq, value: "homeostatic_error"},
          %{any: [
            %{field: :drift_rate, operator: :gt, value: 0.1},
            %{field: :correction_failures, operator: :gt, value: 5},
            %{field: :variable_variance, operator: :gt, value: 0.3}
          ]}
        ]
      }
    }}
  ]
  
  @doc """
  Compile all cybernetic patterns into goldrush queries.
  """
  def compile_all do
    results = Enum.map(@patterns, fn {id, %{description: desc, query: query}} ->
      Logger.info("Compiling cybernetic pattern: #{id} - #{desc}")
      
      case VsmGoldrush.compile_pattern(id, query) do
        {:ok, _} -> {:ok, id}
        error -> error
      end
    end)
    
    successful = Enum.count(results, fn
      {:ok, _} -> true
      _ -> false
    end)
    
    Logger.info("Compiled #{successful}/#{length(@patterns)} cybernetic patterns")
    results
  end
  
  @doc """
  Get pattern metadata.
  """
  def get_pattern_info(pattern_id) do
    case List.keyfind(@patterns, pattern_id, 0) do
      {^pattern_id, info} -> {:ok, info}
      nil -> {:error, :not_found}
    end
  end
  
  @doc """
  List all available patterns.
  """
  def list_patterns do
    Enum.map(@patterns, fn {id, %{description: desc}} ->
      %{id: id, description: desc}
    end)
  end
  
  @doc """
  Compile a specific pattern.
  """
  def compile_pattern(pattern_id) do
    case get_pattern_info(pattern_id) do
      {:ok, %{query: query}} ->
        VsmGoldrush.compile_pattern(pattern_id, query)
      error ->
        error
    end
  end
end