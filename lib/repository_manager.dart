/*
 * SPDX-FileCopyrightText: 2019-2021 Vishesh Handa <me@vhanda.in>
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import 'package:flutter/material.dart';
import 'package:gitjournal/logger/logger.dart';
import 'package:gitjournal/repository.dart';
import 'package:gitjournal/settings/settings.dart';
import 'package:gitjournal/settings/storage_config.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart' as io;

class RepositoryManager with ChangeNotifier {
  var repoIds = <String>[];
  var currentId = DEFAULT_ID;

  GitJournalRepo? _repo;
  Object? _repoError;

  final String gitBaseDir;
  final String cacheDir;
  final SharedPreferences pref;

  RepositoryManager({
    required this.gitBaseDir,
    required this.cacheDir,
    required this.pref,
  }) {
    _load();
    Log.i("Repo Ids $repoIds");
    Log.i("Current Id $currentId");
  }

  GitJournalRepo? get currentRepo => _repo;
  Object? get currentRepoError => _repoError;

  Future<GitJournalRepo?> buildActiveRepository({
    bool loadFromCache = true,
    bool syncOnBoot = true,
    bool clearExisting = false,
  }) async {
    var repoCacheDir = p.join(cacheDir, currentId);

    // When clearExisting is true (e.g. after deleting a repo), null out
    // _repo immediately so the UI doesn't try to use deleted data.
    // Otherwise, keep the old repo visible while loading the new one –
    // this prevents a grey screen during repo switches from widgets.
    _repoError = null;
    if (clearExisting) {
      _repo = null;
      notifyListeners();
    }

    try {
      var newRepo = await GitJournalRepo.load(
        repoManager: this,
        gitBaseDir: gitBaseDir,
        cacheDir: repoCacheDir,
        pref: pref,
        id: currentId,
        loadFromCache: loadFromCache,
        syncOnBoot: syncOnBoot,
      );
      _repo = newRepo;
    } catch (ex, st) {
      Log.e("buildActiveRepo", ex: ex, stacktrace: st);
      _repoError = ex;
      if (clearExisting) {
        _repo = null;
      }
      notifyListeners();
      return null;
    }

    notifyListeners();
    return _repo!;
  }

  String repoFolderName(String id) {
    return pref.getString("${id}_$FOLDER_NAME_KEY") ?? "journal";
  }

  Future<String> addRepoAndSwitch() async {
    int i = repoIds.length;
    while (repoIds.contains(i.toString())) {
      i++;
    }

    var id = i.toString();
    repoIds.add(id);
    currentId = id;
    await _save();

    // Generate a default folder name!
    await pref.setString("${id}_$FOLDER_NAME_KEY", "repo_$id");
    Log.i("Creating new repo with id: $id and folder: repo_$id");

    await buildActiveRepository();
    return id;
  }

  Future<void> _save() async {
    await pref.setString("activeRepo", currentId);
    await pref.setStringList("gitRepos", repoIds);
  }

  void _load() {
    currentId = pref.getString("activeRepo") ?? DEFAULT_ID;
    repoIds = pref.getStringList("gitRepos") ?? [DEFAULT_ID];
  }

  Future<void> setCurrentRepo(String id) async {
    assert(repoIds.contains(id));
    currentId = id;
    await _save();

    Log.i("Switching to repo with id: $id");
    await buildActiveRepository();
  }

  Future<void> deleteCurrent() async {
    Log.i("Deleting repo: $currentId");

    var i = repoIds.indexOf(currentId);
    await _repo?.delete();
    repoIds.removeAt(i);

    if (repoIds.isEmpty) {
      await addRepoAndSwitch();
      return;
    }

    i = i.clamp(0, repoIds.length - 1);
    currentId = repoIds[i];

    await _save();
    await buildActiveRepository(clearExisting: true);
  }

  Future<void> renameRepo(String id, String newName) async {
    assert(repoIds.contains(id));
    if (newName.isEmpty) return;

    await pref.setString("${id}_$FOLDER_NAME_KEY", newName);
    Log.i("Renamed repo $id to $newName");

    notifyListeners();
  }

  Future<void> deleteRepo(String id) async {
    assert(repoIds.contains(id));
    Log.i("Deleting repo: $id");

    // If deleting current repo, switch to another one first
    if (currentId == id) {
      await deleteCurrent();
      return;
    }

    // Delete the repo data on disk
    var repoDir = p.join(gitBaseDir, repoFolderName(id));
    try {
      var dir = io.Directory(repoDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      Log.e("Failed to delete repo directory: $repoDir", ex: e);
    }

    // Clear shared preferences for this repo
    var keysToRemove = <String>[];
    for (var key in pref.getKeys()) {
      if (key.startsWith("${id}_")) {
        keysToRemove.add(key);
      }
    }
    for (var key in keysToRemove) {
      await pref.remove(key);
    }

    repoIds.remove(id);
    await _save();
    notifyListeners();
  }

  // Not sure when to call this!
  Future<void> cleanupInvalidRepos() async {
    var invalidIds = <String>[];
    for (var id in repoIds) {
      var exists = await GitJournalRepo.exists(
          gitBaseDir: gitBaseDir, pref: pref, id: id);
      if (!exists) {
        invalidIds.add(id);
      }
    }

    repoIds.removeWhere((id) => invalidIds.contains(id));
    notifyListeners();
    return _save();
  }
}
