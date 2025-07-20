# Publishing to Hex.pm

This guide explains how to publish vsm-goldrush to Hex.pm.

## Prerequisites

1. Create a Hex.pm account at https://hex.pm
2. Generate an API key: `mix hex.user auth`
3. Ensure you're a member of the `viable_systems` organization on Hex.pm

## Pre-publish Checklist

- [ ] All tests pass: `mix test`
- [ ] Documentation builds: `mix docs`
- [ ] No compiler warnings: `mix compile --warnings-as-errors`
- [ ] Code is formatted: `mix format --check-formatted`
- [ ] Dialyzer passes: `mix dialyzer`
- [ ] CHANGELOG.md is updated with release notes
- [ ] Version in mix.exs is updated
- [ ] README has correct version in installation instructions

## Publishing Process

1. **Dry run** to verify everything looks correct:
   ```bash
   mix hex.build
   mix hex.publish --dry-run
   ```

2. **Publish to Hex.pm**:
   ```bash
   mix hex.publish
   ```

3. **Tag the release**:
   ```bash
   git tag -a v0.1.0 -m "Release v0.1.0"
   git push origin v0.1.0
   ```

4. **Create GitHub Release**:
   - Go to https://github.com/viable-systems/vsm-goldrush/releases
   - Click "Create a new release"
   - Select the tag you just pushed
   - Copy release notes from CHANGELOG.md
   - Publish release

## Post-publish

1. Verify the package on Hex.pm: https://hex.pm/packages/vsm_goldrush
2. Test installation in a new project:
   ```elixir
   {:vsm_goldrush, "~> 0.1.0", organization: "viable_systems"}
   ```
3. Announce the release (if applicable)

## Troubleshooting

- **Organization not found**: Ensure the organization exists on Hex.pm
- **Authentication failed**: Run `mix hex.user auth` to refresh your API key
- **Version conflict**: Ensure the version hasn't been published already

## Future Releases

1. Update version in `mix.exs`
2. Update CHANGELOG.md
3. Follow the publishing process above