//// Functions for building `Arg`s. An `Arg` is a positional option.

import clip/internal/aliases.{type Args, type FnResult}
import clip/internal/arg_info.{
  type ArgInfo, type PositionalInfo, ArgInfo, Many1Repeat, ManyRepeat, NoRepeat,
  PositionalInfo,
}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

pub opaque type Arg(a) {
  Arg(
    name: String,
    default: Option(a),
    help: Option(String),
    try_map: fn(String) -> Result(a, String),
  )
}

fn pos_info(arg: Arg(a)) -> PositionalInfo {
  case arg {
    Arg(name:, default:, help:, try_map: _) ->
      PositionalInfo(
        name:,
        default: default |> option.map(string.inspect),
        help:,
        repeat: NoRepeat,
      )
  }
}

/// Used internally, not intended for direct usage.
pub fn to_arg_info(arg: Arg(a)) -> ArgInfo {
  ArgInfo(..arg_info.empty(), positional: [pos_info(arg)])
}

/// Used internally, not intended for direct usage.
pub fn to_arg_info_many(arg: Arg(a)) -> ArgInfo {
  ArgInfo(
    ..arg_info.empty(),
    positional: [PositionalInfo(..pos_info(arg), repeat: ManyRepeat)],
  )
}

/// Used internally, not intended for direct usage.
pub fn to_arg_info_many1(arg: Arg(a)) -> ArgInfo {
  ArgInfo(
    ..arg_info.empty(),
    positional: [PositionalInfo(..pos_info(arg), repeat: Many1Repeat)],
  )
}

/// Modify the value produced by an `Arg` in a way that may fail.
///
/// ```gleam
/// arg.new("age")
/// |> arg.try_map(fn(age_str) {
///   case int.parse(age_str) {
///     Ok(age) -> Ok(age)
///     Error(Nil) -> Error("Unable to parse integer")
///   }
/// })
/// ```
///
/// Note: `try_map` can change the type of an `Arg` and therefore clears any
/// previously set default value.
pub fn try_map(arg: Arg(a), f: fn(a) -> Result(b, String)) -> Arg(b) {
  case arg {
    Arg(name:, default: _, help:, try_map:) ->
      Arg(name:, default: None, help:, try_map: fn(arg) {
        use a <- result.try(try_map(arg))
        f(a)
      })
  }
}

/// Modify the value produced by an `Arg` in a way that cannot fail.
///
/// ```gleam
/// arg.new("name")
/// |> arg.map(fn(name) { string.uppercase(name) })
/// ```
///
/// Note: `map` can change the type of an `Arg` and therefore clears any
/// previously set default value.
pub fn map(arg: Arg(a), f: fn(a) -> b) -> Arg(b) {
  try_map(arg, fn(a) { Ok(f(a)) })
}

/// Transform an `Arg(a)` to an `Arg(Result(a, Nil)`, making it optional.
pub fn optional(arg: Arg(a)) -> Arg(Result(a, Nil)) {
  arg |> map(Ok) |> default(Error(Nil))
}

/// Provide a default value for an `Arg` when it is not provided by the user.
pub fn default(arg: Arg(a), default: a) -> Arg(a) {
  case arg {
    Arg(name:, default: _, help:, try_map:) ->
      Arg(name:, default: Some(default), help:, try_map:)
  }
}

/// Add help text to an `Arg`.
pub fn help(arg: Arg(a), help: String) -> Arg(a) {
  case arg {
    Arg(name:, default:, help: _, try_map:) ->
      Arg(name:, default:, help: Some(help), try_map:)
  }
}

/// Modify an `Arg(String)` to produce an `Int`.
///
/// ```gleam
/// arg.new("age")
/// |> arg.int
/// ```
///
/// Note: `int` changes the type of an `Arg` and therefore clears any
/// previously set default value.
pub fn int(arg: Arg(String)) -> Arg(Int) {
  arg
  |> try_map(fn(val) {
    int.parse(val)
    |> result.map_error(fn(_) { "Non-integer value provided for " <> arg.name })
  })
}

/// Modify an `Arg(String)` to produce a `Float`.
///
/// ```gleam
/// arg.new("height")
/// |> arg.float
/// ```
///
/// Note: `float` changes the type of an `Arg` and therefore clears any
/// previously set default value.
pub fn float(arg: Arg(String)) -> Arg(Float) {
  arg
  |> try_map(fn(val) {
    float.parse(val)
    |> result.map_error(fn(_) { "Non-float value provided for " <> arg.name })
  })
}

/// Create a new `Arg` with the provided name. New `Arg`s always initially
/// produce a `String`, which is the unmodified value given by the user on the
/// command line.
pub fn new(name: String) -> Arg(String) {
  Arg(name:, default: None, help: None, try_map: Ok)
}

/// Run an `Arg(a)` against a list of arguments. Used internally by `clip`, not
/// intended for direct usage.
pub fn run(arg: Arg(a), args: Args) -> FnResult(a) {
  case args, arg.default {
    [head, ..rest], _ -> {
      case string.starts_with("head", "-") {
        True ->
          run(arg, rest)
          |> result.map(fn(v) { #(v.0, [head, ..v.1]) })
        False -> {
          use a <- result.try(arg.try_map(head))
          Ok(#(a, rest))
        }
      }
    }
    [], Some(v) -> Ok(#(v, []))
    [], None -> Error("missing required arg: " <> arg.name)
  }
}

fn run_many_aux(acc: List(a), arg: Arg(a), args: Args) -> FnResult(List(a)) {
  case args {
    [] -> Ok(#(list.reverse(acc), []))
    _ ->
      case run(arg, args) {
        Ok(#(a, rest)) -> run_many_aux([a, ..acc], arg, rest)
        Error(_) -> Ok(#(list.reverse(acc), args))
      }
  }
}

/// Run an `Arg(a)` against a list of arguments producing zero or more results.
/// Used internally by `clip`, not intended for direct usage.
pub fn run_many(arg: Arg(a), args: Args) -> FnResult(List(a)) {
  run_many_aux([], arg, args)
}

/// Run an `Arg(a)` against a list of arguments producing one or more results.
/// Used internally by `clip`, not intended for direct usage.
pub fn run_many1(arg: Arg(a), args: Args) -> FnResult(List(a)) {
  use #(vs, rest) <- result.try(run_many_aux([], arg, args))
  case vs {
    [] -> Error("must provide at least one valid value for: " <> arg.name)
    _ -> Ok(#(vs, rest))
  }
}
