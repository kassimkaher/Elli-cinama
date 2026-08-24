import 'package:abk_player/core/logging/redaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('redacts registered secrets and their url-encoded form', () {
    final r = Redactor();
    r.registerSecret('s3cr3t/pw');
    expect(r.redact('value is s3cr3t/pw here'), 'value is *** here');
    expect(r.redact('enc ${Uri.encodeComponent('s3cr3t/pw')} x'), 'enc *** x');
  });

  test('empty/null secrets are ignored', () {
    final r = Redactor();
    r.registerSecret('');
    r.registerSecret(null);
    expect(r.redact('unchanged'), 'unchanged');
  });

  test('redactUrl masks credential query params', () {
    final r = Redactor();
    final out = r.redactUrl(
        'http://h:80/player_api.php?username=alice&password=pw&action=get_short_epg');
    expect(out, contains('username=***'));
    expect(out, contains('password=***'));
    expect(out, contains('action=get_short_epg'));
  });
}
