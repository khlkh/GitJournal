/*
 * SPDX-FileCopyrightText: 2019-2021 Vishesh Handa <me@vhanda.in>
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A full-screen error display that shows the error message and stack trace
/// with selectable / copyable text. Used as a global ErrorWidget.builder
/// fallback so users can see and report errors instead of a grey screen.
///
/// This widget avoids depending on Theme.of(context) or ScaffoldMessenger
/// since those may not be available when the error occurs.
class ErrorDisplay extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;

  const ErrorDisplay({
    super.key,
    required this.error,
    required this.stackTrace,
  });

  @override
  Widget build(BuildContext context) {
    final errorText =
        'Error: $error\n\nStackTrace:\n${stackTrace ?? 'No stack trace'}';

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFF1A1A2E),
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: const [
                  Icon(Icons.error_outline, color: Colors.red, size: 28),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '应用出错了',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '请复制以下错误信息并反馈给开发者：',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      errorText,
                      style: const TextStyle(
                        color: Color(0xFFE94560),
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.4,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _CopyButton(text: errorText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  final String text;
  const _CopyButton({required this.text});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.copy, color: Colors.white),
      label: Text(
        _copied ? '已复制 ✓' : '复制错误信息',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          decoration: TextDecoration.none,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[600],
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: widget.text));
        if (mounted) {
          setState(() => _copied = true);
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _copied = false);
          });
        }
      },
    );
  }
}

/// Install the global error widget builder so any uncaught Flutter build
/// error shows the ErrorDisplay instead of a grey / red screen.
void installErrorDisplay() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return ErrorDisplay(
      error: details.exception,
      stackTrace: details.stack,
    );
  };
}
