/*
 * SPDX-FileCopyrightText: 2023 Vishesh Handa <me@vhanda.in>
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:gitjournal/folder_views/standard_view.dart';
import 'package:gitjournal/l10n.dart';
import 'package:gitjournal/settings/widgets/settings_header.dart';

class FolderViewConfigurationDialog extends StatelessWidget {
  final StandardViewHeader headerType;
  final bool showSummary;

  final void Function(StandardViewHeader?) onHeaderTypeChanged;
  final void Function(bool) onShowSummaryChanged;

  const FolderViewConfigurationDialog({
    super.key,
    required this.headerType,
    required this.showSummary,
    required this.onHeaderTypeChanged,
    required this.onShowSummaryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: GestureDetector(
        key: const ValueKey("Hack_Back"),
        child: Text(context.loc.widgetsFolderViewHeaderOptionsCustomize),
        onTap: () {
          if (foundation.kDebugMode) {
            Navigator.of(context).pop();
          }
        },
      ),
      key: const ValueKey("ViewOptionsDialog"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsHeader(context.loc.widgetsFolderViewHeaderOptionsHeading),
          RadioGroup<StandardViewHeader>(
            groupValue: headerType,
            onChanged: onHeaderTypeChanged,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<StandardViewHeader>(
                  title: Text(context.loc.widgetsFolderViewHeaderOptionsTitleFileName),
                  value: StandardViewHeader.TitleOrFileName,
                ),
                RadioListTile<StandardViewHeader>(
                  title: Text(context.loc.widgetsFolderViewHeaderOptionsAuto),
                  value: StandardViewHeader.TitleGenerated,
                ),
                RadioListTile<StandardViewHeader>(
                  key: const ValueKey("ShowFileNameOnly"),
                  title: Text(context.loc.widgetsFolderViewHeaderOptionsFileName),
                  value: StandardViewHeader.FileName,
                ),
              ],
            ),
          ),
          SwitchListTile(
            key: const ValueKey("SummaryToggle"),
            title: Text(context.loc.widgetsFolderViewHeaderOptionsSummary),
            value: showSummary,
            onChanged: onShowSummaryChanged,
          ),
        ],
      ),
    );
  }
}
