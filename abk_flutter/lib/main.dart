import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap.dart';
import 'ui/app_root.dart';

Future<void> main() async {
  final container = await bootstrap();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AbkAppRoot(),
    ),
  );
}
