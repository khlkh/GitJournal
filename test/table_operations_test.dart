// ignore_for_file: avoid_print
// Pure Dart test for table operations correctness.
// Run: dart test/test/table_operations_test.dart
// No Flutter SDK required - this tests the core logic only.
//
// Validates that all table operations (add/delete/duplicate row/column)
// maintain correct flat cell structure: [row0col0, row0col1, row1col0, ...]

/// Simulates a table node with flat cell storage
class MockTableNode {
  int colsLen;
  int rowsLen;

  /// cells indexed as row * colsLen + col
  final List<MockCell> children = [];

  MockTableNode({required this.colsLen, required this.rowsLen}) {
    _rebuildCells();
  }

  void _rebuildCells() {
    children.clear();
    for (var row = 0; row < rowsLen; row++) {
      for (var col = 0; col < colsLen; col++) {
        children.add(MockCell(rowPosition: row, colPosition: col));
      }
    }
  }

  MockCell? getCellNode(int col, int row) {
    final expectedIndex = row * colsLen + col;
    if (expectedIndex < 0 || expectedIndex >= children.length) return null;
    final child = children[expectedIndex];
    if (child.colPosition == col && child.rowPosition == row) return child;
    // Fallback: linear search
    for (final c in children) {
      if (c.colPosition == col && c.rowPosition == row) return c;
    }
    return null;
  }

  /// Add row after given row index. Returns true on success.
  bool addRow(int afterRow) {
    if (afterRow < 0 || afterRow >= rowsLen) return false;
    final newRowIndex = afterRow + 1;

    // Insert new cells at the correct flat index positions
    for (var col = 0; col < colsLen; col++) {
      final cellIndex = newRowIndex * colsLen + col;
      children.insert(cellIndex, MockCell(rowPosition: newRowIndex, colPosition: col));
    }

    // Update rowPosition for cells after the inserted row
    for (var row = newRowIndex + 1; row <= rowsLen; row++) {
      for (var col = 0; col < colsLen; col++) {
        final cell = getCellNode(col, row);
        if (cell != null) cell.rowPosition = row;
      }
    }

    rowsLen++;
    return true;
  }

  /// Delete a row. Returns true on success.
  bool deleteRow(int rowIndex) {
    if (rowsLen <= 1) return false;
    if (rowIndex < 0 || rowIndex >= rowsLen) return false;

    // Delete cells in the row
    for (var col = 0; col < colsLen; col++) {
      final cell = getCellNode(col, rowIndex);
      if (cell != null) children.remove(cell);
    }

    // Update rowPosition for cells after the deleted row
    for (var row = rowIndex + 1; row < rowsLen; row++) {
      for (var col = 0; col < colsLen; col++) {
        final cell = getCellNode(col, row);
        if (cell != null) cell.rowPosition = row - 1;
      }
    }

    rowsLen--;
    return true;
  }

  /// Add column after given column index. Returns true on success.
  bool addColumn(int afterCol) {
    if (afterCol < 0 || afterCol >= colsLen) return false;
    final newColIndex = afterCol + 1;

    // Insert new cells (from bottom to top to keep indices stable)
    for (var row = rowsLen - 1; row >= 0; row--) {
      final cellIndex = row * (colsLen + 1) + newColIndex;
      children.insert(cellIndex, MockCell(rowPosition: row, colPosition: newColIndex));
    }

    // Update colPosition for cells after the inserted column
    for (var row = 0; row < rowsLen; row++) {
      for (var col = newColIndex + 1; col <= colsLen; col++) {
        final cell = getCellNode(col, row);
        if (cell != null) cell.colPosition = col;
      }
    }

    colsLen++;
    return true;
  }

  /// Delete a column. Returns true on success.
  bool deleteColumn(int colIndex) {
    if (colsLen <= 1) return false;
    if (colIndex < 0 || colIndex >= colsLen) return false;

    // Delete cells in the column
    for (var row = 0; row < rowsLen; row++) {
      final cell = getCellNode(colIndex, row);
      if (cell != null) children.remove(cell);
    }

    // Update colPosition for cells after the deleted column
    for (var row = 0; row < rowsLen; row++) {
      for (var col = colIndex + 1; col < colsLen; col++) {
        final cell = getCellNode(col, row);
        if (cell != null) cell.colPosition = col - 1;
      }
    }

    colsLen--;
    return true;
  }

  /// Duplicate a row. Returns true on success.
  bool duplicateRow(int rowIndex) {
    if (rowIndex < 0 || rowIndex >= rowsLen) return false;
    final newRowIndex = rowIndex + 1;

    // Copy each cell in the row
    for (var col = 0; col < colsLen; col++) {
      final sourceCell = getCellNode(col, rowIndex);
      final cellIndex = newRowIndex * colsLen + col;
      if (sourceCell != null) {
        children.insert(cellIndex, MockCell(
          rowPosition: newRowIndex,
          colPosition: col,
        ));
      }
    }

    // Update rowPosition for cells after the inserted row
    for (var row = newRowIndex + 1; row <= rowsLen; row++) {
      for (var col = 0; col < colsLen; col++) {
        final cell = getCellNode(col, row);
        if (cell != null) cell.rowPosition = row;
      }
    }

    rowsLen++;
    return true;
  }

  /// Validate the entire table structure integrity.
  /// Returns a list of error descriptions (empty = valid).
  List<String> validate() {
    final errors = <String>[];

    // Check children count matches dimensions
    if (children.length != colsLen * rowsLen) {
      errors.add('Children count mismatch: expected ${colsLen * rowsLen}, got ${children.length}');
    }

    // Verify all cells have correct positions
    for (var i = 0; i < children.length; i++) {
      final cell = children[i];
      final expectedRow = i ~/ colsLen;
      final expectedCol = i % colsLen;
      if (cell.rowPosition != expectedRow) {
        errors.add('Cell[$i] rowPosition: expected $expectedRow, got ${cell.rowPosition}');
      }
      if (cell.colPosition != expectedCol) {
        errors.add('Cell[$i] colPosition: expected $expectedCol, got ${cell.colPosition}');
      }
    }

    // Check no duplicate positions
    final seen = <String>{};
    for (final cell in children) {
      final key = '${cell.rowPosition},${cell.colPosition}';
      if (seen.contains(key)) {
        errors.add('Duplicate position: ($key)');
      }
      seen.add(key);
    }

    return errors;
  }
}

class MockCell {
  int rowPosition;
  int colPosition;
  MockCell({required this.rowPosition, required this.colPosition});
}

// ============ TESTS ============

int _testCount = 0;
int _passCount = 0;
int _failCount = 0;

void expect(dynamic actual, dynamic expected, [String? description]) {
  _testCount++;
  if (expected is String && description == null) {
    // 2-arg form: expect(bool condition, String description)
    if (actual as bool) {
      _passCount++;
    } else {
      _failCount++;
      print('  FAIL: $expected');
    }
  } else {
    // 3-arg form: expect(actual, expected, description)
    if (actual == expected) {
      _passCount++;
    } else {
      _failCount++;
      print('  FAIL: $description (expected: $expected, got: $actual)');
    }
  }
}

void expectEmpty(List<String> list, String description) {
  expect(list.isEmpty, '$description (${list.join("; ")})');
}

void main() {
  print('=== Table Operations Unit Tests ===\n');

  _testGetCellNode();
  _testAddRow();
  _testAddRowMiddle();
  _testDeleteRow();
  _testDeleteRowLastRowProtected();
  _testAddColumn();
  _testAddColumnMiddle();
  _testDeleteColumn();
  _testDeleteColumnLastProtected();
  _testDuplicateRow();
  _testDuplicateRowMiddle();
  _testMixedOperations();
  _testEdgeCases();

  print('\n=== Results: $_passCount/$_testCount passed, $_failCount failed ===');
  if (_failCount > 0) {
    print('SOME TESTS FAILED!');
  } else {
    print('ALL TESTS PASSED!');
  }
}

void _testGetCellNode() {
  print('Test: _getCellNode');
  final table = MockTableNode(colsLen: 3, rowsLen: 2);
  expect(table.getCellNode(0, 0) != null, 'cell(0,0) exists');
  expect(table.getCellNode(2, 1) != null, 'cell(2,1) exists');
  expect(table.getCellNode(3, 0) == null, 'cell(3,0) out of bounds');
  expect(table.getCellNode(0, 2) == null, 'cell(0,2) out of bounds');
  expectEmpty(table.validate(), 'initial 3x2 table valid');
  print('  3x2 table: ${table.children.length} cells\n');
}

void _testAddRow() {
  print('Test: addRow (at end)');
  final table = MockTableNode(colsLen: 3, rowsLen: 2);
  final result = table.addRow(1);
  expect(result, 'addRow(1) succeeds');
  expect(table.rowsLen, 3, 'rowsLen becomes 3');
  expect(table.colsLen, 3, 'colsLen stays 3');
  expect(table.children.length, 9, '9 cells total');
  expect(table.getCellNode(0, 2) != null, 'new cell(0,2) exists');
  expect(table.getCellNode(2, 2) != null, 'new cell(2,2) exists');
  expectEmpty(table.validate(), 'table valid after addRow at end');
  print('  3x3 table: ${table.children.length} cells\n');
}

void _testAddRowMiddle() {
  print('Test: addRow (in middle)');
  final table = MockTableNode(colsLen: 2, rowsLen: 3);
  // Initial: rows 0,1,2
  final result = table.addRow(0);
  expect(result, 'addRow(0) succeeds');
  expect(table.rowsLen, 4, 'rowsLen becomes 4');
  expect(table.children.length, 8, '8 cells total');
  // Row 0 stays, new row 1, old row 1 becomes row 2, old row 2 becomes row 3
  expect(table.getCellNode(0, 0)?.rowPosition, 0, 'original row 0 stays');
  expect(table.getCellNode(0, 1)?.rowPosition, 1, 'new row 1 inserted');
  expect(table.getCellNode(0, 2)?.rowPosition, 2, 'old row 1 shifted to row 2');
  expect(table.getCellNode(0, 3)?.rowPosition, 3, 'old row 2 shifted to row 3');
  expectEmpty(table.validate(), 'table valid after addRow in middle');
  print('  2x4 table: ${table.children.length} cells\n');
}

void _testDeleteRow() {
  print('Test: deleteRow');
  final table = MockTableNode(colsLen: 3, rowsLen: 3);
  final result = table.deleteRow(1);
  expect(result, 'deleteRow(1) succeeds');
  expect(table.rowsLen, 2, 'rowsLen becomes 2');
  expect(table.colsLen, 3, 'colsLen stays 3');
  expect(table.children.length, 6, '6 cells total');
  expect(table.getCellNode(0, 0)?.rowPosition, 0, 'row 0 stays');
  expect(table.getCellNode(0, 1)?.rowPosition, 1, 'old row 2 becomes row 1');
  expectEmpty(table.validate(), 'table valid after deleteRow');
  print('  3x2 table: ${table.children.length} cells\n');
}

void _testDeleteRowLastRowProtected() {
  print('Test: deleteRow (last row protected)');
  final table = MockTableNode(colsLen: 2, rowsLen: 1);
  final result = table.deleteRow(0);
  expect(!result, 'deleteRow(0) fails on last row');
  expect(table.rowsLen, 1, 'rowsLen stays 1');
  expectEmpty(table.validate(), 'table valid after failed deleteRow\n');
}

void _testAddColumn() {
  print('Test: addColumn (at end)');
  final table = MockTableNode(colsLen: 2, rowsLen: 3);
  final result = table.addColumn(1);
  expect(result, 'addColumn(1) succeeds');
  expect(table.colsLen, 3, 'colsLen becomes 3');
  expect(table.rowsLen, 3, 'rowsLen stays 3');
  expect(table.children.length, 9, '9 cells total');
  expect(table.getCellNode(2, 0) != null, 'new cell(col=2,row=0) exists');
  expectEmpty(table.validate(), 'table valid after addColumn at end');
  print('  3x3 table: ${table.children.length} cells\n');
}

void _testAddColumnMiddle() {
  print('Test: addColumn (in middle)');
  final table = MockTableNode(colsLen: 3, rowsLen: 2);
  final result = table.addColumn(0);
  expect(result, 'addColumn(0) succeeds');
  expect(table.colsLen, 4, 'colsLen becomes 4');
  expect(table.rowsLen, 2, 'rowsLen stays 2');
  expect(table.children.length, 8, '8 cells total');
  // Col 0 stays, new col 1, old col 1 becomes col 2, old col 2 becomes col 3
  expect(table.getCellNode(0, 0)?.colPosition, 0, 'original col 0 stays');
  expect(table.getCellNode(1, 0)?.colPosition, 1, 'new col 1 inserted');
  expect(table.getCellNode(2, 0)?.colPosition, 2, 'old col 1 shifted to col 2');
  expect(table.getCellNode(3, 0)?.colPosition, 3, 'old col 2 shifted to col 3');
  expectEmpty(table.validate(), 'table valid after addColumn in middle');
  print('  4x2 table: ${table.children.length} cells\n');
}

void _testDeleteColumn() {
  print('Test: deleteColumn');
  final table = MockTableNode(colsLen: 3, rowsLen: 2);
  final result = table.deleteColumn(1);
  expect(result, 'deleteColumn(1) succeeds');
  expect(table.colsLen, 2, 'colsLen becomes 2');
  expect(table.rowsLen, 2, 'rowsLen stays 2');
  expect(table.children.length, 4, '4 cells total');
  expectEmpty(table.validate(), 'table valid after deleteColumn');
  print('  2x2 table: ${table.children.length} cells\n');
}

void _testDeleteColumnLastProtected() {
  print('Test: deleteColumn (last column protected)');
  final table = MockTableNode(colsLen: 1, rowsLen: 2);
  final result = table.deleteColumn(0);
  expect(!result, 'deleteColumn(0) fails on last column');
  expect(table.colsLen, 1, 'colsLen stays 1');
  expectEmpty(table.validate(), 'table valid after failed deleteColumn\n');
}

void _testDuplicateRow() {
  print('Test: duplicateRow');
  final table = MockTableNode(colsLen: 3, rowsLen: 2);
  final result = table.duplicateRow(0);
  expect(result, 'duplicateRow(0) succeeds');
  expect(table.rowsLen, 3, 'rowsLen becomes 3');
  expect(table.colsLen, 3, 'colsLen stays 3');
  expect(table.children.length, 9, '9 cells total');
  expectEmpty(table.validate(), 'table valid after duplicateRow');
  print('  3x3 table: ${table.children.length} cells\n');
}

void _testDuplicateRowMiddle() {
  print('Test: duplicateRow (middle row)');
  final table = MockTableNode(colsLen: 2, rowsLen: 3);
  final result = table.duplicateRow(1);
  expect(result, 'duplicateRow(1) succeeds');
  expect(table.rowsLen, 4, 'rowsLen becomes 4');
  expect(table.getCellNode(0, 0)?.rowPosition, 0, 'row 0 stays');
  expect(table.getCellNode(0, 1)?.rowPosition, 1, 'original row 1 stays');
  expect(table.getCellNode(0, 2)?.rowPosition, 2, 'duplicated row 2');
  expect(table.getCellNode(0, 3)?.rowPosition, 3, 'old row 2 becomes row 3');
  expectEmpty(table.validate(), 'table valid after duplicateRow middle');
  print('  2x4 table: ${table.children.length} cells\n');
}

void _testMixedOperations() {
  print('Test: mixed operations');
  final table = MockTableNode(colsLen: 2, rowsLen: 2); // 2x2

  table.addRow(0); // 2x3
  expect(table.rowsLen, 3, 'after addRow: rowsLen=3');
  expectEmpty(table.validate(), 'valid after addRow');

  table.addColumn(1); // 3x3
  expect(table.colsLen, 3, 'after addColumn: colsLen=3');
  expectEmpty(table.validate(), 'valid after addColumn');

  table.deleteRow(1); // 3x2
  expect(table.rowsLen, 2, 'after deleteRow: rowsLen=2');
  expectEmpty(table.validate(), 'valid after deleteRow');

  table.duplicateRow(0); // 3x3
  expect(table.rowsLen, 3, 'after duplicateRow: rowsLen=3');
  expectEmpty(table.validate(), 'valid after duplicateRow');

  table.deleteColumn(0); // 2x3
  expect(table.colsLen, 2, 'after deleteColumn: colsLen=2');
  expectEmpty(table.validate(), 'valid after deleteColumn');

  expect(table.children.length, 6, '6 cells total');
  print('  Final: ${table.colsLen}x${table.rowsLen} table, ${table.children.length} cells\n');
}

void _testEdgeCases() {
  print('Test: edge cases');

  // 1x1 table
  final table1 = MockTableNode(colsLen: 1, rowsLen: 1);
  expectEmpty(table1.validate(), '1x1 table valid');
  table1.addRow(0);
  expect(table1.rowsLen, 2, '1x1 addRow -> 1x2');
  expectEmpty(table1.validate(), '1x2 valid');
  print('  1x1 -> 1x2: OK');

  // Large table
  final tableLarge = MockTableNode(colsLen: 10, rowsLen: 10);
  expectEmpty(tableLarge.validate(), '10x10 valid');
  tableLarge.addRow(5);
  expect(tableLarge.rowsLen, 11, '10x10 addRow -> 10x11');
  expectEmpty(tableLarge.validate(), '10x11 valid');
  tableLarge.addColumn(3);
  expect(tableLarge.colsLen, 11, '10x11 addColumn -> 11x11');
  expectEmpty(tableLarge.validate(), '11x11 valid');
  print('  10x10 -> 11x11: OK');

  // Delete everything possible
  final tableDel = MockTableNode(colsLen: 5, rowsLen: 5);
  for (var i = 4; i > 0; i--) {
    tableDel.deleteRow(i);
    expectEmpty(tableDel.validate(), 'valid after deleting row $i');
  }
  for (var i = 4; i > 0; i--) {
    tableDel.deleteColumn(i);
    expectEmpty(tableDel.validate(), 'valid after deleting col $i');
  }
  expect(tableDel.colsLen, 1, 'final: 1 col');
  expect(tableDel.rowsLen, 1, 'final: 1 row');
  expect(!tableDel.deleteRow(0), 'cannot delete last row');
  expect(!tableDel.deleteColumn(0), 'cannot delete last column');
  print('  Shrink to 1x1: OK\n');
}
