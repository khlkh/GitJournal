/*
 * SPDX-FileCopyrightText: 2019-2021 Vishesh Handa <me@vhanda.in>
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import 'dart:async';

import 'package:gitjournal/logger/logger.dart';
import 'package:home_widget/home_widget.dart';
import 'package:universal_io/io.dart';

/// Service for managing home screen widgets.
///
/// Supports multiple widgets, each bound to a different git repo.
/// The binding is done via a "pending" slot: before requesting a pin,
/// Dart writes the repo data as pending; when Android calls onUpdate
/// for the new widget, the Kotlin provider claims the pending data and
/// stores it per-widget-ID.
class HomeWidgetService {
  // ── Pending keys (written before pin, claimed by the new widget) ──
  static const String _keyPendingRepoId = 'pending_repo_id';
  static const String _keyPendingTitle = 'pending_title';
  static const String _keyPendingSubtitle = 'pending_subtitle';

  // ── Per-repo keys (shared by all widgets of the same repo) ──
  static String _repoTitleKey(String repoId) => 'repo_${repoId}_title';
  static String _repoSubtitleKey(String repoId) => 'repo_${repoId}_subtitle';

  /// Fully-qualified Android provider class name (works in debug & release).
  static const String _qualifiedAndroidProviderName =
      'io.gitjournal.gitjournal.RepoWidgetProvider';

  // ─────────────────────────────────────────────────────────────
  //  Deep-link handling
  // ─────────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    // No special registration needed – HomeWidget.widgetClicked
    // stream is set up by the package.
  }

  /// Returns the repo ID if the app was launched from a widget tap.
  static Future<String?> getInitialWidgetRepoId() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return null;
    }
    try {
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      Log.i("Widget: initiallyLaunchedFromHomeWidget returned URI: '$uri'");
      Log.i("  uri type: ${uri?.runtimeType}, "
          "scheme: ${uri?.scheme}, host: ${uri?.host}, "
          "pathSegments: ${uri?.pathSegments}");
      if (uri != null &&
          uri.scheme == 'gitjournal' &&
          uri.host == 'repo' &&
          uri.pathSegments.isNotEmpty) {
        Log.i("  -> extracted repoId: ${uri.pathSegments.first}");
        return uri.pathSegments.first;
      }
      Log.i("  -> URI did not match gitjournal://repo/{repoId} pattern, "
          "returning null");
      return null;
    } catch (e, st) {
      Log.e("Widget: Failed to get initial widget data", ex: e, stacktrace: st);
      return null;
    }
  }

  /// Stream of repo IDs when the user taps a widget while the app
  /// is already running.
  static Stream<String> get widgetRepoIdStream {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return const Stream.empty();
    }
    return HomeWidget.widgetClicked
        .handleError((e, st) {
          Log.e("widgetClicked stream error", ex: e, stacktrace: st);
        })
        .where((uri) =>
            uri != null &&
            uri.scheme == 'gitjournal' &&
            uri.host == 'repo' &&
            uri.pathSegments.isNotEmpty)
        .map((uri) => uri!.pathSegments.first);
  }

  // ─────────────────────────────────────────────────────────────
  //  Widget management
  // ─────────────────────────────────────────────────────────────

  /// Update the display data for a repo. This refreshes ALL widgets
  /// on the home screen – each widget reads its own bound repoId and
  /// then looks up the title/subtitle from the per-repo keys.
  static Future<void> updateRepoWidget({
    required String repoId,
    required String title,
    String? subtitle,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    try {
      // Write per-repo data (shared by all widgets of this repo)
      await HomeWidget.saveWidgetData<String>(
        _repoTitleKey(repoId), title,
      );
      await HomeWidget.saveWidgetData<String>(
        _repoSubtitleKey(repoId), subtitle ?? 'Tap to open',
      );

      // Trigger onUpdate on all widgets – each will read its own data
      await HomeWidget.updateWidget(
        qualifiedAndroidName: _qualifiedAndroidProviderName,
      );
      Log.i("Updated repo widget data for: $repoId");
    } catch (e) {
      Log.e("Failed to update widget", ex: e);
    }
  }

  /// Request to pin a new widget for [repoId] on the home screen.
  ///
  /// The repo data is saved as "pending". When Android calls onUpdate
  /// for the newly placed widget, the Kotlin provider claims the
  /// pending data and binds it to that widget's ID. This allows
  /// multiple widgets, each pointing to a different repo.
  static Future<bool> requestPinRepoWidget({
    required String repoId,
    required String repoName,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }
    try {
      // Save as pending – will be claimed by the next new widget
      await HomeWidget.saveWidgetData<String>(_keyPendingRepoId, repoId);
      await HomeWidget.saveWidgetData<String>(_keyPendingTitle, repoName);
      await HomeWidget.saveWidgetData<String>(
        _keyPendingSubtitle, 'Tap to open',
      );

      // Also write per-repo data so existing widgets of this repo
      // (if any) get the latest title/subtitle
      await HomeWidget.saveWidgetData<String>(
        _repoTitleKey(repoId), repoName,
      );
      await HomeWidget.saveWidgetData<String>(
        _repoSubtitleKey(repoId), 'Tap to open',
      );

      // Check if pinning is supported (Android < API 26)
      var supported = true;
      try {
        supported = await HomeWidget.isRequestPinWidgetSupported() ?? true;
      } catch (_) {}
      if (!supported) {
        Log.w("requestPinWidget not supported on this device");
        return false;
      }

      // Request to pin – Android shows the pin dialog; on confirm,
      // onUpdate fires and the new widget claims the pending data.
      await HomeWidget.requestPinWidget(
        qualifiedAndroidName: _qualifiedAndroidProviderName,
      );

      Log.i("Requested pin widget for repo: $repoId");
      return true;
    } catch (e) {
      Log.e("Failed to request pin widget", ex: e);
      return false;
    }
  }
}
