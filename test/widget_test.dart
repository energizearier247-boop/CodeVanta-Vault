
import 'package:flutter_test/flutter_test.dart';
import 'package:codevanta_vault/main.dart';

void main() {
  test('CodeVanta Vault app initializes correctly', () {
    const app = CodeVantaVaultApp(initialDarkMode: true);

    expect(app, isA<CodeVantaVaultApp>());
    expect(app.initialDarkMode, isTrue);
  });
}

