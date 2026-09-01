import 'dart:convert';
import 'dart:io';

import 'package:planext4u_observability/planext4u_observability.dart';

void main(List<String> arguments) {
  final input = _argument(arguments, '--input=');
  final stageName = _argument(arguments, '--stage=') ?? 'internal';
  if (input == null) {
    stderr.writeln(
      'Usage: dart run tool/evaluate_release_health.dart '
      '--input=<health.json> [--stage=<stage>]',
    );
    exitCode = 64;
    return;
  }

  try {
    final stage = ReleaseStage.values.byName(stageName);
    final decoded = jsonDecode(File(input).readAsStringSync());
    final snapshot = ReleaseHealthSnapshot.fromJson(decoded);
    const policy = ReleaseGuardrailPolicy();
    final evaluation = policy.evaluate(snapshot);
    final output = <String, Object?>{
      'stage': stage.name,
      'decision': evaluation.decision.name,
      'next_stage': evaluation.decision == ReleaseDecision.advance
          ? stage.next?.name
          : null,
      'reasons': evaluation.reasons,
    };
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(output));
    exitCode = switch (evaluation.decision) {
      ReleaseDecision.advance => 0,
      ReleaseDecision.hold => 2,
      ReleaseDecision.rollback => 3,
    };
  } on FileSystemException catch (error) {
    stderr.writeln('Unable to read release health: ${error.message}');
    exitCode = 66;
  } on FormatException catch (error) {
    stderr.writeln('Invalid release health: ${error.message}');
    exitCode = 65;
  } on ArgumentError {
    stderr.writeln('Unknown release stage: $stageName');
    exitCode = 64;
  }
}

String? _argument(List<String> arguments, String prefix) {
  final matches = arguments.where((value) => value.startsWith(prefix));
  if (matches.isEmpty) return null;
  final value = matches.last.substring(prefix.length).trim();
  return value.isEmpty ? null : value;
}
