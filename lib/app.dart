/*
 * SPDX-FileCopyrightText: 2019-2021 Vishesh Handa <me@vhanda.in>
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gitjournal/analytics/analytics.dart';
import 'package:gitjournal/analytics/route_observer.dart';
import 'package:gitjournal/app_router.dart';
import 'package:gitjournal/change_notifiers.dart';
import 'package:gitjournal/core/folder/notes_folder_config.dart';
import 'package:gitjournal/core/link.dart';
import 'package:gitjournal/core/views/note_links_view.dart';
import 'package:gitjournal/error_reporting.dart';
import 'package:gitjournal/iap/iap.dart';
import 'package:gitjournal/l10n.dart';
import 'package:gitjournal/logger/logger.dart';
import 'package:gitjournal/repository_manager.dart';
import 'package:gitjournal/screens/error_screen.dart';
import 'package:gitjournal/screens/home_screen.dart';
import 'package:gitjournal/settings/app_config.dart';
import 'package:gitjournal/settings/settings.dart';
import 'package:gitjournal/settings/storage_config.dart';
import 'package:gitjournal/themes.dart';
import 'package:gitjournal/utils/debug_nav_observer.dart';
import 'package:gitjournal/utils/debug_overlay.dart';
import 'package:gitjournal/widgets/error_display.dart';
import 'package:gitjournal/widgets/home_widget_service.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart' show Directory, Platform;

class JournalApp extends StatefulWidget {
  static Future<void> main(SharedPreferences pref) async {
    await Log.init();

    Log.i("--------------------------------");
    Log.i("--------------------------------");
    Log.i("--------------------------------");
    Log.i("--------- App Launched ---------");
    Log.i("--------------------------------");
    Log.i("--------------------------------");
    Log.i("--------------------------------");

    var appConfig = AppConfig.instance;
    Log.i("AppConfig", props: appConfig.toMap());

    _enableAnalyticsIfPossible(appConfig, pref);

    final gitBaseDirectory = (await getApplicationDocumentsDirectory()).path;
    final cacheDir = (await getApplicationSupportDirectory()).path;

    Hive.init(cacheDir);
    Hive.registerAdapter(LinkAdapter());
    Hive.registerAdapter(LinksListAdapter());

    var repoManager = RepositoryManager(
      gitBaseDir: gitBaseDirectory,
      cacheDir: cacheDir,
      pref: pref,
    );

    // Ignore the error, the router will show an error screen
    await repoManager.buildActiveRepository();

    GitJournalInAppPurchases.confirmProPurchaseBoot();

    runApp(
      GitJournalChangeNotifiers(
        repoManager: repoManager,
        appConfig: appConfig,
        pref: pref,
        child: JournalApp(repoManager: repoManager),
      ),
    );
  }

  // TODO: All this logic should go inside the analytics package
  static Future<void> _enableAnalyticsIfPossible(
    AppConfig appConfig,
    SharedPreferences pref,
  ) async {
    var supportDir = await getApplicationSupportDirectory();
    var analyticsStorage = p.join(supportDir.path, 'analytics');
    await Directory(analyticsStorage).create(recursive: true);

    var analytics = await Analytics.init(
      pref: pref,
      analyticsCallback: captureErrorBreadcrumb,
      storagePath: analyticsStorage,
    );

    analytics.setUserProperty(
      name: 'proMode',
      value: appConfig.proMode.toString(),
    );
  }

  final RepositoryManager repoManager;

  const JournalApp({super.key, required this.repoManager});

  @override
  JournalAppState createState() => JournalAppState();
}

class JournalAppState extends State<JournalApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  String? _pendingShortcut;
  String? _pendingRepoId;

  StreamSubscription? _intentDataStreamSubscription;
  StreamSubscription? _widgetClickSubscription;
  var _sharedText = "";
  var _sharedImages = <String>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    const quickActions = QuickActions();
    quickActions.initialize((String shortcutType) {
      Log.i("Quick Action Open: $shortcutType");
      if (_navigatorKey.currentState == null) {
        Log.i("Quick Action delegating for after build");
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _afterBuild(context));
        setState(() {
          _pendingShortcut = shortcutType;
        });
        return;
      }
      _navigatorKey.currentState!
          .pushNamed(AppRoute.NewNotePrefix + shortcutType);

      quickActions.setShortcutItems(<ShortcutItem>[
        ShortcutItem(
          type: 'Markdown',
          localizedTitle: context.loc.actionsNewNote,
          icon: "ic_markdown",
        ),
        ShortcutItem(
          type: 'Checklist',
          localizedTitle: context.loc.actionsNewChecklist,
          icon: "ic_tasks",
        ),
        ShortcutItem(
          type: 'Journal',
          localizedTitle: context.loc.actionsNewJournal,
          icon: "ic_book",
        ),
      ]);
    });

    _initShareSubscriptions();
    _initWidgetHandling();
  }

  void _afterBuild(BuildContext context) {
    if (_pendingShortcut != null) {
      var routeName = AppRoute.NewNotePrefix + _pendingShortcut!;
      _navigatorKey.currentState!.pushNamed(routeName);
      _pendingShortcut = null;
    }

    if (_pendingRepoId != null) {
      _switchToRepo(_pendingRepoId!);
      _pendingRepoId = null;
    }
  }

  void _handleShare(Duration _) {
    var noText = _sharedText.isEmpty;
    var noImages = _sharedImages.isEmpty;
    if (noText && noImages) {
      return;
    }

    var folderConfig = context.read<NotesFolderConfig>();
    var editor = folderConfig.defaultEditor.toInternalString();
    _navigatorKey.currentState!.pushNamed(AppRoute.NewNotePrefix + editor);
  }

  @visibleForTesting
  void handleSharedMedia(Iterable<SharedMediaFile> media) {
    _sharedImages = [];
    _sharedText = "";

    // if (value.startsWith('gitjournal-identity://')) return;

    for (var m in media) {
      switch (m.type) {
        case SharedMediaType.image:
          Log.d("Received Image Share $m");
          _sharedImages.add(m.path);
          break;
        case SharedMediaType.video:
          Log.d("Received Video Share $m");
          Log.d("Video sharing is not supported");
          break;
        case SharedMediaType.url:
          Log.d("Received URL Share $m");
          _sharedText =
              _sharedText.isEmpty ? m.path : "$_sharedText\n${m.path}";
          break;
        case SharedMediaType.text:
          Log.d("Received Text Share $m");
          _sharedText =
              _sharedText.isEmpty ? m.path : "$_sharedText\n${m.path}";
          break;
        case SharedMediaType.file:
          Log.d("Received File Share $m");
          Log.d("File sharing is not supported");
          break;
      }
      Log.d("Received Media Share $m");
    }
    WidgetsBinding.instance.addPostFrameCallback(_handleShare);
  }

  void _initShareSubscriptions() {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    // For sharing text and images coming from outside the app while the app is in the memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedMediaFile> value) {
      Log.d("Received Media Share $value");
      handleSharedMedia(value);
    }, onError: (err) {
      Log.e("getIntentDataStream error: $err");
    });

    // For sharing text and images coming from outside the app while the app is closed
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> value) {
      Log.d("Received MediaFile Share with App (media): $value");

      handleSharedMedia(value);
    });
  }

  void _initWidgetHandling() {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    HomeWidgetService.init();
    Log.i("Widget: _initWidgetHandling called");

    // Check if app was launched from a widget
    HomeWidgetService.getInitialWidgetRepoId().then((repoId) {
      Log.i("Widget: getInitialWidgetRepoId returned: $repoId");
      if (repoId != null && repoId.isNotEmpty) {
        Log.i("Widget: app launched from widget, repoId=$repoId, setting _pendingRepoId");
        _pendingRepoId = repoId;
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _afterBuild(context));
      } else {
        Log.i("Widget: app NOT launched from widget (repoId is null/empty)");
      }
    }).catchError((e) {
      Log.e("Widget: getInitialWidgetRepoId error", ex: e);
    });

    // Listen for widget clicks while app is running
    _widgetClickSubscription = HomeWidgetService.widgetRepoIdStream.listen((repoId) {
      Log.i("Widget: widgetRepoIdStream received repoId: $repoId");
      _switchToRepo(repoId);
    });
    Log.i("Widget: _initWidgetHandling done, stream subscription set up");
  }

  Future<void> _switchToRepo(String repoId) async {
    var repoManager = context.read<RepositoryManager>();
    if (!repoManager.repoIds.contains(repoId)) {
      Log.e("Widget: repo not found: $repoId (available: ${repoManager.repoIds})");
      return;
    }

    if (repoManager.currentId == repoId) {
      Log.i("Widget: already on repo: $repoId");
      return;
    }

    Log.i("Widget: switching to repo $repoId from ${repoManager.currentId}");
    try {
      await repoManager.setCurrentRepo(repoId);
      Log.i("Widget: successfully switched to repo $repoId");
    } catch (e, st) {
      Log.e("Widget: failed to switch to repo $repoId", ex: e, stacktrace: st);
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    _widgetClickSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    Log.i("AppLifecycle: $state");

    // Widget clicks while the app is running are handled by
    // widgetRepoIdStream (set up in _initWidgetHandling).
    // We do NOT call getInitialWidgetRepoId() here because on Android
    // the launch intent persists across resumes, which would cause
    // _switchToRepo → buildActiveRepository → _repo = null → grey screen
    // on every app resume.
  }

  @override
  Widget build(BuildContext context) {
    try {
      return _buildApp(context);
    } catch (e, st) {
      Log.e("JournalApp build error", ex: e, stacktrace: st);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ErrorDisplay(error: e, stackTrace: st),
      );
    }
  }

  Widget _buildApp(BuildContext context) {
    var repo = widget.repoManager.currentRepo;
    Log.d("JournalApp.build: repo=${repo?.id}, repoError=${widget.repoManager.currentRepoError}");

    // Repository.load can be quite slow, especially because of the 'git commit'
    // on booting
    // FIXME: Make Settings not depend on Repository
    late Settings settings;
    try {
      settings = context.watch<Settings>();
    } catch (_) {
      // This can happen during initial app boot before any repo is loaded,
      // or after a repo deletion (clearExisting). Show a loading indicator
      // instead of a blank screen.
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    // FIXME: Settings can be null in this case!

    AppRouter? router;
    var themeMode = ThemeMode.system;

    if (repo != null) {
      var appConfig = context.watch<AppConfig>();
      var storageConfig = context.watch<StorageConfig>();

      router = AppRouter(
        settings: settings,
        appConfig: appConfig,
        storageConfig: storageConfig,
      );

      themeMode = settings.theme.toThemeMode();
    }
    var initialRoute =
        router != null ? router.initialRoute() : ErrorScreen.routePath;
    Log.i("JournalApp: initialRoute=$initialRoute, repo=${repo?.id}, router=${router != null}");

    /*

    Also use -
    * https://github.com/bernaferrari/RandomColorScheme
    * https://pub.dev/packages/color_blindness

    const FlexSchemeData customFlexScheme = FlexSchemeData(
      name: 'Toledo purple',
      description: 'Purple theme created from custom defined colors.',
      light: FlexSchemeColor(
        primary: Color(0xFF66bb6a),
        primaryVariant: Color(0xFF338a3e),
        secondary: Color(0xff6d4c41),
        secondaryVariant: Color(0xFF338a3e),
      ),
      dark: FlexSchemeColor(
        primary: Color(0xff212121),
        primaryVariant: Color(0xffc8635f),
        secondary: Color(0xff689f38),
        secondaryVariant: Color(0xff00be00),
      ),
    );
    */

    var locale = Locale(settings.locale);
    var lSplit = settings.locale.split("_");
    if (lSplit.length >= 3) {
      locale = Locale.fromSubtags(
        languageCode: lSplit[0],
        scriptCode: lSplit[1],
        countryCode: lSplit[2],
      );
    } else if (lSplit.length == 2) {
      // A two-part tag like "zh_Hans" is a script, while "pt_BR" is a country.
      const knownScripts = {
        'Hans', 'Hant', 'Latn', 'Cyrl', 'Arab', 'Deva', 'Grek', 'Hira',
        'Kana', 'Hang', 'Thai',
      };
      if (knownScripts.contains(lSplit[1])) {
        locale = Locale.fromSubtags(
          languageCode: lSplit[0],
          scriptCode: lSplit[1],
        );
      } else {
        locale = Locale(lSplit[0], lSplit[1]);
      }
    }

    return MaterialApp(
      key: const ValueKey("App"),
      navigatorKey: _navigatorKey,
      title: 'GitJournal',

      localizationsDelegates: gitJournalLocalizationDelegates,
      supportedLocales: gitJournalSupportedLocales,
      locale: locale,

      theme: Themes.fromName(settings.lightTheme),
      darkTheme: Themes.fromName(settings.darkTheme),
      themeMode: themeMode,
      navigatorObservers: <NavigatorObserver>[
        AnalyticsRouteObserver(),
        SentryNavigatorObserver(),
        DebugNavigatorObserver.instance,
      ],
      initialRoute: initialRoute,
      debugShowCheckedModeBanner: false,
      //debugShowMaterialGrid: true,
      onGenerateRoute: (rs) {
        var routeName = rs.name ?? "";

        // Log EVERY route request at the very start
        DebugNavigatorObserver.instance.logRouteRequest(routeName);
        Log.i("onGenerateRoute: routeName='$routeName' (len=${routeName.length}, "
            "bytes=${routeName.codeUnits.take(40).toList()})");
        Log.i("  router=${router != null}, repo=${repo?.id}, "
            "matchesRepoPrefix=${routeName.startsWith(AppRoute.RepoPrefix)}, "
            "matchesDeepLink=${routeName.startsWith(AppRoute.RepoDeepLinkPrefix)}");

        // Intercept deep-link routes pushed by Flutter's engine when
        // the app is launched from a home-screen widget.
        //
        // The home_widget package creates a PendingIntent with
        // Uri.parse("gitjournal://repo/{repoId}").  Flutter's engine
        // extracts the *path* from the URI and pushes it as a route.
        // So the actual route name can be any of:
        //   "/repo/{repoId}"          (path from gitjournal://repo/{repoId})
        //   "gitjournal://repo/{repoId}" (full URI in some Flutter versions)
        //   "/{repoId}"               (path-only form, the most common)
        //
        // We detect all three forms and also check if the path segment
        // matches a known repo ID.  The actual repo switching is handled
        // by HomeWidgetService.widgetRepoIdStream, so we return a
        // transparent route that removes itself immediately.
        var isWidgetDeepLink = false;
        var deepLinkRepoId = <String>[];

        if (routeName.startsWith(AppRoute.RepoDeepLinkPrefix)) {
          // "gitjournal://repo/{repoId}"
          isWidgetDeepLink = true;
          deepLinkRepoId.add(routeName.substring(AppRoute.RepoDeepLinkPrefix.length));
        } else if (routeName.startsWith(AppRoute.RepoPrefix)) {
          // "/repo/{repoId}"
          isWidgetDeepLink = true;
          deepLinkRepoId.add(routeName.substring(AppRoute.RepoPrefix.length));
        } else if (routeName.length > 1 && routeName.startsWith('/')) {
          // "/{repoId}" — check if the segment after '/' is a known repo ID
          var segment = routeName.substring(1);
          if (widget.repoManager.repoIds.contains(segment)) {
            isWidgetDeepLink = true;
            deepLinkRepoId.add(segment);
          }
        }

        if (isWidgetDeepLink) {
          var repoId = deepLinkRepoId.first;
          Log.i("  -> INTERCEPTED as widget deep-link (repoId=$repoId), "
              "returning _AutoRemoveRoute with repo switch");
          return PageRouteBuilder(
            settings: rs,
            opaque: false,
            pageBuilder: (_, __, ___) => _AutoRemoveRoute(
              repoId: repoId,
              repoManager: widget.repoManager,
            ),
            transitionsBuilder: (_, __, ___, child) => child,
          );
        }

        if (router == null || repo == null) {
          Log.w("  -> router or repo is NULL, returning ErrorScreen. "
              "router=$router, repo=${repo?.id}");
          return MaterialPageRoute(
            settings: rs,
            builder: (context) => const ErrorScreen(),
          );
        }

        var r = router.generateRoute(rs, repo, _sharedText, _sharedImages, () {
          _sharedText = "";
          _sharedImages = [];
        });

        Log.i("  -> generated route: ${r.runtimeType}");
        return r;
      },
        // Wrap every route with a visible debug overlay so we can see
        // navigation events on-screen during development. Only shown in
        // debug builds.
        builder: (context, child) {
          final content = child ?? const SizedBox.shrink();
          if (!kDebugMode) return content;
          return DebugOverlay(child: content);
        },
    );
  }
}

/// A transparent widget that removes its own route from the Navigator
/// in the next frame and switches to the specified repo.  Used to
/// "absorb" deep-link routes pushed by Flutter's engine when the app
/// is launched from a home-screen widget.  The actual repo switching
/// happens here as a fallback in case [HomeWidgetService.widgetRepoIdStream]
/// doesn't fire or fires too late.
class _AutoRemoveRoute extends StatefulWidget {
  final String repoId;
  final RepositoryManager repoManager;

  const _AutoRemoveRoute({
    required this.repoId,
    required this.repoManager,
  });

  @override
  State<_AutoRemoveRoute> createState() => _AutoRemoveRouteState();
}

class _AutoRemoveRouteState extends State<_AutoRemoveRoute> {
  @override
  void initState() {
    super.initState();
    Log.i("_AutoRemoveRoute: initState, repoId=${widget.repoId}");

    // Switch repo immediately (non-blocking for the UI)
    _switchRepo();

    // Replace this transparent route with the home screen so the navigator
    // stack is never left empty (which would show a black screen).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(HomeScreen.routePath);
      Log.i("_AutoRemoveRoute: replaced itself with HomeScreen route");
    });
  }

  Future<void> _switchRepo() async {
    var repoId = widget.repoId;
    var repoManager = widget.repoManager;

    if (!repoManager.repoIds.contains(repoId)) {
      Log.e("_AutoRemoveRoute: repo not found: $repoId "
          "(available: ${repoManager.repoIds})");
      return;
    }

    if (repoManager.currentId == repoId) {
      Log.i("_AutoRemoveRoute: already on repo $repoId, no switch needed");
      return;
    }

    Log.i("_AutoRemoveRoute: switching from ${repoManager.currentId} to $repoId");
    try {
      await repoManager.setCurrentRepo(repoId);
      Log.i("_AutoRemoveRoute: successfully switched to $repoId");
    } catch (e, st) {
      Log.e("_AutoRemoveRoute: failed to switch to $repoId", ex: e, stacktrace: st);
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
