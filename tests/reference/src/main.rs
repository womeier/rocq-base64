//! Reference/oracle half of the differential test for `rocq-base64`.
//!
//! Two modes:
//!
//!   `b64ref cases`     writes the test corpus to stdout.
//!   `b64ref respond`   answers a corpus on stdin, using the `base64` crate.
//!
//! `tests/harness.ml` answers the same corpus using the OCaml code extracted
//! from `theories/Base64.v`, so the two outputs can simply be diffed.
//!
//! # Why this crate is the oracle
//!
//! Rust's standard library has no base64.  The de-facto implementation is
//! marshallpierce's `base64` crate, and it is the right oracle here because its
//! decoder is strict in exactly the places ours is:
//!
//!   * `decode_allow_trailing_bits` defaults to false, so non-canonical final
//!     symbols (`"QR=="`) are rejected -- `DecodeError::InvalidLastSymbol`;
//!   * `STANDARD` decodes with `DecodePaddingMode::RequireCanonical`;
//!   * `URL_SAFE_NO_PAD` decodes with `DecodePaddingMode::RequireNone`.
//!
//! That is precisely the contract of `standard` and `url` in `theories/Alphabet.v`.
//! Python's `base64.b64decode(..., validate=True)`, by contrast, accepts
//! `"QR=="`, so it would report false mismatches against our decoder.
//!
//! # Where the cases come from
//!
//! `cases` does not invent a corpus: every family below is ported from the
//! crate's own test suite (`src/engine/tests.rs`, `src/tests.rs`,
//! `tests/tests.rs` of base64 0.22.1), named in the comment above it.  The
//! crate's suite itself cannot be run against us -- it is written against the
//! internal `Engine` trait (`internal_encode`, `decode_slice_unchecked`,
//! `DecodeEstimate`), i.e. against buffer-level details our whole-string
//! `encode`/`decode` do not have.  So the *inputs* are reused and both
//! implementations are asked for their answers, which is a stronger check than
//! the upstream assertions: it compares behaviour on every case rather than
//! against a hard-coded expectation.

use base64::engine::general_purpose::{STANDARD, URL_SAFE_NO_PAD};
use base64::Engine;
use std::io::{self, BufRead, BufWriter, Write};

/// The 64 standard alphabet symbols, in value order.
const STD_ALPHABET: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

/// Printable ASCII, minus space: the bytes a line-oriented protocol can carry.
fn printable_ascii() -> impl Iterator<Item = u8> {
    0x21u8..=0x7e
}

// ---------------------------------------------------------------- protocol --

fn hex_decode(s: &str) -> Vec<u8> {
    assert!(s.len() % 2 == 0, "odd-length hex");
    (0..s.len() / 2)
        .map(|i| u8::from_str_radix(&s[2 * i..2 * i + 2], 16).expect("bad hex"))
        .collect()
}

fn hex_encode(bs: &[u8]) -> String {
    bs.iter().map(|b| format!("{:02x}", b)).collect()
}

/// "." stands for the empty string, so that every field is non-empty.
fn dot(s: String) -> String {
    if s.is_empty() {
        ".".to_string()
    } else {
        s
    }
}

fn respond() {
    let stdin = io::stdin();
    let stdout = io::stdout();
    let mut out = BufWriter::new(stdout.lock());
    for line in stdin.lock().lines() {
        let line = line.expect("read");
        if line.len() < 2 {
            continue;
        }
        let tag = line.as_bytes()[0];
        let arg = if line.len() < 3 { "" } else { &line[2..] };
        let arg = if arg == "." { "" } else { arg };
        match tag {
            b'E' => {
                let bs = hex_decode(arg);
                writeln!(
                    out,
                    "{} {}",
                    dot(STANDARD.encode(&bs)),
                    dot(URL_SAFE_NO_PAD.encode(&bs))
                )
                .unwrap();
            }
            b'S' | b'U' => {
                let r = if tag == b'S' {
                    STANDARD.decode(arg)
                } else {
                    URL_SAFE_NO_PAD.decode(arg)
                };
                match r {
                    Ok(bs) => writeln!(out, "{}", dot(hex_encode(&bs))).unwrap(),
                    Err(_) => writeln!(out, "ERR").unwrap(),
                }
            }
            _ => panic!("unknown command: {}", line),
        }
    }
}

// ------------------------------------------------------------------ corpus --

struct Corpus<W: Write> {
    out: W,
    n: u64,
}

impl<W: Write> Corpus<W> {
    /// Encode these bytes under both configs.
    fn enc(&mut self, bs: &[u8]) {
        writeln!(self.out, "E {}", dot(hex_encode(bs))).unwrap();
        self.n += 1;
    }

    /// Decode this text under both configs.  Lines that the protocol cannot
    /// carry are skipped rather than silently mangled.
    fn dec(&mut self, s: &str) {
        if s.bytes().any(|b| b < 0x21 || b > 0x7e) {
            return;
        }
        writeln!(self.out, "S {}", dot(s.to_string())).unwrap();
        writeln!(self.out, "U {}", dot(s.to_string())).unwrap();
        self.n += 2;
    }

    /// A byte string, plus the decode of each of its two encodings.
    fn roundtrip(&mut self, bs: &[u8]) {
        self.enc(bs);
        self.dec(&STANDARD.encode(bs));
        self.dec(&URL_SAFE_NO_PAD.encode(bs));
    }
}

/// splitmix64, so the corpus is identical on every machine and every run.
/// Upstream's `roundtrip_random` seeds from entropy; a fixed seed is what makes
/// a diff-based test reproducible.
struct Rng(u64);

impl Rng {
    fn next_u64(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9e37_79b9_7f4a_7c15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xbf58_476d_1ce4_e5b9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94d0_49bb_1331_11eb);
        z ^ (z >> 31)
    }
    fn bytes(&mut self, len: usize) -> Vec<u8> {
        (0..len).map(|_| (self.next_u64() >> 24) as u8).collect()
    }
}

fn cases() {
    let stdout = io::stdout();
    let mut c = Corpus {
        out: BufWriter::with_capacity(1 << 20, stdout.lock()),
        n: 0,
    };

    // src/engine/tests.rs::rfc_test_vectors_std_alphabet -- RFC 4648 section 10,
    // each vector both padded and with the padding stripped.
    for orig in ["", "f", "fo", "foo", "foob", "fooba", "foobar"] {
        c.roundtrip(orig.as_bytes());
        let padded = STANDARD.encode(orig.as_bytes());
        c.dec(padded.trim_end_matches('='));
        c.dec(&format!("{}=", padded));
    }

    // src/engine/tests.rs::encode_doesnt_write_extra_bytes and
    // ::encode_engine_slice_fits_into_precisely_sized_slice exercise every
    // input length; the length-dependent branches of `encode` are what matter.
    for len in 0..=200usize {
        let bs: Vec<u8> = (0..len).map(|i| (i * 7 + 1) as u8).collect();
        c.roundtrip(&bs);
    }

    // Exhaustive over one and two bytes: every reachable 1- and 2-byte tail,
    // which is where `bytes_of_2` / `bytes_of_3` and the padding live.
    for b in 0..=255u8 {
        c.roundtrip(&[b]);
    }
    for hi in 0..=255u8 {
        for lo in 0..=255u8 {
            c.enc(&[hi, lo]);
        }
    }

    // tests/tests.rs::roundtrip_random_{short_,}standard /
    // src/engine/tests.rs::roundtrip_random.  Upstream varies the round count
    // with the length; a flat 48 samples per length up to 40 is the same shape.
    let mut rng = Rng(0x5eed_1234_5eed_1234);
    for len in 0..=40usize {
        for _ in 0..48 {
            let bs = rng.bytes(len);
            c.roundtrip(&bs);
        }
    }

    // src/engine/tests.rs::decode_detect_invalid_last_symbol_every_possible_two_symbols
    // All 64x64 two-symbol final quads: exactly those whose second symbol has
    // its low 4 bits clear are canonical.
    for &a in STD_ALPHABET.iter() {
        for &b in STD_ALPHABET.iter() {
            let two = Stringify::two(a, b);
            c.dec(&format!("{}==", two));
            c.dec(&two);
            c.dec(&format!("AAAA{}==", two));
            c.dec(&format!("AAAA{}", two));
        }
    }

    // src/engine/tests.rs::decode_detect_invalid_last_symbol_every_possible_three_symbols
    // All 64^3 three-symbol final quads: exactly those whose third symbol has
    // its low 2 bits clear are canonical.
    for &a in STD_ALPHABET.iter() {
        for &b in STD_ALPHABET.iter() {
            for &d in STD_ALPHABET.iter() {
                let three = Stringify::three(a, b, d);
                c.dec(&format!("{}=", three));
                c.dec(&three);
            }
        }
    }

    // src/engine/tests.rs::decode_malleability_test_case_* --
    // https://eprint.iacr.org/2022/361.pdf table 2, tests 1-7.
    for s in [
        "SGVsbG8=", "SGVsbG9=", "SGVsbG9", "SGVsbA==", "SGVsbA=", "SGVsbA", "SGVsbA====",
    ] {
        c.dec(s);
    }

    // src/engine/tests.rs::decode_pad_mode_* -- the six final-chunk shapes,
    // after a run of complete quads.  Upstream goes to 256 prefix quads; the
    // branch being probed does not depend on the prefix length past a couple.
    for quads in 0..=32usize {
        for suffix in ["/w", "/w=", "/w==", "iYU", "iYU=", "AAAA", "=", "==", "===", "===="] {
            c.dec(&format!("{}{}", "AAAA".repeat(quads), suffix));
        }
    }

    // src/engine/tests.rs::do_invalid_trailing_byte -- one stray trailing byte
    // after a complete, correctly padded input.  Upstream also tests b'\n',
    // which a line protocol cannot carry.
    for quads in 0..=32usize {
        c.dec(&format!("{}Cg==*", "ABCD".repeat(quads)));
    }

    // src/engine/tests.rs::do_invalid_trailing_padding_as_invalid_byte_at_first_padding
    for quads in 0..=32usize {
        for suffix in ["AA===", "AAA==", "AAAA="] {
            c.dec(&format!("{}{}", "ABCD".repeat(quads), suffix));
        }
    }

    // src/engine/tests.rs::decode_detect_1_valid_symbol_in_last_quad_invalid_length
    // and ::decode_detect_1_invalid_byte_in_last_quad_invalid_byte -- length
    // congruent to 1 mod 4 is never valid.
    for quads in 0..=32usize {
        c.dec(&format!("{}A", "ABCD".repeat(quads)));
        c.dec(&format!("{}*", "ABCD".repeat(quads)));
        c.dec(&format!("{}AAAAA", "ABCD".repeat(quads)));
    }

    // src/engine/tests.rs::decode_invalid_byte_error -- substitute every
    // transmissible byte at every position of a valid 8-symbol encoding, and
    // likewise insert one.  Catches any disagreement about which characters
    // are in the alphabet, including the two configurable ones.
    for base in ["Zm9vYg==", "Zm9vYmFy"] {
        for pos in 0..base.len() {
            for b in printable_ascii() {
                let mut v = base.as_bytes().to_vec();
                v[pos] = b;
                c.dec(std::str::from_utf8(&v).unwrap());
                let mut v = base.as_bytes().to_vec();
                v.insert(pos, b);
                c.dec(std::str::from_utf8(&v).unwrap());
            }
        }
    }

    // Both configurable alphabet positions, in every quad slot: this is the
    // part of the corpus that distinguishes `standard` (+ /) from `url` (- _).
    for sym in [b'+', b'/', b'-', b'_'] {
        for pos in 0..4 {
            let mut v = b"AAAA".to_vec();
            v[pos] = sym;
            c.dec(std::str::from_utf8(&v).unwrap());
            let mut v = b"AAAAAAAA".to_vec();
            v[4 + pos] = sym;
            c.dec(std::str::from_utf8(&v).unwrap());
        }
    }
    // ... and the byte patterns that produce them: 62 and 63 in each position.
    for bs in [
        [0xfbu8, 0xff, 0xbf].as_slice(),
        [0xff, 0xff, 0xff].as_slice(),
        [0x00, 0x00, 0x00].as_slice(),
        [0xf8, 0x00, 0x00].as_slice(),
        [0xfc, 0x00, 0x00].as_slice(),
    ] {
        c.roundtrip(bs);
    }

    // Random text over the alphabet plus the characters most likely to be
    // mishandled: pure fuzzing of the decoder, including lengths that are not
    // multiples of 4 and padding in illegal positions.
    let mut pool: Vec<u8> = STD_ALPHABET.to_vec();
    pool.extend_from_slice(b"-_=*!.");
    for _ in 0..200_000 {
        let len = (rng.next_u64() % 13) as usize;
        let s: String = (0..len)
            .map(|_| pool[(rng.next_u64() % pool.len() as u64) as usize] as char)
            .collect();
        c.dec(&s);
    }

    c.out.flush().unwrap();
    eprintln!("corpus: {} cases", c.n);
}

/// Small helper so the symbol tuples above read as strings without allocating
/// a `format!` per character.
struct Stringify;

impl Stringify {
    fn two(a: u8, b: u8) -> String {
        String::from_utf8(vec![a, b]).unwrap()
    }
    fn three(a: u8, b: u8, d: u8) -> String {
        String::from_utf8(vec![a, b, d]).unwrap()
    }
}

fn main() {
    match std::env::args().nth(1).as_deref() {
        Some("cases") => cases(),
        Some("respond") => respond(),
        other => {
            eprintln!("usage: b64ref (cases|respond)   [got {:?}]", other);
            std::process::exit(2);
        }
    }
}
