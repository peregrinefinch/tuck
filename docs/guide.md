# Tucking values into templates

A template has the words. Its data supplies the visitors. Parse a template once
and render that value repeatedly with different objects:

```pooka
import pooka/json.{JObject, JString}
import tuck

main() {
  let assert Ok(page) = tuck.parse("Hello, {{ name }}!")
  echo tuck.render(page, JObject([#("name", JString("Owl"))]))
}
```

The result is `Ok("Hello, Owl!")`. Data is a `pooka/json.Json` object. Lists,
objects, strings, numbers, booleans and nil remain distinct while expressions
are evaluated; missing values are tracked separately from JSON nil.

## Syntax

Tuck uses the `.tuck` file extension. The entry template selects the output policy. Names ending in `.html.tuck`,
`.htm.tuck`, `.xml.tuck`, or `.svg.tuck` select HTML escaping (case-insensitively).
Includes and inherited blocks keep that entry policy; a plain partial included
by an HTML page therefore still escapes dynamic values.

### Variables

```html
<h1>Hello, {{ user.name }}!</h1>
<p>{{ posts[0].title }}</p>
```

### Filters

```html
<p>{{ user.name | upper }} wrote {{ posts | length }} posts: {{ tags | join(", ") }}</p>
<p>{{ user.nickname | default("friend") }}</p>
```

`upper`, `lower`, `capitalize`, `trim`, `length`, `join`, `first`, `last`, `reverse`, `sort`, `truncate`, `replace`, `json`, plus `default`, `escape` and `safe`. Add your own with `tuck.with_filter`.

### Conditions

```html
{% if user.logged_in %}
  <p>Welcome back!</p>
{% elif user.invited %}
  <p>Welcome!</p>
{% else %}
  <p>Please sign in.</p>
{% endif %}
```

Conditions understand `==`, `!=`, `<`, `<=`, `>`, `>=`, `in`, `and`, `or` and `not`.

### Loops

```html
<ul>
{% for post in posts %}
  <li>{{ loop.index }}. {{ post.title }}</li>
{% else %}
  <li>Nothing yet.</li>
{% endfor %}
</ul>
```

`loop` also has `index0`, `first`, `last` and `length`. Loop over an object's fields with two names: `{% for key, value in scores %}`.

### Includes

```html
{% include "partials/header.tuck" %}
```

### Template inheritance

```html
{% extends "layouts/base.tuck" %}

{% block content %}
  <h1>Welcome to Pooka!</h1>
{% endblock %}
```

### Comments, raw text and whitespace

```html
{# a note for whoever reads the template next #}
{% raw %}{{ printed exactly as written }}{% endraw %}
{%- if trimmed -%} a dash trims the whitespace on its side {%- endif %}
```

## Helpful errors

Every error names the template, the line and the column, and suggests what you might have meant:

```text
home.html.tuck:4:12: unknown filter `uppr`; did you mean `upper`?
home.html.tuck:9:8: `user` has no field `emial`; did you mean `email`?
```


## A library of templates

`tuck.library()` starts empty. `tuck.add` parses text and returns a new library;
adding the same name replaces that entry. `tuck.load("templates")` reads a folder
and its descendants in deterministic order, keeping only `.tuck` files. Names
inside the library use `/`, such as `layouts/base.html.tuck`.

```pooka
let assert Ok(pages) = tuck.library()
  |> tuck.add("base.html.tuck", "<main>{% block body %}{% endblock %}</main>")
let assert Ok(pages) = pages
  |> tuck.add("home.html.tuck", "{% extends \"base.html.tuck\" %}{% block body %}Hello {{ name }}{% endblock %}")
let data = JObject([#("name", JString("<Owl>"))])
assert tuck.render_named(pages, "home.html.tuck", data) == Ok("<main>Hello &lt;Owl&gt;</main>")
```

Include and extends names are library-root names. A parsed standalone template
needs a library to resolve other templates. An include shares the surrounding
variables and loop metadata, but owns its inheritance chain: block overrides
from its caller cannot overwrite the partial's blocks.

Each template may declare a block name once. An extending template still puts
its declarations inside blocks; use `set` within a block for local values. A child and its parent may of
course declare the same block: that is how overriding works. Includes and
inheritance cycles return errors with their template names.

Libraries already contain parsed templates; rendering does not read them from
disk again. Each render builds a dictionary index for repeated include lookups
and prepares the built-in/custom filter registry once.

## Loop metadata

`loop.index` starts at one and `loop.index0` starts at zero. `loop.revindex` and
`loop.revindex0` count down from the other end. `first`, `last`, and `length`
retain their ordinary meanings. Nested loops expose the enclosing loop as
`loop.parent`; at the top level it is nil.

```html
{% for row in rows %}
  {% for bird in row %}
    {{ loop.parent.index }}.{{ loop.index }} — {{ bird }}
  {% endfor %}
{% endfor %}
```

The key and value names in an object loop must differ. `loop` and expression
keywords are reserved as loop variables, so metadata and literals cannot be
silently hidden.

## Missing values and filters

An absent value is false in a condition and may be replaced with
`| default("friend")`. Printing it otherwise returns a helpful error. `default`
requires exactly one fallback, but evaluates it only when needed. False, zero,
and empty strings are present values and are not replaced.

Zero-argument filters reject arguments. `join` accepts an optional separator,
`truncate` takes a length and optional ending, and `replace` takes two strings.
Custom filters retain their own argument contracts:

```pooka
import pooka/json.{JString, Json}

let shout = fn(value: Json, arguments: List(Json)) {
  match #(value, arguments) {
    #(JString(text), []) -> Ok(JString(text + "!"))
    _ -> Error("shout needs text and no arguments")
  }
}
let pages = tuck.library() |> tuck.with_filter("shout", shout)
```

Custom filters can replace ordinary built-ins; `default`, `safe`, and `escape`
remain renderer-managed operations. `escape` marks its result as already
escaped. Repeating it does not escape twice. `safe` explicitly bypasses HTML
escaping. A subsequent ordinary filter returns an ordinary value, which will
be escaped again if printed into HTML.

HTML escaping protects dynamic text characters, not JavaScript, CSS, or URL
semantics. Template source itself is trusted text. Choose a format-specific
encoding/filter when placing a value into another embedded language.

Numeric comparisons preserve exact integer values, including mixed comparisons
with Float values beyond Float's exact-integer range. Text is ordered as text;
comparing unrelated kinds returns an error.

## Bound resource use

Direct `parse`, `load`, and `render` operations remain synchronous. Checked
variants put parsing or rendering in an isolated monitored BEAM worker:

```pooka
import tuck/limits

let budget = limits.defaults()
let assert Ok(page) = tuck.parse_checked("home.html.tuck", "Hello {{ name }}", tuck.Escape.Html, budget)
let output = tuck.render_checked(page, JObject([#("name", JString("Owl"))]), budget)
```

`limits.Budget` fields are maximum source bytes, final output bytes, BEAM
reductions, worker heap words, and elapsed milliseconds. Defaults are one MiB
of source, four MiB of output, twenty million reductions, four million heap
words, and five seconds.

- `parse_checked` checks source size before parsing.
- `load_checked` applies source size to each file; work, heap, and time cover
  the complete folder operation.
- `render_checked` and `render_named_checked` cover evaluation, custom filters,
  includes, and inheritance. Completed output is size-checked inside the worker
  before it is returned.

Intermediate allocations are covered by the worker budget. Reductions are
polled and heap limits are checked during runtime collection; these are BEAM
resource guards, not an operating-system memory sandbox. Cancellation kills
and joins the worker before returning. It cannot undo IO already performed by
an application-supplied custom filter.

Syntax/evaluation errors retain their source locations. Resource failures use
the entry template at `1:1`, since a cancelled worker cannot provide a reliable
current AST location. `tuck.describe` formats either as a readable sentence.

## Test and review

All tests use Poke. Properties exercise Unicode, escaping and repeated rendering;
regressions cover includes, declarations, precision and resource cancellation.
Snapshots live in `test/snapshots/`:

```sh
pooka test
pooka run -m poke review
```

The reviewer stages changed output rather than accepting it during a test.
The accepted snapshots cover an inherited HTML page and a helpful diagnostic.


## Give a host application its infrastructure

The host supplies `site`, `page`, or any other data as ordinary JSON objects.
Tuck does not read a site configuration or discover content on its own:

```html
<title>{{ page.title }} — {{ site.title }}</title>
<p>{{ site.params.author }}</p>
<p>{{ page.params.description | default("") }}</p>
```

Functions are registered separately from data. A namespace is a dotted name in
the registry, not a runtime module or a callable method hidden in JSON.

```pooka
import pooka/json.{JInt, JObject, JString, Json}
import tuck

main() {
  let assert Ok(pages) = tuck.library()
    |> tuck.add("home.html.tuck", "{{ page.title }} — {{ time.now().year }}")
  let clock = fn(arguments: List(Json)) {
    match arguments {
      [] -> Ok(JObject([#("year", JInt(2026))]))
      _ -> Error("expected no arguments")
    }
  }
  let assert Ok(pages) = pages |> tuck.with_function("time.now", clock)
  let data = JObject([#("page", JObject([#("title", JString("Reading room"))]))])
  echo tuck.render_named(pages, "home.html.tuck", data)
}
```

`with_function` returns a Result so invalid names are rejected during setup.
Registering a name again returns a new library with that callback replaced.
Callbacks validate their arguments and return `Result(Json, String)`. Failures
name the function and the calling template position. Returned strings follow
normal HTML escaping; they are not automatically trusted markup.

There is no implicit `time.now` clock. The host can capture one timestamp at the
beginning of a build, supply a real clock, or inject a fixed value for tests.
The same registry can expose formatting, URL, Markdown, or collection helpers
without adding those dependencies to Tuck. Checked rendering budgets host calls
along with the template evaluation.

Calls can be nested and their returned data can be accessed normally:

```html
{{ dates.format(time.now(), "2006-01-02") }}
{{ collections.first(page.related).title }}
```

Those names must be registered by the application. Arbitrary values and methods
cannot be called; for example, a field fetched with `page["callback"]()` is not
a callable capability. Function names use identifier components separated by
dots. Reserved expression words and the `super` namespace cannot be registered.

## Local variables and lexical scopes

```html
{% set heading = page.title | upper %}
<h1>{{ heading }}</h1>
{% with heading = "Related pages", original = heading %}
  <h2>{{ heading }}</h2>
  <p>Related to {{ original }}</p>
{% endwith %}
```

`set` affects following nodes in its current scope. `with` bindings are all
evaluated against the enclosing scope; one binding cannot implicitly depend
on another binding from the same tag. Leaving a `with`, branch, loop iteration,
or included template restores the surrounding values. Root render data is
never mutated.

Assignments preserve already-safe values, including parent-block output, so
saving and printing them does not double-escape HTML. Missing explicit bindings
return errors at their source positions. Duplicate binding names and reserved
names such as `loop` are rejected while parsing.

A function result can be saved for repeated use:

```html
{% set build_time = time.now() %}
{{ build_time.year }} / {{ build_time.year }}
```

## Pass explicit data to partials

```html
{% include "partials/card.html.tuck" with title=page.title, url=page.url %}
{% include "partials/card.html.tuck" with title=page.title, url=page.url only %}
```

The first partial can see surrounding values, with the explicit arguments
shadowing them. `only` removes ambient render data and local variables. A bare
`{% include "partial.tuck" only %}` starts with no data names at all.
Registered host functions and the entry output policy remain available.

Arguments are evaluated in the caller, so a missing `page.title` reports the
calling template's position. Assignments inside the partial cannot change its
caller, and its inheritance blocks remain isolated from caller overrides.

## Add to a parent block

```html
{% extends "base.html.tuck" %}
{% block body %}
  {{ super() }}
  <p>A little more from the child.</p>
{% endblock %}
```

`super()` renders the next ancestor version of the current block. Multi-level
inheritance follows each version in turn. The result is already rendered output,
so it retains its safe marker when printed or saved with `set`.

It takes no arguments. Calling it outside a block with a parent is an error.
Each nested block owns its own chain; an included partial cannot borrow its
caller's `super()` context.
