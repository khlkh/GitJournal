#!/usr/bin/env dart
// SPDX-FileCopyrightText: 2024 GitJournal Contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

// This script verifies that the go_git_dart dependency is correctly
// configured to use the version with malformed mode + detached-HEAD fixes.
// Uses only Dart core libraries (no external dependencies).

import 'dart:io';

void main() {
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln('ERROR: pubspec.yaml not found');
    exit(1);
  }

  final content = pubspecFile.readAsStringSync();

  // Vendored path dependency: go_git_dart -> path: packages/go_git_dart
  final pathMatch = RegExp(
    r'^  go_git_dart:\s*\n\s*path:\s*packages/go_git_dart\s*$',
    multiLine: true,
  ).firstMatch(content);

  if (pathMatch != null) {
    final gitGo = File('packages/go_git_dart/src/internal/git/git.go');
    if (!gitGo.existsSync()) {
      stderr.writeln('ERROR: vendored packages/go_git_dart is missing src/internal/git/git.go');
      exit(1);
    }
    final source = gitGo.readAsStringSync();
    if (!source.contains('normalizeFileMode') || !source.contains('NewSymbolicReference')) {
      stderr.writeln('ERROR: vendored go_git_dart is missing the malformed-mode + detached-HEAD fixes');
      exit(1);
    }
    stdout.writeln('✓ go_git_dart is vendored at packages/go_git_dart with the malformed-mode + detached-HEAD fixes');
    exit(0);
  }

  // Git dependency: go_git_dart -> git: url: .../weijia/go_git_dart.git
  final urlMatch = RegExp(
    r'^  go_git_dart:\s*\n(?:.*\n)*?\s*url:\s*(\S+)',
    multiLine: true,
  ).firstMatch(content);

  if (urlMatch != null) {
    final url = urlMatch.group(1)!;
    if (!url.contains('weijia/go_git_dart')) {
      stderr.writeln('WARNING: go_git_dart is not using the forked version with malformed mode fix');
      stderr.writeln('Current URL: $url');
      stderr.writeln('Expected: https://github.com/weijia/go_git_dart.git');
      exit(1);
    }
    stdout.writeln('✓ go_git_dart is correctly configured to use forked version');
    stdout.writeln('  URL: $url');
    exit(0);
  }

  stderr.writeln('ERROR: go_git_dart dependency not found in pubspec.yaml');
  exit(1);
}
