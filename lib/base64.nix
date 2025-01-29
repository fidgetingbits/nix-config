# This is a copy of the decoder from infinisil, plus an encoder
# https://discourse.nixos.org/t/decoding-base64-in-the-nix-language/33893/3

let
  lib = import <nixpkgs/lib>;
  testString = "TWFueSBoYW5kcyBtYWtlIGxpZ2h0IHdvcmsu";

  base64Table = builtins.listToAttrs (
    lib.imap0 (i: c: lib.nameValuePair c i) (
      lib.stringToCharacters "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    )
  );

  # Generated using python3:
  # print(''.join([ chr(n) for n in range(1, 256) ]), file=open('ascii', 'w'))
  ascii = builtins.readFile ./ascii;

  #encode =
  #  str:
  #  let
  #    pad = 3 - lib.mod (lib.length str) 3;
  #    padded = str + lib.concatLists (lib.genList (i: "=") pad);
  #  in
  #  str;

  decode =
    str:
    let
      # List of base-64 numbers
      numbers64 = map (c: base64Table.${c}) (lib.stringToCharacters str);

      # List of base-256 numbers
      numbers256 = lib.concatLists (
        lib.genList (
          i:
          let
            v = lib.foldl' (acc: el: acc * 64 + el) 0 (lib.sublist (i * 4) 4 numbers64);
          in
          [
            (lib.mod (v / 256 / 256) 256)
            (lib.mod (v / 256) 256)
            (lib.mod v 256)
          ]
        ) (lib.length numbers64 / 4)
      );

    in
    # Converts base-256 numbers to ascii
    lib.concatMapStrings (
      n:
      # Can't represent the null byte in Nix..
      lib.substring (n - 1) 1 ascii
    ) numbers256;

  decoded = (decode testString);
  encoded = (encode (decode testString));

in
assert decoded == "Many hands make light work.";
assert encoded == testString;
{
  input = testString;
  inherit decoded encoded;
}
