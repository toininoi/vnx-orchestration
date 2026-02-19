# Contributing

Thanks for contributing to VNX.

## Scope for contributions

We accept focused PRs for:

- portability and packaging improvements
- CLI reliability (`init`, `start`, `doctor`, `patch-agent-files`)
- documentation and examples
- test coverage and CI hardening

Out of scope for this repo:

- paid/enterprise-only features
- broad architecture rewrites without prior alignment

## Workflow

1. Fork and create a branch.
2. Keep PRs small and scoped to one logical change.
3. Include tests or smoke commands when behavior changes.
4. Ensure CI is green.

## No merge timeline guarantee

Maintainers review PRs as time allows. Opening a PR does not guarantee merge timing.

## PR checklist

- [ ] Change is scoped and documented
- [ ] `vnx doctor` smoke path works
- [ ] No runtime artifacts added to dist
- [ ] No secrets committed
