import 'dart:convert';
import 'dart:typed_data';

/// ABK content codec — repeating-key XOR (recovered & runtime-confirmed).
///
/// Key: `r+3e>@y](7wEEM[` (15 bytes). Symmetric: the same transform encodes a
/// request payload and decodes a response body. Operates at the byte level,
/// which matches the byte-wise PHP middleware for the ASCII/`\uXXXX`-escaped
/// JSON this backend uses.
class XorCodec {
  final Uint8List key;

  XorCodec(this.key) {
    if (key.isEmpty) {
      throw ArgumentError('XOR key must not be empty');
    }
  }

  /// The confirmed ABK key.
  factory XorCodec.abk() => XorCodec(Uint8List.fromList('r+3e>@y](7wEEM['.codeUnits));

  Uint8List xor(Uint8List data) {
    final klen = key.length;
    final out = Uint8List(data.length);
    for (var i = 0; i < data.length; i++) {
      out[i] = data[i] ^ key[i % klen];
    }
    return out;
  }

  /// Plaintext JSON string -> obfuscated bytes for the `json` form field.
  Uint8List encodeString(String plaintext) =>
      xor(Uint8List.fromList(utf8.encode(plaintext)));

  /// Obfuscated response bytes -> plaintext string (caller should trim()).
  String decodeToString(Uint8List body) =>
      utf8.decode(xor(body), allowMalformed: true);
}
