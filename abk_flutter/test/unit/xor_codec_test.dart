import 'dart:convert';
import 'dart:typed_data';

import 'package:abk_player/core/network/xor_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final codec = XorCodec.abk();

  test('key is the confirmed 15-byte constant', () {
    expect(codec.key, Uint8List.fromList('r+3e>@y](7wEEM['.codeUnits));
    expect(codec.key.length, 15);
  });

  test('empty input round-trips and encodes to empty', () {
    expect(codec.encodeString('').length, 0);
    expect(codec.decodeToString(codec.encodeString('')), '');
  });

  test('ASCII payload round-trips', () {
    const s = 'abcdefghijklmnopqrstuvwxyz0123456789';
    expect(codec.decodeToString(codec.encodeString(s)), s);
  });

  test('JSON payload round-trips', () {
    final s = jsonEncode({
      'code': '00000000',
      'user': 'U',
      'pass': 'P',
      'mode': 'login',
      'group': 0,
    });
    expect(codec.decodeToString(codec.encodeString(s)), s);
  });

  test('long payload (> key length, forces wraparound) round-trips', () {
    final s = 'A' * 5000;
    final enc = codec.encodeString(s);
    // Byte i must equal 'A' XOR key[i % 15].
    for (var i = 0; i < 47; i++) {
      expect(enc[i], 'A'.codeUnitAt(0) ^ codec.key[i % codec.key.length]);
    }
    expect(codec.decodeToString(enc), s);
  });

  test('unicode payload round-trips (utf8 bytes)', () {
    const s = 'قناة الرياضة • Sport 🎬';
    expect(codec.decodeToString(codec.encodeString(s)), s);
  });

  test('xor is symmetric (involution)', () {
    final data = Uint8List.fromList(List<int>.generate(300, (i) => i % 256));
    expect(codec.xor(codec.xor(data)), data);
  });

  test('empty key is rejected', () {
    expect(() => XorCodec(Uint8List(0)), throwsArgumentError);
  });
}
