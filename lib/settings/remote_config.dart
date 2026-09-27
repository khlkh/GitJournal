/*
 * SPDX-FileCopyrightText: 2019-2021 Vishesh Handa <me@vhanda.in>
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import 'dart:convert';

/// Remote 配置数据模型
/// 每个 remote 可以有独立的认证配置
class RemoteConfig {
  final String name;
  final String url;
  final String? sshPublicKey;
  final String? sshPrivateKey;
  final String? sshPassword;
  final bool isDefault;

  const RemoteConfig({
    required this.name,
    required this.url,
    this.sshPublicKey,
    this.sshPrivateKey,
    this.sshPassword,
    this.isDefault = false,
  });

  /// 是否使用 SSH 认证
  bool get usesSSH => url.startsWith('git@') || url.startsWith('ssh://');

  /// 是否有自定义 SSH 密钥
  bool get hasCustomSSH => sshPrivateKey != null && sshPrivateKey!.isNotEmpty;

  RemoteConfig copyWith({
    String? name,
    String? url,
    String? sshPublicKey,
    String? sshPrivateKey,
    String? sshPassword,
    bool? isDefault,
  }) {
    return RemoteConfig(
      name: name ?? this.name,
      url: url ?? this.url,
      sshPublicKey: sshPublicKey ?? this.sshPublicKey,
      sshPrivateKey: sshPrivateKey ?? this.sshPrivateKey,
      sshPassword: sshPassword ?? this.sshPassword,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'sshPublicKey': sshPublicKey,
      'sshPrivateKey': sshPrivateKey,
      'sshPassword': sshPassword,
      'isDefault': isDefault,
    };
  }

  factory RemoteConfig.fromJson(Map<String, dynamic> json) {
    return RemoteConfig(
      name: json['name'] as String,
      url: json['url'] as String,
      sshPublicKey: json['sshPublicKey'] as String?,
      sshPrivateKey: json['sshPrivateKey'] as String?,
      sshPassword: json['sshPassword'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory RemoteConfig.fromJsonString(String jsonString) {
    return RemoteConfig.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RemoteConfig &&
        other.name == name &&
        other.url == url &&
        other.sshPublicKey == sshPublicKey &&
        other.sshPrivateKey == sshPrivateKey &&
        other.sshPassword == sshPassword &&
        other.isDefault == isDefault;
  }

  @override
  int get hashCode {
    return name.hashCode ^
        url.hashCode ^
        sshPublicKey.hashCode ^
        sshPrivateKey.hashCode ^
        sshPassword.hashCode ^
        isDefault.hashCode;
  }

  @override
  String toString() {
    return 'RemoteConfig(name: $name, url: $url, isDefault: $isDefault)';
  }
}

/// Remote 配置列表管理
class RemoteConfigList {
  final List<RemoteConfig> remotes;

  const RemoteConfigList({this.remotes = const []});

  /// 获取默认 remote
  RemoteConfig? get defaultRemote {
    final defaults = remotes.where((r) => r.isDefault);
    return defaults.isNotEmpty ? defaults.first : (remotes.isNotEmpty ? remotes.first : null);
  }

  /// 根据 name 获取 remote
  RemoteConfig? getByName(String name) {
    try {
      return remotes.firstWhere((r) => r.name == name);
    } catch (_) {
      return null;
    }
  }

  /// 添加 remote
  RemoteConfigList add(RemoteConfig remote) {
    final newRemotes = List<RemoteConfig>.from(remotes);
    // 如果是第一个或标记为默认，确保只有一个默认
    if (remote.isDefault || newRemotes.isEmpty) {
      newRemotes.removeWhere((r) => r.isDefault);
      newRemotes.add(remote.copyWith(isDefault: true));
    } else {
      newRemotes.add(remote);
    }
    return RemoteConfigList(remotes: newRemotes);
  }

  /// 更新 remote
  RemoteConfigList update(RemoteConfig remote) {
    final newRemotes = List<RemoteConfig>.from(remotes);
    final index = newRemotes.indexWhere((r) => r.name == remote.name);
    if (index != -1) {
      // 如果更新为默认，移除其他默认标记
      if (remote.isDefault) {
        newRemotes.removeWhere((r) => r.isDefault);
      }
      newRemotes[index] = remote;
    }
    return RemoteConfigList(remotes: newRemotes);
  }

  /// 删除 remote
  RemoteConfigList remove(String name) {
    final newRemotes = List<RemoteConfig>.from(remotes);
    final hadDefault = newRemotes.where((r) => r.name == name).any((r) => r.isDefault);
    newRemotes.removeWhere((r) => r.name == name);
    // 如果删除的是默认，设置第一个为默认
    if (hadDefault && newRemotes.isNotEmpty && !newRemotes.any((r) => r.isDefault)) {
      newRemotes[0] = newRemotes[0].copyWith(isDefault: true);
    }
    return RemoteConfigList(remotes: newRemotes);
  }

  /// 设置默认 remote
  RemoteConfigList setDefault(String name) {
    final newRemotes = List<RemoteConfig>.from(remotes);
    for (int i = 0; i < newRemotes.length; i++) {
      newRemotes[i] = newRemotes[i].copyWith(isDefault: newRemotes[i].name == name);
    }
    return RemoteConfigList(remotes: newRemotes);
  }

  Map<String, dynamic> toJson() {
    return {
      'remotes': remotes.map((r) => r.toJson()).toList(),
    };
  }

  factory RemoteConfigList.fromJson(Map<String, dynamic> json) {
    return RemoteConfigList(
      remotes: (json['remotes'] as List<dynamic>?)
              ?.map((r) => RemoteConfig.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory RemoteConfigList.fromJsonString(String jsonString) {
    return RemoteConfigList.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  static RemoteConfigList empty() => const RemoteConfigList();
}
