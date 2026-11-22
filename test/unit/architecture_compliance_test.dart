import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Architectural Layering & Compliance Tests (Requirement R4)', () {
    final projectRoot = Directory.current.path.endsWith('metapos')
        ? Directory.current
        : Directory('${Directory.current.path}/dev/Codes/metamorphosis/metapos');

    final presentationDir = Directory('${projectRoot.path}/lib/presentation');
    final modelsDir = Directory('${projectRoot.path}/lib/data/models');

    test('lib/presentation and lib/data/models directories must exist', () {
      expect(presentationDir.existsSync(), isTrue,
          reason: 'Presentation directory must exist at ${presentationDir.path}');
      expect(modelsDir.existsSync(), isTrue,
          reason: 'Models directory must exist at ${modelsDir.path}');
    });

    test('UI Layer (lib/presentation/) contains ZERO direct network or database imports', () {
      final forbiddenPresentationImports = [
        'sqflite',
        'dio',
        'http/http.dart',
        'package:http/',
        'dart:io',
        'data/remote/',
        'data/local/',
      ];

      final presentationFiles = presentationDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      expect(presentationFiles.isNotEmpty, isTrue,
          reason: 'Must find Dart files in lib/presentation/');
      expect(presentationFiles.length, greaterThanOrEqualTo(7),
          reason: 'Should scan at least 7 presentation files (screens and widgets)');

      final violations = <String>[];

      for (final file in presentationFiles) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('import ') || line.startsWith('export ')) {
            for (final forbidden in forbiddenPresentationImports) {
              if (line.contains(forbidden)) {
                violations.add(
                  '${file.path}:${i + 1} imports forbidden "$forbidden": $line',
                );
              }
            }
          }
        }
      }

      expect(violations, isEmpty,
          reason: 'Found forbidden imports in presentation layer violating R4:\n${violations.join('\n')}');
    });

    test('Domain Models (lib/data/models/) contain ZERO UI framework imports (material/widgets)', () {
      final forbiddenModelImports = [
        'package:flutter/material.dart',
        'package:flutter/widgets.dart',
        'package:flutter/cupertino.dart',
      ];

      final modelFiles = modelsDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      expect(modelFiles.isNotEmpty, isTrue,
          reason: 'Must find Dart files in lib/data/models/');
      expect(modelFiles.length, greaterThanOrEqualTo(5),
          reason: 'Should scan at least 5 domain model files');

      final violations = <String>[];

      for (final file in modelFiles) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('import ') || line.startsWith('export ')) {
            for (final forbidden in forbiddenModelImports) {
              if (line.contains(forbidden)) {
                violations.add(
                  '${file.path}:${i + 1} imports forbidden UI package "$forbidden": $line',
                );
              }
            }
          }
        }
      }

      expect(violations, isEmpty,
          reason: 'Domain models must remain UI-agnostic and clean from Flutter widgets:\n${violations.join('\n')}');
    });

    test('Data Layer Separation: Repositories isolate data sources from Presentation Layer', () {
      // Presentation files should route through providers or repositories, never directly instantiating raw DB/HTTP
      final presentationFiles = presentationDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      final forbiddenKeywords = [
        'openDatabase',
        'DatabaseHelper.instance',
        'sqfliteFfiInit',
        'HttpClient(',
      ];

      final violations = <String>[];

      for (final file in presentationFiles) {
        final content = file.readAsStringSync();
        for (final keyword in forbiddenKeywords) {
          if (content.contains(keyword)) {
            violations.add('${file.path} contains forbidden direct data call "$keyword"');
          }
        }
      }

      expect(violations, isEmpty,
          reason: 'Presentation widgets must not contain direct database or HTTP connections:\n${violations.join('\n')}');
    });
  });
}
