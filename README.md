# clip - A CLI Option Parser for Gleam

[![Package Version](https://img.shields.io/hexpm/v/clip)](https://hex.pm/packages/clip)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/clip/)

`clip` is a library for parsing command line interface options.

## Simple Example

```gleam
import argv
import clip
import clip/opt
import gleam/io
import gleam/string

type Person {
  Person(name: String, age: Int)
}

fn command() {
  clip.command(fn(name) { fn(age) { Person(name, age) } })
  |> clip.opt(opt.new("name") |> opt.help("Your name"))
  |> clip.opt(opt.new("age") |> opt.int |> opt.help("Your age"))
}

pub fn main() {
  let result =
    command()
    |> clip.add_help("person", "Create a person")
    |> clip.run(argv.load().arguments)

  case result {
    Error(e) -> io.println_error(e)
    Ok(person) -> person |> string.inspect |> io.println
  }
}
```

```
$ gleam run -- --help
   Compiled in 0.00s
    Running cli.main
person -- Create a person

Usage:

  person [OPTIONS]

Options:

  (--name NAME) Your name
  (--age AGE)   Your age
  [--help,-h]   Print this help
```

```
$ gleam run -- --name Drew --age 42
   Compiled in 0.00s
    Running cli.main
Person("Drew", 42)
```

## Using `clip`

`clip` is an "applicative style" options parser. To use `clip`, we follow these
steps:

1. First, we invoke `clip.command`, providing a function to be called with our
   parsed options. This function needs to be provided in a curried style,
   meaning a two argument function looks like `fn(a) { fn(b) { do_stuff(a, b) }
   }`.
2. We use the `|>` operator along with `clip.opt`, `clip.flag`, and `clip.arg`
   to parse our command line arguments and provide them as parameters to the
   function given to `clip.command`.
3. We use `clip.add_help` to generate help text for our command. The user can
   view this help text via the `--help,-h` flag.
4. Finally, we run our parser with `clip.run`, giving it the command we have
   built and the arguments to parse. We recommend using the `argv` library to
   access these arguments for both erlang and javascript.

## Types of Options

`clip` provides three types of options:

1. An `Option` is a named option with a value, like `--name "Drew"`. You create
   these with the `clip/opt` module and add them to your command with the
   `clip.opt` function.
2. A `Flag` is an option without a value, like `--verbose`. If provided, it
   produces `True`, if not provided it produces `False`. You create these with
   the `clip/flag` module and add them to your command with the `clip.flag`
   function.
3. An `Argument` is a positional value passed to your command. You create
   these with the `clip/arg` module and add them to your command with the
   `clip.arg`, `clip.arg_many`, and `clip.arg_many1` functions.

Take a look at the
[examples](https://github.com/drewolson/clip/tree/main/examples) for more information.
