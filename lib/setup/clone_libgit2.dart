/*
 * SPDX-FileCopyrightText: 2019-2021 Vishesh Handa <me@vhanda.in>
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import 'dart:convert';
import 'package:universal_io/io.dart';

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:function_types/function_types.dart';
import 'package:git_setup/git_transfer_progress.dart';
import 'package:gitjournal/logger/logger.dart';
import 'package:go_git_dart/go_git_dart_async.dart';

import 'clone.dart';

Future<void> cloneRemote({
  required String repoPath,
  required String cloneUrl,
  required String remoteName,
  required String sshPublicKey,
  required String sshPrivateKey,
  required String sshPassword,
  required String authorName,
  required String authorEmail,
  required String proxyUrl,
  required Func1<GitTransferProgress, void> progressUpdate,
}) {
  return cloneRemotePluggable(
    repoPath: repoPath,
    cloneUrl: cloneUrl,
    remoteName: remoteName,
    sshPublicKey: sshPublicKey,
    sshPrivateKey: sshPrivateKey,
    sshPassword: sshPassword,
    authorName: authorName,
    authorEmail: authorEmail,
    proxyUrl: proxyUrl,
    progressUpdate: progressUpdate,
    gitCloneFn: _clone,
    gitFetchFn: _fetch,
    defaultBranchFn: _defaultBranch,
  );
}

Future<void> _clone({
  required String cloneUrl,
  required String repoPath,
  required String sshPublicKey,
  required String sshPrivateKey,
  required String sshPassword,
  required String statusFile,
  required String proxyUrl,
}) async {
  Log.i("=== go_git_dart Clone Start ===");
  Log.i("Clone URL: $cloneUrl");
  Log.i("Repo Path: $repoPath");
  if (proxyUrl.isNotEmpty) {
    Log.w("Proxy configured but go_git_dart does not support proxy yet "
        "(TODO: port proxy support from xtccc fork)");
  }

  // Do NOT pre-create .git/config here!
  // go-git's PlainClone will create the repo from scratch.
  // Pre-creating an incomplete .git directory causes go-git to treat it as
  // a bare repo and fail with "Work tree not available in a bare repo".
  // The malformed mode fallback is handled entirely in the Go layer.

  var bindings = GitBindingsAsync();
  try {
    await bindings.clone(
      cloneUrl,
      repoPath,
      utf8.encode(sshPrivateKey),
      sshPassword,
    );
    Log.i("=== go_git_dart Clone Success ===");
  } catch (ex, st) {
    Log.e("=== go_git_dart Clone FAILED ===", ex: ex, stacktrace: st);
    Log.e("Clone Error Details: ${ex.toString()}");
    Log.e("Clone URL was: $cloneUrl");
    Log.e("Repo Path was: $repoPath");

    // Check if this is a malformed mode error
    var errStr = ex.toString().toLowerCase();
    if (errStr.contains('malformed') || errStr.contains('mode')) {
      Log.e("DETECTED: Malformed mode error - this means go_git_dart fallback failed");
      Log.e("The go_git_dart binary may not have been updated with the fix");
    }

    rethrow;
  }

  // Post-clone: Ensure core.fileMode=false is set
  try {
    var configFile = File('$repoPath/.git/config');
    if (configFile.existsSync()) {
      var lines = await configFile.readAsLines();
      var modified = false;
      var newLines = <String>[];
      var hasCoreSection = false;
      var hasFileMode = false;

      for (var line in lines) {
        if (line.trim() == '[core]') {
          hasCoreSection = true;
        }
        if (line.contains('fileMode') || line.contains('filemode')) {
          hasFileMode = true;
          if (line.contains('true')) {
            newLines.add('\tfileMode = false');
            modified = true;
            continue;
          }
        }
        newLines.add(line);
      }

      if (hasCoreSection && !hasFileMode) {
        // Insert fileMode = false after [core] section
        var result = <String>[];
        for (var line in newLines) {
          result.add(line);
          if (line.trim() == '[core]') {
            result.add('\tfileMode = false');
            modified = true;
          }
        }
        newLines = result;
      }

      if (modified) {
        await configFile.writeAsString(newLines.join('\n'));
        Log.i("Set core.fileMode=false in .git/config");
      } else {
        Log.i("core.fileMode already correctly configured");
      }
    }
  } catch (ex) {
    Log.w("Failed to set core.fileMode=false (non-fatal)", ex: ex);
  }
}

Future<void> _fetch(
  String repoPath,
  String remoteName,
  String sshPublicKey,
  String sshPrivateKey,
  String sshPassword,
  String statusFile,
  String proxyUrl,
) async {
  var bindings = GitBindingsAsync();
  await bindings.fetch(
      remoteName, repoPath, utf8.encode(sshPrivateKey), sshPassword);
}

Future<String> _defaultBranch(
  String repoPath,
  String remoteName,
  String sshPublicKey,
  String sshPrivateKey,
  String sshPassword,
  String proxyUrl,
) async {
  try {
    var repo = GitRepository.load(repoPath);
    var remote = repo.config.remote(remoteName);
    if (remote == null) {
      throw Exception("Remote '$remoteName' not found");
    }

    var bindings = GitBindingsAsync();
    var branch = await bindings.defaultBranch(
        remote.url, utf8.encode(sshPrivateKey), sshPassword);

    Log.i("Got default branch: $branch");
    if (branch.isNotEmpty) {
      return branch;
    }
  } catch (ex) {
    Log.w("Could not fetch git Default Branch", ex: ex);
  }

  var repo = GitRepository.load(repoPath);
  var remoteBranch = repo.guessRemoteHead(remoteName);
  repo.close();
  if (remoteBranch == null || remoteBranch is! SymbolicReference) {
    Log.e("Failed to guess RemoteHead. Returning `main`");
    return "main";
  }
  var branch = remoteBranch.target.branchName()!;
  Log.d("Guessed default branch as $branch");
  return branch;
}
