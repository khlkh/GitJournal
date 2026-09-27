/*
 * SPDX-FileCopyrightText: 2019-2021 Vishesh Handa <me@vhanda.in>
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gitjournal/utils/debug_nav_observer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A floating, draggable debug overlay that shows recent navigation events.
///
/// Only meant to be shown in debug builds (the caller in app.dart guards it
/// with kDebugMode).
///
/// Features:
///  - Drag the panel anywhere on screen to avoid blocking UI controls.
///  - The position is persisted to SharedPreferences across app restarts.
///  - Tap the collapsed bar to expand the log panel.
///  - The panel can be dismissed entirely (hidden) via the close button.
///  - When hidden, a small floating bug icon lets you bring it back.
///  - Log entries are selectable and a "copy all" button copies everything.
class DebugOverlay extends StatefulWidget {
  final Widget child;

  const DebugOverlay({super.key, required this.child});

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  static const String _prefKeyX = 'debug_overlay_x';
  static const String _prefKeyY = 'debug_overlay_y';

  bool _expanded = true;
  bool _visible = true;

  // Position of the panel's top-left corner.
  Offset _position = Offset.zero;
  bool _positionLoaded = false;

  // Size of the panel (used for clamping during drag).
  final Size _collapsedSize = const Size(220, 36);
  final Size _expandedSize = const Size(320, 300);
  final Size _reopenSize = const Size(36, 36);

  @override
  void initState() {
    super.initState();
    _loadPosition();
    // Refresh periodically so new log entries show up
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadPosition() async {
    try {
      final pref = await SharedPreferences.getInstance();
      final x = pref.getDouble(_prefKeyX);
      final y = pref.getDouble(_prefKeyY);
      if (x != null && y != null) {
        if (mounted) {
          setState(() {
            _position = Offset(x, y);
            _positionLoaded = true;
          });
        }
        return;
      }
    } catch (_) {
      // ignore: fall through to default
    }
    if (mounted) {
      setState(() {
        _positionLoaded = true;
      });
    }
  }

  Future<void> _savePosition() async {
    try {
      final pref = await SharedPreferences.getInstance();
      await pref.setDouble(_prefKeyX, _position.dx);
      await pref.setDouble(_prefKeyY, _position.dy);
    } catch (_) {
      // ignore
    }
  }

  Offset _defaultPosition(Size size, Size screen) {
    // Default: top-right corner, below the status bar / AppBar.
    return Offset(
      (screen.width - size.width).clamp(0.0, double.infinity),
      56.0, // below typical AppBar height
    );
  }

  /// Clamp [pos] so the panel stays on screen.
  Offset _clamp(Offset pos, Size size, Size screen) {
    final dx = pos.dx.clamp(0.0, (screen.width - size.width).clamp(0.0, double.infinity));
    final dy = pos.dy.clamp(0.0, (screen.height - size.height).clamp(0.0, double.infinity));
    return Offset(dx, dy);
  }

  void _refresh() {
    setState(() {});
  }

  Future<void> _copyAll() async {
    final entries = DebugNavigatorObserver.instance.logEntries;
    await Clipboard.setData(ClipboardData(text: entries.join('\n')));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debug log copied to clipboard'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final size = _currentSize;

    // Use the default position until we've loaded the saved one.
    final pos = _positionLoaded ? _position : _defaultPosition(size, screen);
    final clamped = _clamp(pos, size, screen);

    return Stack(
      children: [
        widget.child,
        Positioned(
          left: clamped.dx,
          top: clamped.dy,
          child: _visible ? _buildPanel(size) : _buildReopenButton(),
        ),
      ],
    );
  }

  Size get _currentSize {
    if (!_visible) return _reopenSize;
    return _expanded ? _expandedSize : _collapsedSize;
  }

  Widget _buildDraggable({required Widget child}) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanUpdate: (details) {
        setState(() {
          final screen = MediaQuery.of(context).size;
          _position = _clamp(
            _position + details.delta,
            _currentSize,
            screen,
          );
        });
      },
      onPanEnd: (_) => _savePosition(),
      child: child,
    );
  }

  Widget _buildReopenButton() {
    return _buildDraggable(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _visible = true;
            _expanded = true;
          });
        },
        child: Container(
          width: _reopenSize.width,
          height: _reopenSize.height,
          decoration: BoxDecoration(
            color: Colors.black87.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange, width: 1),
          ),
          child: const Icon(Icons.bug_report, color: Colors.orange, size: 20),
        ),
      ),
    );
  }

  Widget _buildPanel(Size size) {
    return _buildDraggable(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _expanded = !_expanded;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size.width,
          height: size.height,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black87.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange, width: 1),
          ),
          child: _expanded ? _buildExpanded() : _buildCollapsed(),
        ),
      ),
    );
  }

  Widget _buildCollapsed() {
    final entries = DebugNavigatorObserver.instance.logEntries;
    return Row(
      children: [
        const Icon(Icons.bug_report, color: Colors.orange, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            entries.isEmpty ? 'Debug (tap to expand)' : entries.first,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              _visible = false;
            });
          },
          child: const Icon(Icons.close, color: Colors.white54, size: 16),
        ),
      ],
    );
  }

  Widget _buildExpanded() {
    final entries = DebugNavigatorObserver.instance.logEntries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.bug_report, color: Colors.orange, size: 16),
            const SizedBox(width: 6),
            const Text(
              'Debug Nav Log',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _copyAll,
              child: const Icon(Icons.copy_all, color: Colors.white54, size: 16),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _refresh,
              child: const Icon(Icons.refresh, color: Colors.white54, size: 16),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _expanded = false;
                });
              },
              child: const Icon(Icons.expand_less, color: Colors.white54, size: 16),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _visible = false;
                });
              },
              child: const Icon(Icons.close, color: Colors.white54, size: 16),
            ),
          ],
        ),
        const Divider(color: Colors.white24, height: 4),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: entries.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: SelectableText(
                  entries[index],
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 9,
                    fontFamily: 'monospace',
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
