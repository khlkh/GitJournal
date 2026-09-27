// SPDX-FileCopyrightText: 2019-2021 Vishesh Handa <me@vhanda.in>
//
// SPDX-License-Identifier: AGPL-3.0-or-later
// TAG: AppFlowy Editor Support v2
// Features: WYSIWYG editing, Tables, Bullet/Numbered lists, Checkboxes, Headings
// Build: 61
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gitjournal/core/folder/notes_folder.dart';
import 'package:gitjournal/core/note.dart';
import 'package:gitjournal/core/notes/note.dart';
import 'package:gitjournal/editors/common.dart' as gj;
import 'package:gitjournal/editors/utils/disposable_change_notifier.dart';
import 'package:appflowy_editor/appflowy_editor.dart';

/// A standalone WYSIWYG Markdown Editor using AppFlowy Editor
class AppFlowyNoteEditor extends StatefulWidget implements gj.Editor {
  final Note note;
  final NotesFolder parentFolder;
  final bool noteModified;
  @override
  final gj.EditorCommon common;
  final bool editMode;
  final String? highlightString;
  final ThemeData theme;

  const AppFlowyNoteEditor({
    super.key,
    required this.note,
    required this.parentFolder,
    required this.noteModified,
    required this.editMode,
    required this.highlightString,
    required this.theme,
    required this.common,
  });

  @override
  AppFlowyNoteEditorState createState() => AppFlowyNoteEditorState();
}

class AppFlowyNoteEditorState extends State<AppFlowyNoteEditor>
    with DisposableChangeNotifier
    implements gj.EditorState {
  late EditorState _editorState;
  late TextEditingController _titleController;
  bool _isModified = false;
  late Note _note;
  StreamSubscription? _transactionSub;
  String _originalMarkdown = '';  // 保存原始 Markdown，用于未修改时恢复
  String _initialEditorContent = '';  // 保存初始编辑器内容（Markdown 格式），用于检测是否真正修改
  VoidCallback? _selectionListener;
  bool _isInTable = false;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _isModified = widget.noteModified;
    _titleController = TextEditingController(text: _note.title ?? '');

    _originalMarkdown = _note.body;  // 保存原始 Markdown
    final document = markdownToDocument(_note.body);
    _editorState = EditorState(document: document);
    _initialEditorContent = documentToMarkdown(_editorState.document);  // 保存初始编辑器内容

    // 监听 transaction 用于标记修改
    _transactionSub = _editorState.transactionStream.listen((_) {
      if (!_isModified) {
        setState(() {
          _isModified = true;
        });
        notifyListeners();
      }
    });

    // 监听 selection 变化用于切换工具栏
    _selectionListener = () {
      _updateTableState();
    };
    _editorState.selectionNotifier.addListener(_selectionListener!);
  }

  void _updateTableState() {
    if (!mounted) return;
    
    final wasInTable = _isInTable;
    _isInTable = _isSelectionInTable();
    
    if (wasInTable != _isInTable) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _transactionSub?.cancel();
    if (_selectionListener != null) {
      _editorState.selectionNotifier.removeListener(_selectionListener!);
    }
    _titleController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AppFlowyNoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noteModified != widget.noteModified) {
      _isModified = widget.noteModified;
    }
    if (oldWidget.note != widget.note) {
      _note = widget.note;
      _titleController.text = _note.title ?? '';
      final document = markdownToDocument(_note.body);
      _editorState = EditorState(document: document);
    }
  }

  /// Check if current selection is inside a table
  bool _isSelectionInTable() {
    final sel = _editorState.selection;
    if (sel == null) return false;
    Node? current = _editorState.getNodeAtPath(sel.start.path);
    while (current != null) {
      if (current.type == TableBlockKeys.type) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  /// Find table node from current selection
  Node? _findTableNode() {
    final sel = _editorState.selection;
    if (sel == null) return null;
    for (int i = sel.start.path.length - 1; i >= 0; i--) {
      final path = sel.start.path.sublist(0, i + 1);
      final node = _editorState.getNodeAtPath(path);
      if (node != null && node.type == TableBlockKeys.type) {
        return node;
      }
    }
    return null;
  }

  /// Get cell position in table
  MapEntry<int, int>? _getTableCellPosition() {
    final sel = _editorState.selection;
    if (sel == null) return null;
    if (sel.start.path.length < 3) return null;
    final colIndex = sel.start.path[sel.start.path.length - 2];
    final rowIndex = sel.start.path[sel.start.path.length - 1];
    return MapEntry(rowIndex, colIndex);
  }

  @override
  @override
  Note getNote() {
    final currentContent = documentToMarkdown(_editorState.document);
    
    // 比较当前内容和初始内容，判断是否真正修改过
    // 这样可以处理编辑后又撤销的情况
    if (currentContent == _initialEditorContent) {
      // 内容未改变，返回原始 Markdown（避免被规范化）
      return _note.copyWith(
        body: _originalMarkdown,
        title: _titleController.text.trim(),
        type: NoteType.Unknown,
      );
    }
    
    // 内容真正改变了，返回编辑器内容
    return _note.copyWith(
      body: currentContent,
      title: _titleController.text.trim(),
      type: NoteType.Unknown,
    );
  }

  @override
  Future<void> addImage(String filePath) async {
    // TODO: Implement image insertion
  }

  @override
  bool get noteModified => _isModified;

  @override
  gj.SearchInfo search(String? text) {
    // TODO: Implement search
    return gj.SearchInfo();
  }

  @override
  void scrollToResult(String text, int num) {
    // TODO: Implement scroll to result
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return gj.EditorScaffold(
      startingNote: widget.note,
      editor: widget,
      editorState: this,
      noteModified: _isModified,
      editMode: widget.editMode,
      parentFolder: _note.parent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
              ),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              onChanged: (_) {
                _isModified = true;
                notifyListeners();
              },
            ),
          ),
          const Divider(height: 1),
          _buildToolbar(colorScheme),
          const Divider(height: 1),
          Expanded(
            child: _buildEditor(colorScheme),
          ),
        ],
      ),
      onUndoSelected: () {},
      onRedoSelected: () {},
      undoAllowed: false,
      redoAllowed: false,
      findAllowed: false,
    );
  }

  Widget _buildEditor(ColorScheme colorScheme) {
    return AppFlowyEditor(
      editorState: _editorState,
      editable: true,
      autoFocus: true,
      showMagnifier: false,
      editorStyle: EditorStyle.mobile(
        padding: const EdgeInsets.all(16),
        cursorColor: colorScheme.primary,
        selectionColor: colorScheme.primaryContainer.withValues(alpha: 0.4),
        textStyleConfiguration: TextStyleConfiguration(
          text: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 16,
            height: 1.5,
          ),
          bold: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
          italic: TextStyle(
            color: colorScheme.onSurface,
            fontStyle: FontStyle.italic,
          ),
          underline: TextStyle(
            color: colorScheme.onSurface,
            decoration: TextDecoration.underline,
          ),
          strikethrough: TextStyle(
            color: colorScheme.onSurface,
            decoration: TextDecoration.lineThrough,
          ),
          code: TextStyle(
            color: colorScheme.primary,
            backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
            fontFamily: 'monospace',
            fontSize: 14,
          ),
        ),
      ),
      blockComponentBuilders: standardBlockComponentBuilderMap,
      characterShortcutEvents: standardCharacterShortcutEvents,
      commandShortcutEvents: standardCommandShortcutEvents,
    );
  }

  Widget _buildToolbar(ColorScheme colorScheme) {
    return Material(
      color: colorScheme.surfaceContainerLow,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _isInTable
                ? _buildTableToolbar(colorScheme)
                : _buildNormalToolbar(colorScheme),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildNormalToolbar(ColorScheme colorScheme) {
    return [
      _buildToolbarButton(
        icon: Icons.title,
        tooltip: 'Heading H1',
        onPressed: () => _toggleHeading(1),
      ),
      _buildToolbarButton(
        icon: Icons.format_size,
        tooltip: 'Heading H2',
        onPressed: () => _toggleHeading(2),
      ),
      _buildToolbarButton(
        icon: Icons.format_size,
        tooltip: 'Heading H3',
        onPressed: () => _toggleHeading(3),
        iconSize: 18,
      ),
      _buildDivider(colorScheme),
      _buildToolbarButton(
        icon: Icons.format_bold,
        tooltip: 'Bold',
        onPressed: () => _editorState.toggleAttribute(BuiltInAttributeKey.bold),
      ),
      _buildToolbarButton(
        icon: Icons.format_italic,
        tooltip: 'Italic',
        onPressed: () => _editorState.toggleAttribute(BuiltInAttributeKey.italic),
      ),
      _buildToolbarButton(
        icon: Icons.format_underlined,
        tooltip: 'Underline',
        onPressed: () => _editorState.toggleAttribute(BuiltInAttributeKey.underline),
      ),
      _buildToolbarButton(
        icon: Icons.strikethrough_s,
        tooltip: 'Strikethrough',
        onPressed: () => _editorState.toggleAttribute(BuiltInAttributeKey.strikethrough),
      ),
      _buildDivider(colorScheme),
      _buildToolbarButton(
        icon: Icons.format_list_bulleted,
        tooltip: 'Bullet List',
        onPressed: () => _toggleBlockType(BulletedListBlockKeys.type),
      ),
      _buildToolbarButton(
        icon: Icons.format_list_numbered,
        tooltip: 'Numbered List',
        onPressed: () => _toggleBlockType(NumberedListBlockKeys.type),
      ),
      _buildToolbarButton(
        icon: Icons.check_box_outlined,
        tooltip: 'Todo List',
        onPressed: () => _toggleTodoList(),
      ),
      _buildDivider(colorScheme),
      _buildToolbarButton(
        icon: Icons.format_quote,
        tooltip: 'Quote',
        onPressed: () => _toggleBlockType(QuoteBlockKeys.type),
      ),
      _buildToolbarButton(
        icon: Icons.table_chart,
        tooltip: 'Insert Table',
        onPressed: _showInsertTableDialog,
      ),
    ];
  }

  List<Widget> _buildTableToolbar(ColorScheme colorScheme) {
    return [
      _buildToolbarButton(
        icon: Icons.table_chart,
        tooltip: 'Table: Add Row Below',
        onPressed: _tableAddRow,
      ),
      _buildToolbarButton(
        icon: Icons.table_chart_outlined,
        tooltip: 'Table: Add Row Above',
        onPressed: _tableAddRowAbove,
      ),
      _buildToolbarButton(
        icon: Icons.view_column,
        tooltip: 'Table: Add Column Right',
        onPressed: _tableAddColumn,
      ),
      _buildDivider(colorScheme),
      _buildToolbarButton(
        icon: Icons.delete_outline,
        tooltip: 'Table: Delete Row',
        onPressed: _tableDeleteRow,
      ),
      _buildToolbarButton(
        icon: Icons.delete_sweep,
        tooltip: 'Table: Delete Column',
        onPressed: _tableDeleteColumn,
      ),
      _buildDivider(colorScheme),
      _buildToolbarButton(
        icon: Icons.content_copy,
        tooltip: 'Table: Duplicate Row',
        onPressed: _tableDuplicateRow,
      ),
    ];
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    double iconSize = 20,
  }) {
    return IconButton(
      icon: Icon(icon, size: iconSize),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  Widget _buildDivider(ColorScheme colorScheme) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
  }

  /// Toggle block type using formatNode
  void _toggleBlockType(String targetType) {
    final selection = _editorState.selection;
    if (selection == null) {
      debugPrint('No selection available');
      return;
    }
    final node = _editorState.getNodeAtPath(selection.start.path);
    if (node == null) {
      debugPrint('No node at selection');
      return;
    }
    final newType = node.type == targetType ? ParagraphBlockKeys.type : targetType;
    debugPrint('Toggling block: ${node.type} -> $newType at path ${selection.start.path}');
    _editorState.formatNode(
      selection,
      (node) => node.copyWith(type: newType),
    );
  }

  /// Toggle todo list with checked attribute
  void _toggleTodoList() {
    final selection = _editorState.selection;
    if (selection == null) {
      debugPrint('No selection available');
      return;
    }
    final node = _editorState.getNodeAtPath(selection.start.path);
    if (node == null) {
      debugPrint('No node at selection');
      return;
    }
    final isTodo = node.type == TodoListBlockKeys.type;
    final newType = isTodo ? ParagraphBlockKeys.type : TodoListBlockKeys.type;
    debugPrint('Toggling todo: ${node.type} -> $newType');
    if (isTodo) {
      _editorState.formatNode(
        selection,
        (node) => node.copyWith(type: newType),
      );
    } else {
      _editorState.formatNode(
        selection,
        (node) => node.copyWith(
          type: newType,
          attributes: {
            ...node.attributes,
            TodoListBlockKeys.checked: false,
          },
        ),
      );
    }
  }

  /// Toggle heading level
  void _toggleHeading(int level) {
    final selection = _editorState.selection;
    if (selection == null) {
      debugPrint('No selection available');
      return;
    }
    final node = _editorState.getNodeAtPath(selection.start.path);
    if (node == null) {
      debugPrint('No node at selection');
      return;
    }
    final isHeading = node.type == HeadingBlockKeys.type;
    final currentLevel = node.attributes[HeadingBlockKeys.level] ?? 1;
    final shouldToggleOff = isHeading && currentLevel == level;
    final newType = shouldToggleOff ? ParagraphBlockKeys.type : HeadingBlockKeys.type;
    final newAttributes = shouldToggleOff
        ? <String, dynamic>{}
        : {...node.attributes, HeadingBlockKeys.level: level};
    debugPrint('Toggling heading: ${node.type} -> $newType level $level');
    _editorState.formatNode(
      selection,
      (node) => node.copyWith(
        type: newType,
        attributes: newAttributes,
      ),
    );
  }

  // --- Table Operations ---
  void _showInsertTableDialog() {
    showDialog(
      context: context,
      builder: (context) => _InsertTableDialog(
        onInsert: _insertTable,
      ),
    );
  }

  void _insertTable(int rows, int cols) {
    final sel = _editorState.selection;
    final lastPath = [_editorState.document.root.children.length - 1];
    final insertPath = sel?.end.path ?? lastPath;
    final tableData = List.generate(
      cols,
      (_) => List.generate(rows, (_) => ''),
    );
    final tableNode = TableNode.fromList(tableData);
    final transaction = _editorState.transaction;
    final currentNode = _editorState.getNodeAtPath(insertPath);
    if (currentNode != null &&
        currentNode.delta != null &&
        currentNode.delta!.isEmpty) {
      transaction.deleteNode(currentNode);
      transaction.insertNode(insertPath, tableNode.node);
    } else {
      transaction.insertNode(insertPath.next, tableNode.node);
    }
    transaction.afterSelection = Selection.collapsed(
      Position(path: insertPath + [0, 0], offset: 0),
    );
    _editorState.apply(transaction);
    debugPrint('Inserted table ${rows}x$cols');
  }

  /// Find cell by (col, row) using linear search on attributes.
  /// Safe during position shifts where physical indices may not match.
  Node? _getCellNode(Node tableNode, int col, int row) {
    for (final c in tableNode.children) {
      final cCol = c.attributes[TableCellBlockKeys.colPosition] as int? ?? 0;
      final cRow = c.attributes[TableCellBlockKeys.rowPosition] as int? ?? 0;
      if (cCol == col && cRow == row) return c;
    }
    return null;
  }

  void _tableAddRow() {
    final tableNode = _findTableNode();
    final cellPos = _getTableCellPosition();
    if (tableNode == null || cellPos == null) return;

    final colsLen = tableNode.attributes[TableBlockKeys.colsLen] as int? ?? 0;
    final rowsLen = tableNode.attributes[TableBlockKeys.rowsLen] as int? ?? 0;
    final afterRow = cellPos.key;
    final newRowIndex = afterRow + 1;

    final transaction = _editorState.transaction;

    // Shift: update rowPosition for existing cells with rowPosition > afterRow
    for (final c in tableNode.children) {
      final r = c.attributes[TableCellBlockKeys.rowPosition] as int? ?? 0;
      if (r > afterRow) {
        transaction.updateNode(c, {TableCellBlockKeys.rowPosition: r + 1});
      }
    }

    // Update table rows count
    transaction.updateNode(tableNode, {TableBlockKeys.rowsLen: rowsLen + 1});

    // Insert new cells for the new row
    for (var col = 0; col < colsLen; col++) {
      final cellIndex = newRowIndex * colsLen + col;
      transaction.insertNode(
        [...tableNode.path, cellIndex],
        tableCellNode('', newRowIndex, col),
      );
    }

    _editorState.apply(transaction);
    debugPrint('Added row at index $newRowIndex');
  }

  void _tableAddRowAbove() {
    final tableNode = _findTableNode();
    final cellPos = _getTableCellPosition();
    if (tableNode == null || cellPos == null) return;

    final colsLen = tableNode.attributes[TableBlockKeys.colsLen] as int? ?? 0;
    final rowsLen = tableNode.attributes[TableBlockKeys.rowsLen] as int? ?? 0;
    final currentRow = cellPos.key;
    final newRowIndex = currentRow;

    final transaction = _editorState.transaction;

    // Shift: update rowPosition for existing cells with rowPosition >= currentRow
    for (final c in tableNode.children) {
      final r = c.attributes[TableCellBlockKeys.rowPosition] as int? ?? 0;
      if (r >= currentRow) {
        transaction.updateNode(c, {TableCellBlockKeys.rowPosition: r + 1});
      }
    }

    // Update table rows count
    transaction.updateNode(tableNode, {TableBlockKeys.rowsLen: rowsLen + 1});

    // Insert new cells at the position of the new row
    for (var col = 0; col < colsLen; col++) {
      final cellIndex = newRowIndex * colsLen + col;
      transaction.insertNode(
        [...tableNode.path, cellIndex],
        tableCellNode('', newRowIndex, col),
      );
    }

    _editorState.apply(transaction);
    debugPrint('Added row above at index $newRowIndex');
  }

  void _tableAddColumn() {
    final tableNode = _findTableNode();
    final cellPos = _getTableCellPosition();
    if (tableNode == null || cellPos == null) return;

    final colsLen = tableNode.attributes[TableBlockKeys.colsLen] as int? ?? 0;
    final rowsLen = tableNode.attributes[TableBlockKeys.rowsLen] as int? ?? 0;
    final afterCol = cellPos.value;
    final newColIndex = afterCol + 1;

    final transaction = _editorState.transaction;

    // Shift: update colPosition for existing cells with colPosition > afterCol
    for (final c in tableNode.children) {
      final col = c.attributes[TableCellBlockKeys.colPosition] as int? ?? 0;
      if (col > afterCol) {
        transaction.updateNode(c, {TableCellBlockKeys.colPosition: col + 1});
      }
    }

    // Update table cols count
    transaction.updateNode(tableNode, {TableBlockKeys.colsLen: colsLen + 1});

    // Insert new cells for the new column
    for (var row = 0; row < rowsLen; row++) {
      final cellIndex = row * colsLen + newColIndex;
      transaction.insertNode(
        [...tableNode.path, cellIndex],
        tableCellNode('', row, newColIndex),
      );
    }

    _editorState.apply(transaction);
    debugPrint('Added column at index $newColIndex');
  }

  void _tableDeleteRow() {
    final tableNode = _findTableNode();
    final cellPos = _getTableCellPosition();
    if (tableNode == null || cellPos == null) return;

    final rowsLen = tableNode.attributes[TableBlockKeys.rowsLen] as int? ?? 0;
    if (rowsLen <= 1) return;
    final rowToDelete = cellPos.key;

    final transaction = _editorState.transaction;

    // Delete cells in the row
    for (final c in tableNode.children.toList()) {
      final r = c.attributes[TableCellBlockKeys.rowPosition] as int? ?? 0;
      if (r == rowToDelete) {
        transaction.deleteNode(c);
      }
    }

    // Shift: cells with rowPosition > rowToDelete get -1
    for (final c in tableNode.children.toList()) {
      final r = c.attributes[TableCellBlockKeys.rowPosition] as int? ?? 0;
      if (r > rowToDelete) {
        transaction.updateNode(c, {TableCellBlockKeys.rowPosition: r - 1});
      }
    }

    // Update table rows count
    transaction.updateNode(tableNode, {TableBlockKeys.rowsLen: rowsLen - 1});

    _editorState.apply(transaction);
    debugPrint('Deleted row at index $rowToDelete');
  }

  void _tableDeleteColumn() {
    final tableNode = _findTableNode();
    final cellPos = _getTableCellPosition();
    if (tableNode == null || cellPos == null) return;

    final colsLen = tableNode.attributes[TableBlockKeys.colsLen] as int? ?? 0;
    if (colsLen <= 1) return;
    final colToDelete = cellPos.value;

    final transaction = _editorState.transaction;

    // Delete cells in the column
    for (final c in tableNode.children.toList()) {
      final col = c.attributes[TableCellBlockKeys.colPosition] as int? ?? 0;
      if (col == colToDelete) {
        transaction.deleteNode(c);
      }
    }

    // Shift: cells with colPosition > colToDelete get -1
    for (final c in tableNode.children.toList()) {
      final col = c.attributes[TableCellBlockKeys.colPosition] as int? ?? 0;
      if (col > colToDelete) {
        transaction.updateNode(c, {TableCellBlockKeys.colPosition: col - 1});
      }
    }

    // Update table cols count
    transaction.updateNode(tableNode, {TableBlockKeys.colsLen: colsLen - 1});

    _editorState.apply(transaction);
    debugPrint('Deleted column at index $colToDelete');
  }

  void _tableDuplicateRow() {
    final tableNode = _findTableNode();
    final cellPos = _getTableCellPosition();
    if (tableNode == null || cellPos == null) return;

    final colsLen = tableNode.attributes[TableBlockKeys.colsLen] as int? ?? 0;
    final rowsLen = tableNode.attributes[TableBlockKeys.rowsLen] as int? ?? 0;
    final rowToCopy = cellPos.key;
    final newRowIndex = rowToCopy + 1;

    final transaction = _editorState.transaction;

    // Shift: update rowPosition for existing cells with rowPosition > rowToCopy
    for (final c in tableNode.children) {
      final r = c.attributes[TableCellBlockKeys.rowPosition] as int? ?? 0;
      if (r > rowToCopy) {
        transaction.updateNode(c, {TableCellBlockKeys.rowPosition: r + 1});
      }
    }

    // Update table rows count
    transaction.updateNode(tableNode, {TableBlockKeys.rowsLen: rowsLen + 1});

    // Copy each cell in the row
    for (var col = 0; col < colsLen; col++) {
      final cellIndex = newRowIndex * colsLen + col;
      final sourceCell = _getCellNode(tableNode, col, rowToCopy);
      if (sourceCell != null) {
        final newCell = sourceCell.copyWith(
          attributes: {
            ...sourceCell.attributes,
            TableCellBlockKeys.rowPosition: newRowIndex,
            TableCellBlockKeys.colPosition: col,
          },
        );
        transaction.insertNode([...tableNode.path, cellIndex], newCell);
      } else {
        transaction.insertNode(
          [...tableNode.path, cellIndex],
          tableCellNode('', newRowIndex, col),
        );
      }
    }

    _editorState.apply(transaction);
    debugPrint('Duplicated row at index $newRowIndex');
  }
}


// --- Insert Table Dialog ---
class _InsertTableDialog extends StatefulWidget {
  final Function(int rows, int cols) onInsert;

  const _InsertTableDialog({required this.onInsert});

  @override
  _InsertTableDialogState createState() => _InsertTableDialogState();
}

class _InsertTableDialogState extends State<_InsertTableDialog> {
  int _rows = 3;
  int _cols = 3;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Insert Table'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Rows:'),
              Expanded(
                child: Slider(
                  value: _rows.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: _rows.toString(),
                  onChanged: (value) {
                    setState(() {
                      _rows = value.toInt();
                    });
                  },
                ),
              ),
              Text(_rows.toString()),
            ],
          ),
          Row(
            children: [
              const Text('Columns:'),
              Expanded(
                child: Slider(
                  value: _cols.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: _cols.toString(),
                  onChanged: (value) {
                    setState(() {
                      _cols = value.toInt();
                    });
                  },
                ),
              ),
              Text(_cols.toString()),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            widget.onInsert(_rows, _cols);
            Navigator.pop(context);
          },
          child: const Text('Insert'),
        ),
      ],
    );
  }
}
