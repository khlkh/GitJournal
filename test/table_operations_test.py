#!/usr/bin/env python3
"""
Table operations test - verifies flat cell structure correctness.
Validates the same logic used in appflowy_note_editor.dart table operations.

Strategy: Uses physical index insertion (like AppFlowy's insertNode(path, node))
with explicit cellIndex calculation. After all operations, validates that
physical index matches (rowPosition, colPosition) via row-major ordering.

Run: python3 test/table_operations_test.py
"""

class MockCell:
    def __init__(self, row_pos, col_pos, content=''):
        self.row_position = row_pos
        self.col_position = col_pos
        self.content = content
    def __repr__(self):
        return f'({self.r},{self.c})'
    @property
    def r(self): return self.row_position
    @property
    def c(self): return self.col_position

class MockTableNode:
    def __init__(self, cols_len, rows_len):
        self.cols_len = cols_len
        self.rows_len = rows_len
        self.children = []
        for r in range(rows_len):
            for c in range(cols_len):
                self.children.append(MockCell(r, c))

    def get_cell_node(self, col, row):
        for c in self.children:
            if c.col_position == col and c.row_position == row:
                return c
        return None

    def add_row(self, after_row):
        if after_row < 0 or after_row >= self.rows_len:
            return False
        new_row_index = after_row + 1
        # Shift old cells with row_position > after_row
        for c in self.children:
            if c.row_position > after_row:
                c.row_position += 1
        # Insert new cells at correct physical indices
        for col in range(self.cols_len):
            cell_index = new_row_index * self.cols_len + col
            self.children.insert(cell_index, MockCell(new_row_index, col))
        self.rows_len += 1
        return True

    def add_row_above(self, current_row):
        """Insert a new row above the current row."""
        if current_row < 0 or current_row >= self.rows_len:
            return False
        new_row_index = current_row
        # Shift old cells with row_position >= current_row
        for c in self.children:
            if c.row_position >= current_row:
                c.row_position += 1
        # Insert new cells at the position of the new row
        for col in range(self.cols_len):
            cell_index = new_row_index * self.cols_len + col
            self.children.insert(cell_index, MockCell(new_row_index, col))
        self.rows_len += 1
        return True

    def delete_row(self, row_index):
        if self.rows_len <= 1:
            return False
        if row_index < 0 or row_index >= self.rows_len:
            return False
        # Delete cells in the row
        self.children = [c for c in self.children if c.row_position != row_index]
        # Shift cells with row_position > row_index
        for c in self.children:
            if c.row_position > row_index:
                c.row_position -= 1
        self.rows_len -= 1
        return True

    def add_column(self, after_col):
        if after_col < 0 or after_col >= self.cols_len:
            return False
        new_col_index = after_col + 1
        # Shift old cells with col_position > after_col
        for c in self.children:
            if c.col_position > after_col:
                c.col_position += 1
        # Insert new cells at correct physical indices (bottom to top)
        for row in range(self.rows_len - 1, -1, -1):
            cell_index = row * self.cols_len + new_col_index
            self.children.insert(cell_index, MockCell(row, new_col_index))
        self.cols_len += 1
        return True

    def delete_column(self, col_index):
        if self.cols_len <= 1:
            return False
        if col_index < 0 or col_index >= self.cols_len:
            return False
        # Delete cells in the column
        self.children = [c for c in self.children if c.col_position != col_index]
        # Shift cells with col_position > col_index
        for c in self.children:
            if c.col_position > col_index:
                c.col_position -= 1
        self.cols_len -= 1
        return True

    def duplicate_row(self, row_index):
        if row_index < 0 or row_index >= self.rows_len:
            return False
        new_row_index = row_index + 1
        # Shift old cells with row_position > row_index
        for c in self.children:
            if c.row_position > row_index:
                c.row_position += 1
        # Copy each cell in the row
        for col in range(self.cols_len):
            cell_index = new_row_index * self.cols_len + col
            source = self.get_cell_node(col, row_index)
            if source:
                self.children.insert(cell_index, MockCell(new_row_index, col, source.content))
            else:
                self.children.insert(cell_index, MockCell(new_row_index, col))
        self.rows_len += 1
        return True

    def validate(self):
        errors = []
        if len(self.children) != self.cols_len * self.rows_len:
            errors.append(f'Children count: expected {self.cols_len * self.rows_len}, got {len(self.children)}')
        for i, cell in enumerate(self.children):
            expected_row = i // self.cols_len
            expected_col = i % self.cols_len
            if cell.row_position != expected_row:
                errors.append(f'Cell[{i}] row: expected {expected_row}, got {cell.row_position}')
            if cell.col_position != expected_col:
                errors.append(f'Cell[{i}] col: expected {expected_col}, got {cell.col_position}')
        seen = set()
        for cell in self.children:
            key = (cell.row_position, cell.col_position)
            if key in seen:
                errors.append(f'Duplicate position: {key}')
            seen.add(key)
        return errors


passed = 0
failed = 0
total = 0

def check(condition, desc):
    global passed, failed, total
    total += 1
    if condition:
        passed += 1
    else:
        failed += 1
        print(f'  FAIL: {desc}')

def check_empty(errors, desc):
    check(len(errors) == 0, f'{desc} ({"; ".join(errors[:3])})')

def test_get_cell_node():
    print('Test: getCellNode')
    t = MockTableNode(3, 2)
    check(t.get_cell_node(0, 0) is not None, 'cell(0,0) exists')
    check(t.get_cell_node(2, 1) is not None, 'cell(2,1) exists')
    check(t.get_cell_node(3, 0) is None, 'cell(3,0) out of bounds')
    check(t.get_cell_node(0, 2) is None, 'cell(0,2) out of bounds')
    check_empty(t.validate(), 'initial 3x2 valid')

def test_add_row():
    print('Test: addRow (at end)')
    t = MockTableNode(3, 2)
    check(t.add_row(1), 'addRow(1) succeeds')
    check(t.rows_len == 3, 'rowsLen=3')
    check(t.cols_len == 3, 'colsLen=3')
    check(len(t.children) == 9, '9 cells')
    check(t.get_cell_node(0, 2) is not None, 'cell(0,2) exists')
    check(t.get_cell_node(2, 2) is not None, 'cell(2,2) exists')
    check_empty(t.validate(), 'valid after addRow')

def test_add_row_middle():
    print('Test: addRow (middle)')
    t = MockTableNode(2, 3)
    check(t.add_row(0), 'addRow(0) succeeds')
    check(t.rows_len == 4, 'rowsLen=4')
    check(t.get_cell_node(0, 0).row_position == 0, 'row 0 stays')
    check(t.get_cell_node(0, 1).row_position == 1, 'new row 1')
    check(t.get_cell_node(0, 2).row_position == 2, 'old row 1 -> row 2')
    check(t.get_cell_node(0, 3).row_position == 3, 'old row 2 -> row 3')
    check_empty(t.validate(), 'valid after addRow middle')

def test_add_row_above():
    print('Test: addRowAbove')
    t = MockTableNode(3, 3)
    # Insert above row 1 (middle)
    check(t.add_row_above(1), 'addRowAbove(1) succeeds')
    check(t.rows_len == 4, 'rowsLen=4')
    check(t.cols_len == 3, 'colsLen=3')
    check(len(t.children) == 12, '12 cells')
    check(t.get_cell_node(0, 0).row_position == 0, 'row 0 stays')
    check(t.get_cell_node(0, 1).row_position == 1, 'new row 1 (above)')
    check(t.get_cell_node(0, 2).row_position == 2, 'old row 1 -> row 2')
    check(t.get_cell_node(0, 3).row_position == 3, 'old row 2 -> row 3')
    check_empty(t.validate(), 'valid after addRowAbove middle')

def test_add_row_above_first():
    print('Test: addRowAbove (first row)')
    t = MockTableNode(2, 3)
    check(t.add_row_above(0), 'addRowAbove(0) succeeds')
    check(t.rows_len == 4, 'rowsLen=4')
    check(t.get_cell_node(0, 0).row_position == 0, 'new row 0 (above)')
    check(t.get_cell_node(0, 1).row_position == 1, 'old row 0 -> row 1')
    check(t.get_cell_node(0, 2).row_position == 2, 'old row 1 -> row 2')
    check(t.get_cell_node(0, 3).row_position == 3, 'old row 2 -> row 3')
    check_empty(t.validate(), 'valid after addRowAbove first')

def test_add_row_above_last():
    print('Test: addRowAbove (last row)')
    t = MockTableNode(2, 3)
    check(t.add_row_above(2), 'addRowAbove(2) succeeds')
    check(t.rows_len == 4, 'rowsLen=4')
    check(t.get_cell_node(0, 0).row_position == 0, 'row 0 stays')
    check(t.get_cell_node(0, 1).row_position == 1, 'row 1 stays')
    check(t.get_cell_node(0, 2).row_position == 2, 'new row 2 (above last)')
    check(t.get_cell_node(0, 3).row_position == 3, 'old row 2 -> row 3')
    check_empty(t.validate(), 'valid after addRowAbove last')

def test_delete_row():
    print('Test: deleteRow')
    t = MockTableNode(3, 3)
    check(t.delete_row(1), 'deleteRow(1) succeeds')
    check(t.rows_len == 2, 'rowsLen=2')
    check(len(t.children) == 6, '6 cells')
    check(t.get_cell_node(0, 0).row_position == 0, 'row 0 stays')
    check(t.get_cell_node(0, 1).row_position == 1, 'old row 2 -> row 1')
    check_empty(t.validate(), 'valid after deleteRow')

def test_delete_row_last():
    print('Test: deleteRow (last protected)')
    t = MockTableNode(2, 1)
    check(not t.delete_row(0), 'deleteRow fails')
    check(t.rows_len == 1, 'rowsLen=1')

def test_add_column():
    print('Test: addColumn (at end)')
    t = MockTableNode(2, 3)
    check(t.add_column(1), 'addColumn(1) succeeds')
    check(t.cols_len == 3, 'colsLen=3')
    check(t.get_cell_node(2, 0) is not None, 'cell(col=2,row=0)')
    check_empty(t.validate(), 'valid after addColumn')

def test_add_column_middle():
    print('Test: addColumn (middle)')
    t = MockTableNode(3, 2)
    check(t.add_column(0), 'addColumn(0) succeeds')
    check(t.cols_len == 4, 'colsLen=4')
    check(t.get_cell_node(0, 0).col_position == 0, 'col 0 stays')
    check(t.get_cell_node(1, 0).col_position == 1, 'new col 1')
    check(t.get_cell_node(2, 0).col_position == 2, 'old col 1 -> col 2')
    check(t.get_cell_node(3, 0).col_position == 3, 'old col 2 -> col 3')
    check_empty(t.validate(), 'valid after addColumn middle')

def test_delete_column():
    print('Test: deleteColumn')
    t = MockTableNode(3, 2)
    check(t.delete_column(1), 'deleteColumn(1) succeeds')
    check(t.cols_len == 2, 'colsLen=2')
    check_empty(t.validate(), 'valid after deleteColumn')

def test_delete_column_last():
    print('Test: deleteColumn (last protected)')
    t = MockTableNode(1, 2)
    check(not t.delete_column(0), 'deleteColumn fails')
    check(t.cols_len == 1, 'colsLen=1')

def test_duplicate_row():
    print('Test: duplicateRow')
    t = MockTableNode(3, 2)
    check(t.duplicate_row(0), 'duplicateRow(0) succeeds')
    check(t.rows_len == 3, 'rowsLen=3')
    check(len(t.children) == 9, '9 cells')
    check_empty(t.validate(), 'valid after duplicateRow')

def test_duplicate_row_middle():
    print('Test: duplicateRow (middle)')
    t = MockTableNode(2, 3)
    check(t.duplicate_row(1), 'duplicateRow(1) succeeds')
    check(t.rows_len == 4, 'rowsLen=4')
    check(t.get_cell_node(0, 0).row_position == 0, 'row 0 stays')
    check(t.get_cell_node(0, 1).row_position == 1, 'row 1 stays')
    check(t.get_cell_node(0, 2).row_position == 2, 'duplicated row 2')
    check(t.get_cell_node(0, 3).row_position == 3, 'old row 2 -> row 3')
    check_empty(t.validate(), 'valid after duplicateRow middle')

def test_mixed():
    print('Test: mixed operations')
    t = MockTableNode(2, 2)
    t.add_row(0);    check_empty(t.validate(), 'valid: addRow')
    t.add_column(1); check_empty(t.validate(), 'valid: addColumn')
    t.delete_row(1); check_empty(t.validate(), 'valid: deleteRow')
    t.duplicate_row(0); check_empty(t.validate(), 'valid: duplicateRow')
    t.delete_column(0); check_empty(t.validate(), 'valid: deleteColumn')
    check(len(t.children) == 6, '6 cells final')

def test_edge_cases():
    print('Test: edge cases')
    t = MockTableNode(1, 1)
    check_empty(t.validate(), '1x1 valid')
    t.add_row(0); check(t.rows_len == 2, '1x1->1x2')
    check_empty(t.validate(), '1x2 valid')

    t2 = MockTableNode(10, 10)
    check_empty(t2.validate(), '10x10 valid')
    t2.add_row(5); check_empty(t2.validate(), '10x11 valid')
    t2.add_column(3); check_empty(t2.validate(), '11x11 valid')

    t3 = MockTableNode(5, 5)
    for i in range(4, 0, -1):
        t3.delete_row(i); check_empty(t3.validate(), f'valid: delete row {i}')
    for i in range(4, 0, -1):
        t3.delete_column(i); check_empty(t3.validate(), f'valid: delete col {i}')
    check(t3.cols_len == 1 and t3.rows_len == 1, 'final 1x1')

def test_stress():
    print('Test: stress (20x20)')
    t = MockTableNode(20, 20)
    check_empty(t.validate(), '20x20 valid')
    for i in range(10):
        t.add_row(i * 2); check_empty(t.validate(), f'valid: add_row {i}')
    for i in range(10):
        t.add_column(i * 2); check_empty(t.validate(), f'valid: add_col {i}')
    check(t.cols_len == 30 and t.rows_len == 30, '30x30')

if __name__ == '__main__':
    print('=== Table Operations Unit Tests ===\n')
    test_get_cell_node()
    test_add_row()
    test_add_row_middle()
    test_add_row_above()
    test_add_row_above_first()
    test_add_row_above_last()
    test_delete_row()
    test_delete_row_last()
    test_add_column()
    test_add_column_middle()
    test_delete_column()
    test_delete_column_last()
    test_duplicate_row()
    test_duplicate_row_middle()
    test_mixed()
    test_edge_cases()
    test_stress()
    print(f'\n=== Results: {passed}/{total} passed, {failed} failed ===')
    if failed:
        print('SOME TESTS FAILED!')
        exit(1)
    else:
        print('ALL TESTS PASSED!')
