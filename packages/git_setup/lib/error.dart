/*
 * SPDX-FileCopyrightText: 2019-2021 Vishesh Handa <me@vhanda.in>
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gitjournal/l10n.dart';

class GitHostSetupErrorPage extends StatelessWidget {
  final String errorMessage;

  const GitHostSetupErrorPage(this.errorMessage);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            context.loc.setupFail,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 8.0),
        // Use SelectableText so users can long-press to copy the error
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: SelectableText(
                errorMessage,
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12.0),
        // Copy button for easy error sharing
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: errorMessage));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error copied to clipboard'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          icon: Icon(Icons.copy, size: 16),
          label: Text('Copy Error'),
        ),
      ],
    );
  }
}
