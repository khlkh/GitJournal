/*
 * SPDX-FileCopyrightText: 2019-2021 Vishesh Handa <me@vhanda.in>
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import 'package:flutter/material.dart';
import 'package:gitjournal/l10n.dart';

class NoteBodyEditor extends StatelessWidget {
  final TextEditingController textController;
  final bool autofocus;
  final bool readOnly;
  final Function onChanged;

  const NoteBodyEditor({
    super.key,
    required this.textController,
    required this.autofocus,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return TextField(
      autofocus: autofocus,
      readOnly: readOnly,
      keyboardType: TextInputType.multiline,
      maxLines: null,
      style: textStyle(context),
      decoration: InputDecoration(
        hintText: context.loc.editorsCommonDefaultBodyHint,
        border: InputBorder.none,
        fillColor: theme.scaffoldBackgroundColor,
        hoverColor: theme.scaffoldBackgroundColor,
        contentPadding: const EdgeInsets.all(0.0),
        isDense: true,
      ),
      controller: textController,
      textCapitalization: TextCapitalization.sentences,
      scrollPadding: const EdgeInsets.all(0.0),
      onChanged: (_) => onChanged(),
    );
  }

  static TextStyle textStyle(BuildContext context) {
    var theme = Theme.of(context);
    return theme.textTheme.titleMedium!;
  }
}
