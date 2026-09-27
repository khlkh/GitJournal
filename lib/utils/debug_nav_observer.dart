/*
 * SPDX-FileCopyrightText: 2019-2021 Vishesh Handa <me@vhanda.in>
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import 'package:flutter/material.dart';
import 'package:gitjournal/logger/logger.dart';

/// A [NavigatorObserver] that logs every navigation event and keeps
/// an in-memory ring buffer of recent events so they can be shown
/// on-screen in a debug overlay.
class DebugNavigatorObserver extends NavigatorObserver {
  static final DebugNavigatorObserver instance = DebugNavigatorObserver._();

  final List<String> _log = [];
  static const int _maxEntries = 50;

  DebugNavigatorObserver._();

  List<String> get logEntries => List.unmodifiable(_log);

  void _add(String msg) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    final entry = '[$ts] $msg';
    _log.insert(0, entry);
    if (_log.length > _maxEntries) _log.removeLast();
    Log.i('NAV: $msg');
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name ?? '(unnamed)';
    final prev = previousRoute?.settings.name ?? '(none)';
    _add('PUSH "$name" from "$prev"');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name ?? '(unnamed)';
    final prev = previousRoute?.settings.name ?? '(none)';
    _add('POP "$name" back to "$prev"');
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name ?? '(unnamed)';
    final prev = previousRoute?.settings.name ?? '(none)';
    _add('REMOVE "$name" prev "$prev"');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final newName = newRoute?.settings.name ?? '(unnamed)';
    final oldName = oldRoute?.settings.name ?? '(none)';
    _add('REPLACE "$oldName" -> "$newName"');
  }

  /// Called from [onGenerateRoute] to log every route request, even
  /// ones that don't result in a push/pop event.
  void logRouteRequest(String routeName) {
    _add('GENROUTE "$routeName"');
  }
}
