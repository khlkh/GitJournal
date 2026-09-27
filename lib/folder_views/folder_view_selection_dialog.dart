/*
 * SPDX-FileCopyrightText: 2023 Vishesh Handa <me@vhanda.in>
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import 'package:flutter/material.dart';
import 'package:gitjournal/folder_views/common_types.dart';
import 'package:gitjournal/l10n.dart';

class FolderViewSelectionDialog extends StatelessWidget {
  final FolderViewType viewType;
  final void Function(FolderViewType?) onViewChange;

  const FolderViewSelectionDialog({
    super.key,
    required this.viewType,
    required this.onViewChange,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.loc.widgetsFolderViewViewsSelect),
      content: RadioGroup<FolderViewType>(
        groupValue: viewType,
        onChanged: onViewChange,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            RadioListTile<FolderViewType>(
              title: Text(context.loc.widgetsFolderViewViewsStandard),
              value: FolderViewType.Standard,
            ),
            RadioListTile<FolderViewType>(
              title: Text(context.loc.widgetsFolderViewViewsJournal),
              value: FolderViewType.Journal,
            ),
            RadioListTile<FolderViewType>(
              title: Text(context.loc.widgetsFolderViewViewsGrid),
              value: FolderViewType.Grid,
            ),
            RadioListTile<FolderViewType>(
              title: Text(context.loc.widgetsFolderViewViewsCard),
              value: FolderViewType.Card,
            ),
          ],
        ),
      ),
    );
  }
}
