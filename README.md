# Tuck 🧵

[![Package Version](https://img.shields.io/hexpm/v/tuck?style=for-the-badge&color=75618E)](https://hex.pm/packages/tuck)
[![Hex Docs](https://img.shields.io/website?url=https%3A%2F%2Ftuck.hexdocs.pm%2F&style=for-the-badge&label=hex&up_message=docs&up_color=FF891F&down_message=not%20found&down_color=lightgrey)](https://tuck.hexdocs.pm/)
[![Tests](https://img.shields.io/github/actions/workflow/status/peregrinefinch/tuck/test.yml?style=for-the-badge&label=tests)](https://github.com/peregrinefinch/tuck/actions/workflows/test.yml)

Templates for HTML, email, and other text in Pooka.

## Installation

```sh
pooka add tuck
```

## Usage

```pooka
module main

import pooka/json.{JObject, JString}
import tuck

main() {
  let assert Ok(page) = tuck.parse("Hello, {{ name }}!")
  let data = JObject([#("name", JString("Owl"))])
  echo tuck.render(page, data)
}
```

Parse once, then render with different data. Libraries add includes and template
inheritance; HTML output escapes dynamic values by default. Conditions, loops,
filters, registered host functions, local scopes, explicit partial arguments,
`super()`, and resource-bounded APIs are covered in the [guide](docs/guide.md).

## Licence

Licensed under the [Apache License, Version 2.0](LICENSE).
