import gleam/io
import gleam/string
import colored
import lib/formula_lexer.{calculate, lex_formula}
import glint
import glint/flag
import argv

const verbose = "verbose"

fn verbose_flag() -> flag.FlagBuilder(Bool) {
  flag.bool()
  |> flag.default(False)
  |> flag.description("Request verbose log messages. Useful for diagnostics.")
}

const approx = "approx"

fn approx_flag() -> flag.FlagBuilder(Bool) {
  flag.bool()
  |> flag.default(False)
  |> flag.description(
    "Calculate using approximate masses instead of monoisotopic masses.",
  )
}

pub fn main() {
  glint.new()
  |> glint.with_name("massif")
  |> glint.with_pretty_help(glint.default_pretty_help())
  |> glint.add(
    at: [],
    do: glint.command(exec)
      |> glint.description(
        "Calculate the monoisotopic mass of a compound from a molecular formula.",
      )
      |> glint.flag(approx, approx_flag())
      |> glint.flag(verbose, verbose_flag()),
  )
  |> glint.run(argv.load().arguments)
}

pub fn exec(input: glint.CommandInput) -> Nil {
  let assert Ok(approx) = flag.get_bool(from: input.flags, for: approx)
  let assert Ok(verbose) = flag.get_bool(from: input.flags, for: verbose)
  log_verbose("Flags:", #(approx, verbose), verbose)
  let formula = case input.args {
    [] -> {
      io.println_error(colored.yellow(
        "!> The input was empty! Please double check to ensure it was entered correctly.",
      ))
      ""
    }
    [formula, ..] -> formula
  }

  let lexed_formula =
    formula
    |> lex_formula()

  let mass = calculate(lexed_formula, !approx)

  io.println(
    mass
    |> string.inspect,
  )
  Nil
}

fn log_verbose(title: String, message: a, verbose is_verbose: Bool) -> Nil {
  case is_verbose {
    True ->
      io.println(
        {
          "v> "
          <> title
          <> " "
          <> message
          |> string.inspect
        }
        |> colored.yellow(),
      )
    _ -> Nil
  }
  Nil
}
