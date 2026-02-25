# Contributing

Thanks for contributing to PluginSystem.jl.

## Development Environment

Use Julia 1.12+ and install dependencies:

```bash
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

## Run Tests

```bash
julia --project=. test/runtests.jl
```

## Build Documentation

```bash
julia --project=docs docs/make.jl
```

## Coding and Review Guidelines

- Keep changes focused and minimal.
- Add or update tests for behavioral changes.
- Keep docs consistent with CLI/API behavior.
- Prefer deterministic tests and avoid hidden global state.

## Commit Guidelines

- Use clear commit messages, for example:
  - `feat: add registry branch push support`
  - `fix: handle merge request URL fallback`
  - `docs: update publishing tutorial`

## Pull Requests

- Explain what changed and why.
- List test/doc commands you ran.
- Include migration notes when behavior changes.

## Questions

For questions about contribution workflow, contact:

- chenzhiyuan <chenzhiyuan@mail.ustc.edu.cn>

