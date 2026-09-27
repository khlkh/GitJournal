/*
 * SPDX-FileCopyrightText: 2019-2021 Vishesh Handa <me@vhanda.in>
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gitjournal/l10n.dart';
import 'package:gitjournal/logger/logger.dart';
import 'package:gitjournal/repository_manager.dart';
import 'package:gitjournal/screens/home_screen.dart';
import 'package:gitjournal/widgets/home_widget_service.dart';
import 'package:provider/provider.dart';

class SettingsReposScreen extends StatefulWidget {
  static const routePath = '/settings/repos';

  const SettingsReposScreen({super.key});

  @override
  State<SettingsReposScreen> createState() => _SettingsReposScreenState();
}

class _SettingsReposScreenState extends State<SettingsReposScreen> {
  @override
  Widget build(BuildContext context) {
    var repoManager = context.watch<RepositoryManager>();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.settingsReposTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: context.loc.settingsReposAddRepo,
            onPressed: () => _addRepo(context),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        itemCount: repoManager.repoIds.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          var repoId = repoManager.repoIds[index];
          return _RepoListTile(
            repoId: repoId,
            isCurrent: repoManager.currentId == repoId,
            onTap: () => _switchToRepo(context, repoId),
            onRename: () => _renameRepo(context, repoId),
            onDelete: () => _deleteRepo(context, repoId),
            onAddToHome: () => _addToHomeScreen(context, repoId),
          );
        },
      ),
    );
  }

  Future<void> _addRepo(BuildContext context) async {
    var nameController = TextEditingController();
    var formKey = GlobalKey<FormState>();

    var result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.loc.settingsReposAddRepo),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.loc.settingsReposRepoName,
              hintText: context.loc.settingsReposRepoNameHint,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return context.loc.settingsReposRepoNameError;
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, true);
              }
            },
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );

    if (result == true) {
      var name = nameController.text.trim();
      try {
        var repoManager = context.read<RepositoryManager>();
        var newId = await repoManager.addRepoAndSwitch();
        if (name.isNotEmpty && name != 'repo_$newId') {
          await repoManager.renameRepo(newId, name);
        }
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            HomeScreen.routePath,
            (r) => r.isFirst,
          );
        }
      } catch (e) {
        Log.e("Failed to add repo", ex: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.loc.settingsReposAddError)),
          );
        }
      }
    }
  }

  Future<void> _switchToRepo(BuildContext context, String repoId) async {
    var repoManager = context.read<RepositoryManager>();
    if (repoManager.currentId == repoId) return;

    try {
      await repoManager.setCurrentRepo(repoId);
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          HomeScreen.routePath,
          (r) => r.isFirst,
        );
      }
    } catch (e) {
      Log.e("Failed to switch repo", ex: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.settingsReposSwitchError)),
        );
      }
    }
  }

  Future<void> _renameRepo(BuildContext context, String repoId) async {
    var repoManager = context.read<RepositoryManager>();
    var currentName = repoManager.repoFolderName(repoId);
    var nameController = TextEditingController(text: currentName);
    var formKey = GlobalKey<FormState>();

    var result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.loc.settingsReposRenameRepo),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.loc.settingsReposRepoName,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return context.loc.settingsReposRepoNameError;
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, true);
              }
            },
            child: Text(MaterialLocalizations.of(context).saveButtonLabel),
          ),
        ],
      ),
    );

    if (result == true) {
      var newName = nameController.text.trim();
      try {
        await repoManager.renameRepo(repoId, newName);
      } catch (e) {
        Log.e("Failed to rename repo", ex: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.loc.settingsReposRenameError)),
          );
        }
      }
    }
  }

  Future<void> _deleteRepo(BuildContext context, String repoId) async {
    var repoManager = context.read<RepositoryManager>();
    var repoName = repoManager.repoFolderName(repoId);
    var isCurrent = repoManager.currentId == repoId;

    var confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.loc.settingsReposDeleteRepo),
        content: Text(
          isCurrent
              ? context.loc.settingsReposDeleteCurrentWarning(repoName)
              : context.loc.settingsReposDeleteWarning(repoName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.loc.settingsReposDelete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await repoManager.deleteRepo(repoId);
        if (mounted && isCurrent) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            HomeScreen.routePath,
            (r) => r.isFirst,
          );
        }
      } catch (e) {
        Log.e("Failed to delete repo", ex: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.loc.settingsReposDeleteError)),
          );
        }
      }
    }
  }

  Future<void> _addToHomeScreen(BuildContext context, String repoId) async {
    var repoManager = context.read<RepositoryManager>();
    var repoName = repoManager.repoFolderName(repoId);

    try {
      final success = await HomeWidgetService.requestPinRepoWidget(
        repoId: repoId,
        repoName: repoName,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.loc.settingsReposWidgetAdded(repoName)),
          ),
        );
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.loc.settingsReposWidgetPinFailed),
          ),
        );
      }
    } catch (e) {
      Log.e("Failed to add widget to home screen", ex: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.loc.settingsReposWidgetError),
          ),
        );
      }
    }
  }
}

class _RepoListTile extends StatelessWidget {
  final String repoId;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onAddToHome;

  const _RepoListTile({
    required this.repoId,
    required this.isCurrent,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    required this.onAddToHome,
  });

  @override
  Widget build(BuildContext context) {
    var repoManager = context.watch<RepositoryManager>();
    var repoName = repoManager.repoFolderName(repoId);
    var theme = Theme.of(context);

    return ListTile(
      leading: FaIcon(
        FontAwesomeIcons.book,
        color: isCurrent ? theme.colorScheme.secondary : null,
      ),
      title: Text(
        repoName,
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          color: isCurrent ? theme.colorScheme.secondary : null,
        ),
      ),
      subtitle: isCurrent
          ? Text(context.loc.settingsReposCurrentBadge)
          : null,
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'rename':
              onRename();
              break;
            case 'delete':
              onDelete();
              break;
            case 'add_to_home':
              onAddToHome();
              break;
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'add_to_home',
            child: Row(
              children: [
                const Icon(Icons.home, size: 20),
                const SizedBox(width: 8),
                Text(context.loc.settingsReposAddToHome),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'rename',
            child: Row(
              children: [
                const Icon(Icons.edit, size: 20),
                const SizedBox(width: 8),
                Text(context.loc.settingsReposRenameRepo),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            enabled: repoManager.repoIds.length > 1,
            child: Row(
              children: [
                Icon(Icons.delete,
                    size: 20,
                    color: repoManager.repoIds.length > 1
                        ? theme.colorScheme.error
                        : theme.disabledColor),
                const SizedBox(width: 8),
                Text(
                  context.loc.settingsReposDeleteRepo,
                  style: TextStyle(
                    color: repoManager.repoIds.length > 1
                        ? theme.colorScheme.error
                        : theme.disabledColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
