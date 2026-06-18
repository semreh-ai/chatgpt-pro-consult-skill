# Contributing

This repo is a thin skill wrapper. Keep it auditable.

## Rules

- Do not add code that reads browser cookies, browser profiles, keychains, password managers, or session stores.
- Do not add hard-coded provider credentials or token handling.
- Do not auto-upload whole repositories.
- Do not vendor upstream code unless the MIT attribution requirements are explicitly handled.
- Keep the root `SKILL.md` valid for `npx skills add` discovery.

## Validate

```bash
npm test
npx skills add . --list
```

## Release checklist

1. Run tests.
2. Verify `npx skills add . --list` finds exactly one skill.
3. Tag a release.
4. Test install by GitHub ref:

```bash
npx skills add semreh-ai/chatgpt-pro-consult-skill#vX.Y.Z --list
```
