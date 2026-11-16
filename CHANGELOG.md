# Changelog

## 1.0.0

Initial release.

- Parse templates once and render variables, fields, indexed values, conditions,
  loops, includes, inheritance, comments, raw blocks and whitespace control.
- Add thirteen built-in filters plus lazy default, explicit escape/safe values,
  and custom filters with validated argument contracts.
- Preserve include-local block overrides, reject duplicate blocks and ambiguous
  loop bindings, and expose parent/reverse loop metadata.
- Escape dynamic values according to the entry template's output policy,
  including partials and inherited blocks; recognise markup extensions without
  case sensitivity.
- Preserve integer precision in mixed integer/Float comparisons and sorting.
- Index templates and prepare filter registries once per render.
- Add resource-bounded parsing, loading and rendering with source/output byte,
  work, heap and elapsed-time budgets.
- Report errors with template names, source positions and spelling suggestions.
- Add Poke properties, regression tests, HTML/diagnostic snapshots, documentation,
  and Linux/macOS/Windows CI configuration.
- Add registered namespaced host functions with typed JSON arguments/results,
  setup validation, source-aware errors, and injected-clock support.
- Add lexical `set`/`with`, explicit include arguments and `only` isolation.
- Preserve complete block ancestry for `super()`, including safe parent output
  saved through bindings, nested block scope and include isolation.
- Keep site/page content and build orchestration in the host application.
- Licensed under Apache-2.0.
