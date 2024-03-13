import gleam/int
import gleam/float
import gleam/result

pub fn int_to_float(int int: Int) {
  let out =
    int
    |> int.to_string()
  let out =
    { out <> ".0" }
    |> float.parse()
    |> result.unwrap(-1.0)
  out
}
