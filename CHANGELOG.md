# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2024-01-20

### Added
- Initial release with full goldrush integration
- VSM event format conversion (Elixir maps <-> goldrush events)
- Query builder for VSM pattern specifications
- Pre-defined cybernetic failure patterns:
  - Variety engineering patterns (explosion, imbalance)
  - Communication channel patterns (saturation, S1-S3 breakdown, S2 loop failure)
  - Algedonic patterns (signal detection, channel blocked)
  - Recursion patterns (violation, meta-system dominance)
  - Homeostatic failure detection
- Pattern compilation with actions
- Built-in statistics tracking
- OTP application with optional pattern compilation on startup
- Comprehensive test suite
- Full documentation and examples

### Technical Details
- Actually uses goldrush's query compilation engine for native performance
- Patterns compile to BEAM bytecode for maximum speed
- Event conversion handles nested maps via dot notation
- Statistics use ETS counters for minimal overhead