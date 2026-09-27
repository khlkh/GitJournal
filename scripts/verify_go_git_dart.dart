#!/usr/bin/env dart
// SPDX-FileCopyrightText: 2024 GitJournal Contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

// This script verifies that go_git_dart dependency is correctly configured
// to use the forked version with malformed mode fixes.
// Uses only Dart core libraries (no external dependencies).

import 'dart:io';

void main() {
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln('ERROR: pubspec.yaml not found');
    exit(1);
  }

  final content = pubspecFile.readAsStringSync();
  
  // Simple YAML parsing for go_git_dart dependency
  // Look for go_git_dart: followed by git: configuration
  final lines = content.split('\n');
  bool inGoGitDart = false;
  bool inGit = false;
  String? url;
  
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();
    
    // Check if we're entering go_git_dart section
    if (RegExp(r'^go_git_dart:\s*$').hasMatch(trimmed)) {
      inGoGitDart = true;
      continue;
    }
    
    // Check if we're leaving go_git_dart section (new top-level key)
    if (inGoGitDart && !line.startsWith(' ') && !line.startsWith('\t') && trimmed.isNotEmpty) {
      inGoGitDart = false;
      inGit = false;
      continue;
    }
    
    if (inGoGitDart) {
      // Check for git: key
      if (RegExp(r'^git:\s*$').hasMatch(trimmed)) {
        inGit = true;
        continue;
      }
      
      // Check for inline git: url
      final inlineMatch = RegExp(r'^git:\s*(\S+)').firstMatch(trimmed);
      if (inlineMatch != null) {
        url = inlineMatch.group(1);
        break;
      }
      
      // Check for url: in git section
      if (inGit && trimmed.startsWith('url:')) {
        url = trimmed.substring(4).trim();
        break;
      }
      
      // Check if we're leaving git section
      if (inGit && !line.startsWith('    ') && !line.startsWith('\t\t') && trimmed.isNotEmpty && !trimmed.startsWith('git:')) {
        inGit = false;
      }
    }
  }
  
  if (url == null) {
    stderr.writeln('ERROR: go_git_dart dependency not found or not configured as git dependency');
    exit(1);
  }

  // Verify it's using the forked version
  if (!url.contains('weijia/go_git_dart')) {
    stderr.writeln('WARNING: go_git_dart is not using the forked version with malformed mode fix');
    stderr.writeln('Current URL: $url');
    stderr.writeln('Expected: https://github.com/weijia/go_git_dart.git');
    stderr.writeln('');
    stderr.writeln('Please update pubspec.yaml to use the forked version:');
    stderr.writeln('  go_git_dart:');
    stderr.writeln('    git:');
    stderr.writeln('      url: https://github.com/weijia/go_git_dart.git');
    stderr.writeln('      ref: main');
    exit(1);
  }

  stdout.writeln('✓ go_git_dart is correctly configured to use forked version');
  stdout.writeln('  URL: $url');
  exit(0);
}
