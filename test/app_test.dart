import 'package:flutter_test/flutter_test.dart';
import 'package:resq/app/theme.dart';

void main() {
  test('theme honours the monochrome contract', () {
    final theme = ResqTheme.monochrome;

    expect(theme.scaffoldBackgroundColor, ResqTheme.black);
    expect(theme.colorScheme.onSurface, ResqTheme.white);
    expect(theme.textTheme.bodyMedium?.fontFamily, ResqTheme.fontFamily);
  });
}
