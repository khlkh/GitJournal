/*
 * SPDX-FileCopyrightText: 2019-2021 Vishesh Handa <me@vhanda.in>
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import 'package:flutter/material.dart';
import 'package:gitjournal/repository.dart';
import 'package:gitjournal/settings/remote_config.dart';

/// Remote 管理界面
class RemoteManagerScreen extends StatefulWidget {
  final GitJournalRepo repo;

  const RemoteManagerScreen({super.key, required this.repo});

  @override
  State<RemoteManagerScreen> createState() => _RemoteManagerScreenState();
}

class _RemoteManagerScreenState extends State<RemoteManagerScreen> {
  List<RemoteConfig> _remotes = [];
  bool _loading = true;
  String? _defaultRemoteName;

  @override
  void initState() {
    super.initState();
    _loadRemotes();
  }

  Future<void> _loadRemotes() async {
    setState(() => _loading = true);

    try {
      final gitRemotes = await widget.repo.remoteConfigs();
      final remoteConfigList = await _loadRemoteConfigList();

      // 合并 Git remote 配置和存储的认证信息
      final remotes = gitRemotes.map((gitRemote) {
        final stored = remoteConfigList.getByName(gitRemote.name);
        return RemoteConfig(
          name: gitRemote.name,
          url: gitRemote.url,
          sshPublicKey: stored?.sshPublicKey,
          sshPrivateKey: stored?.sshPrivateKey,
          sshPassword: stored?.sshPassword,
          isDefault: stored?.isDefault ?? gitRemote.name == 'origin',
        );
      }).toList();

      setState(() {
        _remotes = remotes;
        _defaultRemoteName = remoteConfigList.defaultRemote?.name ?? 
            (remotes.isNotEmpty ? remotes.first.name : null);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load remotes: $e')),
        );
      }
    }
  }

  Future<RemoteConfigList> _loadRemoteConfigList() async {
    // TODO: 从 SharedPreferences 加载
    return RemoteConfigList.empty();
  }

  Future<void> _saveRemoteConfigList(RemoteConfigList list) async {
    // TODO: 保存到 SharedPreferences
  }

  Future<void> _addRemote() async {
    final result = await showDialog<RemoteConfig>(
      context: context,
      builder: (context) => const AddRemoteDialog(),
    );

    if (result != null) {
      try {
        await widget.repo.addRemote(
          name: result.name,
          url: result.url,
        );

        final newList = RemoteConfigList(remotes: _remotes).add(result);
        await _saveRemoteConfigList(newList);

        await _loadRemotes();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added remote: ${result.name}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add remote: $e')),
          );
        }
      }
    }
  }

  Future<void> _editRemote(RemoteConfig remote) async {
    final result = await showDialog<RemoteConfig>(
      context: context,
      builder: (context) => AddRemoteDialog(existing: remote),
    );

    if (result != null) {
      try {
        await widget.repo.updateRemoteUrl(
          name: result.name,
          url: result.url,
        );

        final newList = RemoteConfigList(remotes: _remotes).update(result);
        await _saveRemoteConfigList(newList);

        await _loadRemotes();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Updated remote: ${result.name}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update remote: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteRemote(RemoteConfig remote) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Remote'),
        content: Text('Delete remote "${remote.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.repo.removeRemote(remote.name);

        final newList = RemoteConfigList(remotes: _remotes).remove(remote.name);
        await _saveRemoteConfigList(newList);

        await _loadRemotes();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted remote: ${remote.name}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete remote: $e')),
          );
        }
      }
    }
  }

  Future<void> _setDefaultRemote(RemoteConfig remote) async {
    final newList = RemoteConfigList(remotes: _remotes).setDefault(remote.name);
    await _saveRemoteConfigList(newList);
    await _loadRemotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Git Remotes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addRemote,
            tooltip: 'Add Remote',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _remotes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No remotes configured',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _addRemote,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Remote'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _remotes.length,
                  itemBuilder: (context, index) {
                    final remote = _remotes[index];
                    final isDefault = remote.name == _defaultRemoteName;

                    return ListTile(
                      leading: Icon(
                        isDefault ? Icons.star : Icons.cloud,
                        color: isDefault ? Colors.amber : null,
                      ),
                      title: Text(remote.name),
                      subtitle: Text(
                        remote.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              _editRemote(remote);
                              break;
                            case 'delete':
                              _deleteRemote(remote);
                              break;
                            case 'default':
                              _setDefaultRemote(remote);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit),
                              title: Text('Edit'),
                            ),
                          ),
                          if (!isDefault) ...[
                            const PopupMenuItem(
                              value: 'default',
                              child: ListTile(
                                leading: Icon(Icons.star),
                                title: Text('Set as Default'),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete),
                                title: Text('Delete'),
                              ),
                            ),
                          ],
                        ],
                      ),
                      onTap: () => _editRemote(remote),
                    );
                  },
                ),
    );
  }
}

/// 添加/编辑 Remote 对话框
class AddRemoteDialog extends StatefulWidget {
  final RemoteConfig? existing;

  const AddRemoteDialog({super.key, this.existing});

  @override
  State<AddRemoteDialog> createState() => _AddRemoteDialogState();
}

class _AddRemoteDialogState extends State<AddRemoteDialog> {
  late TextEditingController _nameController;
  late TextEditingController _urlController;
  late TextEditingController _sshPrivateKeyController;
  late TextEditingController _sshPasswordController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _urlController = TextEditingController(text: widget.existing?.url ?? '');
    _sshPrivateKeyController = TextEditingController(
      text: widget.existing?.sshPrivateKey ?? '',
    );
    _sshPasswordController = TextEditingController(
      text: widget.existing?.sshPassword ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _sshPrivateKeyController.dispose();
    _sshPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Remote' : 'Add Remote'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Remote Name',
                hintText: 'origin',
              ),
              enabled: !isEditing,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'git@github.com:user/repo.git',
              ),
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('SSH Configuration (Optional)'),
              children: [
                TextField(
                  controller: _sshPrivateKeyController,
                  decoration: const InputDecoration(
                    labelText: 'SSH Private Key',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _sshPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'SSH Password / Passphrase',
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameController.text.trim();
            final url = _urlController.text.trim();

            if (name.isEmpty || url.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Name and URL are required')),
              );
              return;
            }

            Navigator.pop(
              context,
              RemoteConfig(
                name: name,
                url: url,
                sshPrivateKey: _sshPrivateKeyController.text.isNotEmpty
                    ? _sshPrivateKeyController.text
                    : null,
                sshPassword: _sshPasswordController.text.isNotEmpty
                    ? _sshPasswordController.text
                    : null,
              ),
            );
          },
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
