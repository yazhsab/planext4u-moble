import 'dart:convert';
import 'dart:io';

void main(List<String> arguments) {
  final check = arguments.contains('--check');
  final packageRoot = File.fromUri(Platform.script).parent.parent;
  final source = File('${packageRoot.path}/tokens/design_tokens.json');
  final output = File('${packageRoot.path}/lib/src/generated_tokens.dart');
  final document =
      jsonDecode(source.readAsStringSync()) as Map<String, dynamic>;
  final generated = _render(document);

  if (check) {
    if (!output.existsSync() || output.readAsStringSync() != generated) {
      stderr.writeln(
        'Generated design tokens are stale. Run '
        '`dart run packages/design_system/tool/generate_tokens.dart`.',
      );
      exitCode = 1;
      return;
    }
    stdout.writeln('Generated design tokens are current.');
    return;
  }

  output.writeAsStringSync(generated);
  stdout.writeln('Generated ${output.path}.');
}

String _render(Map<String, dynamic> document) {
  final output = StringBuffer()
    ..writeln('// Code generated from tokens/design_tokens.json; DO NOT EDIT.')
    ..writeln()
    ..writeln("import 'package:flutter/material.dart';")
    ..writeln()
    ..writeln('abstract final class Planext4uColors {');
  for (final entry in _map(document, 'colors').entries) {
    output.writeln('  static const ${entry.key} = Color(0xFF${entry.value});');
  }
  output
    ..writeln('}')
    ..writeln()
    ..writeln('abstract final class Planext4uSpacing {');
  for (final entry in _map(document, 'spacing').entries) {
    output.writeln('  static const ${entry.key} = ${entry.value}.0;');
  }
  output
    ..writeln('}')
    ..writeln()
    ..writeln('abstract final class Planext4uRadii {');
  for (final entry in _map(document, 'radii').entries) {
    output.writeln('  static const ${entry.key} = ${entry.value}.0;');
  }
  output
    ..writeln('}')
    ..writeln()
    ..writeln('abstract final class Planext4uMotion {');
  for (final entry in _map(document, 'motionMilliseconds').entries) {
    output.writeln(
      '  static const ${entry.key} = Duration(milliseconds: ${entry.value});',
    );
  }
  output
    ..writeln('}')
    ..writeln()
    ..writeln('abstract final class Planext4uBreakpoints {');
  for (final entry in _map(document, 'breakpoints').entries) {
    output.writeln('  static const ${entry.key} = ${entry.value}.0;');
  }
  output
    ..writeln('}')
    ..writeln()
    ..writeln('abstract final class Planext4uTypography {');
  for (final entry in _map(document, 'typography').entries) {
    output.writeln("  static const ${entry.key} = '${entry.value}';");
  }
  output.writeln('}');
  return output.toString();
}

Map<String, dynamic> _map(Map<String, dynamic> document, String key) =>
    document[key]! as Map<String, dynamic>;
