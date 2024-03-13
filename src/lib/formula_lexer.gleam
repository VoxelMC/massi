import gleam/io
import gleam/int
import gleam/list
import gleam/regex
import gleam/result
import gleam/string
import lib/util/math.{int_to_float}
import colored

/// A `Token` represents an element, element quantity, an unknown element, or
/// the end of a formula.
pub type Token {
  Hydrogen
  Carbon
  Nitrogen
  Oxygen

  Bromine
  Number(value: Int)
  Unknown
  EndOfFormula
}

pub type TokenType {
  CharToken(value: String)
  NumberToken(value: Int)
  EndOfFormulaToken
  NoneToken
}

type NextTokenType {
  CharTokenNext
  NumberTokenNext
  NoneTokenNext
}

/// Returns a list of tokens generated from a string of elements.
pub fn lex_formula(input: String) -> List(Token) {
  let chars =
    input
    |> string.split(on: "")
  case chars {
    [] -> {
      [EndOfFormula]
    }
    char_list ->
      walk(char_list, 0, [])
      |> collapse_tokens()
  }
}

fn tokenize(char: String) {
  get_token_type(char, CharTokenNext)
}

fn get_token_type(char: String, token_type: NextTokenType) -> TokenType {
  let assert Ok(char_reg) = regex.from_string("^[a-zA-Z]$")
  let assert Ok(number_reg) = regex.from_string("[0-9]")

  let what = case token_type {
    CharTokenNext -> {
      let is_char = regex.check(with: char_reg, content: char)
      case is_char {
        True -> Ok(CharToken(value: char))
        False -> Error(NumberTokenNext)
      }
    }
    NumberTokenNext -> {
      let is_number = regex.check(with: number_reg, content: char)

      case is_number {
        True -> Ok(NumberToken(value: result.unwrap(int.parse(char), -1)))
        False -> Error(NoneTokenNext)
      }
    }
    NoneTokenNext -> Ok(EndOfFormulaToken)
  }

  case what {
    Ok(token) -> token
    Error(next) -> get_token_type(char, next)
  }
}

fn walk(
  chars: List(String),
  position: Int,
  accumulator: List(TokenType),
) -> List(TokenType) {
  let char =
    chars
    |> list.at(position)
    |> result.unwrap("EOI")
  let is_end = char == "EOI"

  let token = tokenize(char)
  let new_accumulator =
    accumulator
    |> list.append([token])

  case is_end {
    True -> new_accumulator
    False -> walk(chars, position + 1, new_accumulator)
  }
}

fn collapse_tokens(accumulator: List(TokenType)) {
  accumulator
  |> do_collapse_tokens([], start: 0)
}

fn do_collapse_tokens(
  accumulator: List(TokenType),
  current_accumulator: List(Token),
  start position: Int,
) -> List(Token) {
  let cur =
    accumulator
    |> list.at(position)
    |> result.unwrap(NoneToken)
  let prev =
    accumulator
    |> list.at(position - 1)
    |> result.unwrap(NoneToken)
  let next =
    accumulator
    |> list.at(position + 1)
    |> result.unwrap(NoneToken)

  let next_is_char = case next {
    CharToken(val) -> #(True, val)
    _ -> #(False, "")
  }

  let prev_in_cur_acc =
    current_accumulator
    |> list.last()
    |> result.unwrap(Unknown)

  let new = case cur {
    NumberToken(value) ->
      tokenize_number(current: value, prev_acc: prev, prev_cur: prev_in_cur_acc)
    CharToken(value) -> {
      let tokenized = tokenize_element(value)
      let element_token = case tokenized {
        Ok(token) -> token
        Error(current) if next_is_char.0 -> {
          tokenize_element(current <> next_is_char.1)
          |> result.unwrap(Unknown)
        }
        _ -> EndOfFormula
      }
      #(False, element_token)
    }
    EndOfFormulaToken -> #(False, EndOfFormula)
    _ -> #(False, EndOfFormula)
  }
  let replace = new.0

  let new_accumulator = case replace {
    True ->
      current_accumulator
      |> list.take(list.length(current_accumulator) - 1)
      |> list.append([new.1])
    False ->
      current_accumulator
      |> list.append([new.1])
  }

  case new {
    #(_, EndOfFormula) -> new_accumulator
    #(_, _) ->
      do_collapse_tokens(accumulator, new_accumulator, start: position + 1)
  }
}

pub fn tokenize_element(name: String) -> Result(Token, String) {
  let token = case name {
    "H" -> Hydrogen

    "C" -> Carbon

    "N" -> Nitrogen
    "O" -> Oxygen

    "Br" -> Bromine
    _ -> Unknown
  }
  case token {
    Unknown -> Error(name)
    _ -> Ok(token)
  }
}

pub fn tokenize_number(
  current value: Int,
  prev_acc prev: TokenType,
  prev_cur prev_cur: Token,
) {
  case prev {
    NumberToken(value2) ->
      case prev_cur {
        Number(value3) -> {
          let digits =
            int.digits(value3, 10)
            |> result.unwrap([])
          let concatenated = list.concat([digits, [value]])
          let res = int.undigits(concatenated, 10)
          #(
            True,
            Number(
              value: res
              |> result.unwrap(value3),
            ),
          )
        }
        _ -> #(
          True,
          Number(
            value: int.undigits([value2, value], 10)
            |> result.unwrap(value),
          ),
        )
      }

    _ -> #(False, Number(value))
  }
}

pub fn calculate(accumulator: List(Token), exact exact: Bool) -> Float {
  calculator(accumulator, exact, 0.0, 0)
}

fn calculator(
  accumulator: List(Token),
  exact: Bool,
  current_total: Float,
  position: Int,
) -> Float {
  let current_token =
    accumulator
    |> list.at(position)
    |> result.unwrap(Unknown)
  let next_token =
    accumulator
    |> list.at(position + 1)
    |> result.unwrap(EndOfFormula)

  case next_token {
    EndOfFormula -> current_total +. mass_from_token(current_token, exact)
    Number(val) ->
      calculator(
        accumulator,
        exact,
        current_total
          +. int_to_float(val)
          *. mass_from_token(current_token, exact),
        position + 2,
      )
    _ ->
      calculator(
        accumulator,
        exact,
        current_total +. mass_from_token(current_token, exact),
        position + 1,
      )
  }
}

pub fn mass_from_token(token: Token, exact exact: Bool) {
  let out = case exact {
    True -> exact_mass_from_token(token)
    False -> approx_mass_from_token(token)
  }
  case out {
    Ok(mass) -> mass
    Error(MassNotFound) -> {
      io.println_error(colored.yellow(
        "!> The input contained an unrecognizable token. Please double check to ensure it was entered correctly. Note: input is case-sensitive.",
      ))
      io.println_error(colored.yellow(
        "!> Calculating with unknown token omitted...",
      ))
      0.0
    }
    Error(FormulaCompleted) -> 0.0
  }
  // Careful, icarus...
}

pub type MassError {
  MassNotFound
  FormulaCompleted
}

// TODO: https://byjus.com/question-answer/name-all-the-118-elements-in-the-periodic-table-with-their-symbol-atomic-mass-and/
// // https://ciaaw.org/atomic-weights.htm
/// Get the exact mass of an element by its token.
pub fn exact_mass_from_token(token: Token) -> Result(Float, MassError) {
  let out = case token {
    Hydrogen -> 1.00784
    Carbon -> 12.0
    Nitrogen -> 14.00643
    Oxygen -> 15.9949
    Bromine -> 78.9183
    EndOfFormula -> 0.69
    Unknown -> -0.14
    Number(val) -> int_to_float(val)
  }
  case out {
    0.69 -> Error(FormulaCompleted)
    -0.14 -> Error(MassNotFound)
    _ -> Ok(out)
  }
}

/// Get the approximate mass of an element by its token.
pub fn approx_mass_from_token(token: Token) -> Result(Float, MassError) {
  let out = case token {
    Hydrogen -> 1.008
    Carbon -> 12.0107
    Nitrogen -> 14.007
    Oxygen -> 15.999
    Bromine -> 79.904
    EndOfFormula -> 0.69
    Unknown -> -0.14
    Number(val) -> int_to_float(val)
  }
  case out {
    0.69 -> Error(FormulaCompleted)
    -0.14 -> Error(MassNotFound)
    _ -> Ok(out)
  }
}
