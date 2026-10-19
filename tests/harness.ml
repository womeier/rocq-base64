(* Differential-test driver around the OCaml code extracted from theories/Base64.v.

   Reads commands on stdin, one per line, and writes exactly one result line
   each.  "." stands for the empty string, both in arguments and in results.

     E <hex>    encode; prints "<standard_padded> <url_unpadded> <url_padded> <standard_unpadded>"
     S <text>   decode with [standard_padded];   prints "<hex>" or "ERR"
     U <text>   decode with [url_unpadded];     prints "<hex>" or "ERR"
     P <text>   decode with [url_padded];       prints "<hex>" or "ERR"
     N <text>   decode with [standard_unpadded]; prints "<hex>" or "ERR"

   The four tags are the 2x2 of alphabet against padding, which is everything
   [Alphabet.config] can express and exactly the four configs it ships.
   [standard_unpadded] is the only one that tests [pad = false] against "+"/"/"
   rather than "-"/"_", so it decorrelates the two axes.

   tests/reference/src/main.rs speaks the same protocol, so the two outputs
   can simply be diffed.  Qualified [Stdlib.] names are needed because the
   extracted sources shadow String, Nat, Bool and Ascii. *)

module Str = Stdlib.String
module L = Stdlib.List

let nat_of_int n =
  let rec go i acc = if i = 0 then acc else go (i - 1) (Datatypes.S acc) in
  go n Datatypes.O

let int_of_nat n =
  let rec go n acc = match n with Datatypes.O -> acc | Datatypes.S m -> go m (acc + 1) in
  go n 0

let byte_of_char ch =
  match Extraction.byte_of_nat (nat_of_int (Char.code ch)) with
  | Some b -> b
  | None -> failwith "byte_of_nat: not a byte"

let char_of_byte b = Char.chr (int_of_nat (Extraction.byte_to_nat b))

let to_bytes s = L.init (Str.length s) (fun i -> byte_of_char (Str.get s i))
let of_bytes bs = Str.concat "" (L.map (fun b -> Str.make 1 (char_of_byte b)) bs)

let hex_decode s =
  if Str.length s mod 2 <> 0 then failwith "odd-length hex";
  Str.init (Str.length s / 2)
    (fun i -> Char.chr (int_of_string ("0x" ^ Str.sub s (2 * i) 2)))

let hex_encode s =
  Str.concat "" (L.init (Str.length s) (fun i -> Printf.sprintf "%02x" (Char.code (Str.get s i))))

let dot s = if s = "" then "." else s
let undot s = if s = "." then "" else s

let () =
  let buf = Buffer.create (1 lsl 16) in
  (try
     while true do
       let line = input_line stdin in
       if Str.length line >= 2 then begin
         let tag = Str.get line 0 in
         let arg = undot (if Str.length line < 3 then "" else Str.sub line 2 (Str.length line - 2)) in
         match tag with
         | 'E' ->
           let bs = to_bytes (hex_decode arg) in
           Buffer.add_string buf (dot (of_bytes (Base64.encode Alphabet.standard_padded bs)));
           Buffer.add_char buf ' ';
           Buffer.add_string buf (dot (of_bytes (Base64.encode Alphabet.url_unpadded bs)));
           Buffer.add_char buf ' ';
           Buffer.add_string buf (dot (of_bytes (Base64.encode Alphabet.url_padded bs)));
           Buffer.add_char buf ' ';
           Buffer.add_string buf (dot (of_bytes (Base64.encode Alphabet.standard_unpadded bs)));
           Buffer.add_char buf '\n'
         | 'S' | 'U' | 'P' | 'N' ->
           let cfg =
             match tag with
             | 'S' -> Alphabet.standard_padded
             | 'U' -> Alphabet.url_unpadded
             | 'P' -> Alphabet.url_padded
             | _ -> Alphabet.standard_unpadded
           in
           (match Base64.decode cfg (to_bytes arg) with
            | Some bs -> Buffer.add_string buf (dot (hex_encode (of_bytes bs)))
            | None -> Buffer.add_string buf "ERR");
           Buffer.add_char buf '\n'
         | _ -> failwith ("unknown command: " ^ line)
       end
     done
   with End_of_file -> ());
  print_string (Buffer.contents buf)
