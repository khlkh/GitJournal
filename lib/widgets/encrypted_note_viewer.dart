/*
 * SPDX-FileCopyrightText: 2024 GitJournal Contributors
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import 'package:flutter/material.dart';
import 'package:gitjournal/core/note.dart';
import 'package:gitjournal/core/note_storage.dart';
import 'package:gitjournal/logger/logger.dart';
import 'package:gitjournal/widgets/encrypted_password_dialog.dart';

/// A dialog for temporarily viewing an encrypted note's content.
///
/// This is read-only - the note remains encrypted on disk.
/// Users can choose to enter edit mode from here if they want to modify.
/// When entering edit mode, the password is passed along so the user
/// doesn't need to enter it again.
class EncryptedNoteViewer extends StatefulWidget {
  final Note note;

  const EncryptedNoteViewer({
    super.key,
    required this.note,
  });

  /// Shows the encrypted note viewer.
  /// Returns the encryption password if user wants to edit, or null if cancelled.
  static Future<String?> show(
    BuildContext context,
    Note note,
  ) async {
    return await showDialog<String>(
      context: context,
      builder: (context) => EncryptedNoteViewer(note: note),
    );
  }

  @override
  State<EncryptedNoteViewer> createState() => _EncryptedNoteViewerState();
}

class _EncryptedNoteViewerState extends State<EncryptedNoteViewer> {
  bool _isDecrypting = false;
  String? _decryptedContent;
  String? _errorMessage;
  String? _password; // cached for passing to editor
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptPassword();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _promptPassword() async {
    final password = await EncryptedPasswordDialog.showDecrypt(context);
    if (password == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isDecrypting = true;
      _errorMessage = null;
    });

    try {
      var decryptedNote =
          await NoteStorage.decryptNote(widget.note, password);
      if (mounted) {
        setState(() {
          _isDecrypting = false;
          _decryptedContent = decryptedNote.body;
          _password = password;
        });
      }
    } catch (e, st) {
      Log.e("Failed to decrypt note for viewing", ex: e, stacktrace: st);
      if (mounted) {
        setState(() {
          _isDecrypting = false;
          _errorMessage = 'Decryption failed: $e';
        });
        // Retry
        Future.delayed(const Duration(milliseconds: 500), _promptPassword);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.lock, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.note.title ?? 'Encrypted Note',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: _buildContent(),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (_decryptedContent != null)
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(_password),
            icon: const Icon(Icons.edit),
            label: const Text('Edit'),
          ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isDecrypting) {
      return const SizedBox(
        width: 200,
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return SizedBox(
        width: 300,
        child: Text(
          _errorMessage!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    if (_decryptedContent != null) {
      return SizedBox(
        width: 500,
        height: 400,
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SelectableText(
                _decryptedContent!,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
