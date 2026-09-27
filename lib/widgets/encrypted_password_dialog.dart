/*
 * SPDX-FileCopyrightText: 2024 GitJournal Contributors
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import 'package:flutter/material.dart';

/// Dialog for entering a password to encrypt or decrypt a note.
class EncryptedPasswordDialog extends StatefulWidget {
  final String title;
  final String confirmButtonText;
  final bool requireConfirmation;

  const EncryptedPasswordDialog({
    super.key,
    required this.title,
    required this.confirmButtonText,
    this.requireConfirmation = false,
  });

  /// Shows a dialog to enter a password for decryption.
  /// Returns the password string, or null if cancelled.
  static Future<String?> showDecrypt(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const EncryptedPasswordDialog(
        title: 'Enter Password',
        confirmButtonText: 'Decrypt',
        requireConfirmation: false,
      ),
    );
  }

  /// Shows a dialog to set a password for encryption.
  /// Returns the password string, or null if cancelled.
  static Future<String?> showEncrypt(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const EncryptedPasswordDialog(
        title: 'Set Encryption Password',
        confirmButtonText: 'Encrypt',
        requireConfirmation: true,
      ),
    );
  }

  @override
  State<EncryptedPasswordDialog> createState() =>
      _EncryptedPasswordDialogState();
}

class _EncryptedPasswordDialogState extends State<EncryptedPasswordDialog> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorText;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final password = _passwordController.text.trim();

    if (widget.requireConfirmation) {
      final confirm = _confirmController.text.trim();
      if (password != confirm) {
        setState(() {
          _errorText = 'Passwords do not match';
        });
        return;
      }
    }

    if (password.isEmpty) {
      setState(() {
        _errorText = 'Password cannot be empty';
      });
      return;
    }

    Navigator.of(context).pop(password);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _passwordController,
              autofocus: true,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                errorText: _errorText,
              ),
              onFieldSubmitted: (_) {
                if (!widget.requireConfirmation) {
                  _submit();
                }
              },
            ),
            if (widget.requireConfirmation) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirm = !_obscureConfirm;
                      });
                    },
                  ),
                ),
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(widget.confirmButtonText),
        ),
      ],
    );
  }
}
