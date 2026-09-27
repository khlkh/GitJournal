/*
 * SPDX-FileCopyrightText: 2021 Vishesh Handa <me@vhanda.in>
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import 'package:flutter/material.dart';
import 'package:gitjournal/l10n.dart';
import 'package:gitjournal/logger/logger.dart';
import 'package:gitjournal/repository_manager.dart';
import 'package:gitjournal/settings/settings_git_remote.dart';
import 'package:gitjournal/utils/debug_nav_observer.dart';
import 'package:gitjournal/widgets/app_drawer.dart';
import 'package:provider/provider.dart';

import 'home_screen.dart';

class ErrorScreen extends StatelessWidget {
  static const routePath = '/error';

  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var repoManager = context.watch<RepositoryManager>();
    // assert(repoManager.currentRepo == null);

    if (repoManager.currentRepo != null) {
      Log.e("ErrorScreen shown but repo is NOT null! "
          "repoId=${repoManager.currentRepo?.id}, "
          "currentRoute=${ModalRoute.of(context)?.settings.name}");
      return Scaffold(
        appBar: AppBar(
          title: const Text('Debug: ErrorScreen (should not be visible)'),
          backgroundColor: Colors.red,
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "This screen should never be visible",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Route: ${ModalRoute.of(context)?.settings.name ?? "(unknown)"}',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
              Text(
                'Repo: ${repoManager.currentRepo?.id ?? "null"}',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
              Text(
                'CurrentId: ${repoManager.currentId}',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Navigation log:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: DebugNavigatorObserver.instance.logEntries.length,
                  itemBuilder: (context, index) {
                    return SelectableText(
                      DebugNavigatorObserver.instance.logEntries[index],
                      style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: Colors.green),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    var children = <Widget>[
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          context.loc.screensErrorMessage,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          repoManager.currentRepoError.toString(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
      const SizedBox(height: 64),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          child: Text(context.loc.drawerAddRepo),
          onPressed: () async {
            try {
              await repoManager.addRepoAndSwitch();
            } catch (ex) {
              Navigator.pop(context);
              Navigator.of(context).pushNamedAndRemoveUntil(
                ErrorScreen.routePath,
                (r) => true,
              );
            }

            Navigator.pop(context);
            Navigator.of(context).pushNamedAndRemoveUntil(
              HomeScreen.routePath,
              (r) => true,
            );
          },
        ),
      ),
      RedButton(
        text: context.loc.settingsDeleteRepo,
        onPressed: () async {
          var ok = await showDialog(
            context: context,
            builder: (_) => IrreversibleActionConfirmationDialog(
              title: context.loc.settingsDeleteRepo,
              subtitle: context.loc.settingsGitRemoteChangeHostSubtitle,
            ),
          );
          if (ok == null) {
            return;
          }

          var repoManager = context.read<RepositoryManager>();
          await repoManager.deleteCurrent();

          Navigator.popUntil(context, (route) => route.isFirst);
        },
      ),
    ];

    return Scaffold(
      drawer: AppDrawer(),
      appBar: AppBar(
        title: Text(context.loc.screensErrorTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: children,
        ),
      ),
    );
  }
}

//
// * Add a file bug buttton
// * Add text on how to recover the data
//
