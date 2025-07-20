# Contributing to VSM-Goldrush

We welcome contributions to vsm-goldrush! This document provides guidelines for contributing to the project.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR-USERNAME/vsm-goldrush.git`
3. Add the upstream remote: `git remote add upstream https://github.com/viable-systems/vsm-goldrush.git`
4. Create a feature branch: `git checkout -b my-feature`

## Development Setup

```bash
# Install dependencies
mix deps.get

# Run tests
mix test

# Run quality checks
mix format
mix credo --strict
mix dialyzer
```

## Making Changes

1. **Write tests first**: We practice TDD. Write tests for your changes before implementing them.
2. **Follow the style guide**: Run `mix format` before committing.
3. **Keep commits focused**: Each commit should represent one logical change.
4. **Write good commit messages**: Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification.

## Submitting a Pull Request

1. Update your branch with the latest upstream changes:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. Run all tests and quality checks:
   ```bash
   mix test
   mix format
   mix credo --strict
   ```

3. Push to your fork: `git push origin my-feature`

4. Create a pull request from your fork to the upstream repository

5. In the PR description:
   - Describe what the change does and why
   - Reference any related issues
   - Include examples if applicable

## Code Review Process

- All submissions require review before merging
- We may suggest changes or improvements
- Once approved, we'll merge your contribution

## Reporting Issues

- Use GitHub Issues to report bugs or suggest features
- Check existing issues first to avoid duplicates
- Include as much detail as possible:
  - Elixir and OTP versions
  - Steps to reproduce
  - Expected vs actual behavior
  - Error messages or stack traces

## Code of Conduct

Be respectful and constructive in all interactions. We're here to build great software together.

## Questions?

Feel free to open an issue for any questions about contributing.