part of datagrid;

class _RowGenerator {
  _RowGenerator({required _DataGridStateDetails dataGridStateDetails}) {
    _dataGridStateDetails = dataGridStateDetails;
    items = <DataRowBase>[];
  }

  late List<DataRowBase> items;

  _DataGridStateDetails get dataGridStateDetails => _dataGridStateDetails;
  late _DataGridStateDetails _dataGridStateDetails;

  _VisualContainerHelper get container => dataGridStateDetails().container;

  void _preGenerateRows(_VisibleLinesCollection? visibleRows,
      _VisibleLinesCollection? visibleColumns) {
    if (items.isNotEmpty || dataGridStateDetails().container.rowCount <= 0) {
      return;
    }

    if (visibleRows != null && visibleColumns != null) {
      for (int i = 0; i < visibleRows.length; i++) {
        _VisibleLineInfo? line = visibleRows[i];
        late DataRowBase? dr;
        switch (line.region) {
          case _ScrollAxisRegion.header:
            dr = _createHeaderRow(line.lineIndex, visibleColumns);
            break;
          case _ScrollAxisRegion.body:
            dr = _createDataRow(line.lineIndex, visibleColumns);
            break;
          case _ScrollAxisRegion.footer:
            dr = _createFooterRow(line.lineIndex, visibleColumns);
            break;
        }

        items.add(dr);
        dr = null;
        line = null;
      }
    }
  }

  void _ensureRows(_VisibleLinesCollection visibleRows,
      _VisibleLinesCollection visibleColumns) {
    List<int>? actualStartAndEndIndex = <int>[];
    RowRegion? region = RowRegion.header;

    List<DataRowBase> reUseRows() => items
        .where((DataRowBase row) =>
            (row.rowIndex < 0 ||
                row.rowIndex < actualStartAndEndIndex![0] ||
                row.rowIndex > actualStartAndEndIndex[1]) &&
            !row._isEnsured &&
            !row._isEditing)
        .toList(growable: false);

    for (final DataRowBase row in items) {
      row._isEnsured = false;
    }

    for (int i = 0; i < 3; i++) {
      if (i == 0) {
        region = RowRegion.header;
        actualStartAndEndIndex = container._getStartEndIndex(visibleRows, i);
      } else if (i == 1) {
        region = RowRegion.body;
        actualStartAndEndIndex = container._getStartEndIndex(visibleRows, i);
      } else {
        region = RowRegion.footer;
        actualStartAndEndIndex = container._getStartEndIndex(visibleRows, i);
      }

      for (int index = actualStartAndEndIndex[0];
          index <= actualStartAndEndIndex[1];
          index++) {
        DataRowBase? dr = _indexer(index);
        if (dr == null) {
          List<DataRowBase>? rows = reUseRows();
          if (rows.isNotEmpty) {
            _updateRow(rows, index, region);
            rows = null;
          }
        }

        dr ??=
            items.firstWhereOrNull((DataRowBase row) => row.rowIndex == index);

        if (dr != null) {
          if (!dr._isVisible) {
            dr._isVisible = true;
          }

          dr._isEnsured = true;
        } else {
          if (region == RowRegion.header) {
            dr = _createHeaderRow(index, visibleColumns);
          } else {
            dr = _createDataRow(index, visibleColumns);
          }

          dr._isEnsured = true;
          items.add(dr);
        }

        dr = null;
      }
    }

    for (final DataRowBase row in items) {
      if (!row._isEnsured || row.rowIndex == -1) {
        row._isVisible = false;
      }
    }

    actualStartAndEndIndex = null;
    region = null;
  }

  void _ensureColumns(_VisibleLinesCollection visibleColumns) {
    for (final DataRowBase row in items) {
      row._ensureColumns(visibleColumns);
    }
  }

  DataRowBase _createDataRow(
      int rowIndex, _VisibleLinesCollection visibleColumns,
      {RowRegion rowRegion = RowRegion.body}) {
    final _DataGridSettings dataGridSettings = dataGridStateDetails();
    DataRow dr;
    if (_GridIndexResolver.isFooterWidgetRow(rowIndex, dataGridSettings)) {
      dr = DataRow()
        .._dataGridStateDetails = dataGridStateDetails
        ..rowIndex = rowIndex
        ..rowRegion = rowRegion
        ..rowType = RowType.footerRow;
      dr._key = ObjectKey(dr);
      dr._footerView = _buildFooterWidget(dataGridSettings, rowIndex);
      return dr;
    } else {
      dr = DataRow()
        .._dataGridStateDetails = dataGridStateDetails
        ..rowIndex = rowIndex
        ..rowRegion = rowRegion
        ..rowType = RowType.dataRow;
      dr._key = ObjectKey(dr);
      dr
        .._dataGridRow =
            _SfDataGridHelper.getDataGridRow(dataGridSettings, rowIndex)
        .._dataGridRowAdapter = _SfDataGridHelper.getDataGridRowAdapter(
            dataGridSettings, dr._dataGridRow!);
      assert(_SfDataGridHelper.debugCheckTheLength(
          dataGridSettings.columns.length,
          dr._dataGridRowAdapter!.cells.length,
          'SfDataGrid.columns.length == DataGridRowAdapter.cells.length'));
      _checkForCurrentRow(dr);
      _checkForSelection(dr);
      dr._initializeDataRow(visibleColumns);
      return dr;
    }
  }

  DataRowBase _createHeaderRow(
      int rowIndex, _VisibleLinesCollection visibleColumns) {
    final _DataGridSettings dataGridSettings = dataGridStateDetails();
    DataRowBase dr;
    if (rowIndex == _GridIndexResolver.getHeaderIndex(dataGridSettings)) {
      dr = DataRow()
        .._dataGridStateDetails = dataGridStateDetails
        ..rowIndex = rowIndex
        ..rowRegion = RowRegion.header
        ..rowType = RowType.headerRow;
      dr
        .._key = ObjectKey(dr)
        .._initializeDataRow(visibleColumns);
      return dr;
    } else if (rowIndex < dataGridSettings.stackedHeaderRows.length) {
      dr = _SpannedDataRow();
      dr._key = ObjectKey(dr);
      dr.rowIndex = rowIndex;
      dr._dataGridStateDetails = dataGridStateDetails;
      dr.rowRegion = RowRegion.header;
      dr.rowType = RowType.stackedHeaderRow;
      _createStackedHeaderCell(
          dataGridSettings.stackedHeaderRows[rowIndex], rowIndex);
      dr._initializeDataRow(visibleColumns);
      return dr;
    } else {
      return _createDataRow(rowIndex, visibleColumns,
          rowRegion: RowRegion.header);
    }
  }

  void _createStackedHeaderCell(StackedHeaderRow header, int rowIndex) {
    final _DataGridSettings dataGridSettings = dataGridStateDetails();
    for (final StackedHeaderCell column in header.cells) {
      final List<int> childSequence = _StackedHeaderHelper._getChildSequence(
          dataGridSettings, column, rowIndex);
      childSequence.sort();
      column._childColumnIndexes = childSequence;
    }
  }

  DataRowBase _createFooterRow(
      int rowIndex, _VisibleLinesCollection visibleColumns) {
    return _createDataRow(rowIndex, visibleColumns,
        rowRegion: RowRegion.footer);
  }

  Widget? _buildFooterWidget(_DataGridSettings dataGridSettings, int rowIndex) {
    if (dataGridSettings.footer == null) {
      return null;
    }

    BoxDecoration drawBorder() {
      final SfDataGridThemeData themeData = dataGridSettings.dataGridThemeData!;
      final GridLinesVisibility gridLinesVisibility =
          dataGridSettings.gridLinesVisibility;

      final bool canDrawHorizontalBorder =
          gridLinesVisibility == GridLinesVisibility.horizontal ||
              gridLinesVisibility == GridLinesVisibility.both;
      final bool canDrawVerticalBorder =
          gridLinesVisibility == GridLinesVisibility.vertical ||
              gridLinesVisibility == GridLinesVisibility.both;

      final bool canDrawTopFrozenBorder = dataGridSettings
              .footerFrozenRowsCount.isFinite &&
          dataGridSettings.footerFrozenRowsCount > 0 &&
          _GridIndexResolver.getStartFooterFrozenRowIndex(dataGridSettings) ==
              rowIndex;

      return BoxDecoration(
        border: BorderDirectional(
          top: canDrawTopFrozenBorder && themeData.frozenPaneElevation <= 0.0
              ? BorderSide(
                  color: themeData.frozenPaneLineColor,
                  width: themeData.frozenPaneLineWidth)
              : BorderSide.none,
          bottom: canDrawHorizontalBorder
              ? BorderSide(
                  color: themeData.gridLineColor,
                  width: themeData.gridLineStrokeWidth)
              : BorderSide.none,
          end: canDrawVerticalBorder
              ? BorderSide(
                  color: themeData.gridLineColor,
                  width: themeData.gridLineStrokeWidth)
              : BorderSide.none,
        ),
      );
    }

    return Container(
        decoration: drawBorder(),
        clipBehavior: Clip.antiAlias,
        child: dataGridSettings.footer);
  }

  DataRowBase? _indexer(int index) {
    for (int i = 0; i < items.length; i++) {
      if (items[i].rowIndex == index) {
        return items[i];
      }
    }

    return null;
  }

  void _updateRow(List<DataRowBase> rows, int index, RowRegion region) {
    final _DataGridSettings dataGridSettings = dataGridStateDetails();
    DataRowBase? dr;
    if (region == RowRegion.header) {
      if (index == _GridIndexResolver.getHeaderIndex(dataGridSettings)) {
        dr = rows.firstWhereOrNull(
            (DataRowBase row) => row.rowType == RowType.headerRow);
        if (dr != null) {
          dr
            .._key = dr._key
            ..rowIndex = index
            .._dataGridStateDetails = dataGridStateDetails
            ..rowRegion = RowRegion.header
            ..rowType = RowType.headerRow
            .._rowIndexChanged();
          dr = null;
        } else {
          dr = _createHeaderRow(
              index, _SfDataGridHelper.getVisibleLines(dataGridStateDetails()));
          items.add(dr);
          dr = null;
        }
      } else if (index < dataGridSettings.stackedHeaderRows.length) {
        dr = rows.firstWhereOrNull(
            (DataRowBase r) => r.rowType == RowType.stackedHeaderRow);
        if (dr != null) {
          dr._key = dr._key;
          dr.rowIndex = index;
          _dataGridStateDetails = dataGridStateDetails;
          dr.rowRegion = RowRegion.header;
          dr.rowType = RowType.stackedHeaderRow;
          dr._rowIndexChanged();
          _createStackedHeaderCell(
              dataGridSettings.stackedHeaderRows[index], index);
          dr._initializeDataRow(
              dataGridSettings.container.scrollRows.getVisibleLines());
        } else {
          dr = _createHeaderRow(
              index, _SfDataGridHelper.getVisibleLines(dataGridStateDetails()));
          items.add(dr);
          dr = null;
        }
      } else {
        _updateDataRow(rows, index, region, dataGridSettings);
      }
    } else if (_GridIndexResolver.isFooterWidgetRow(index, dataGridSettings)) {
      dr = rows
          .firstWhereOrNull((DataRowBase r) => r.rowType == RowType.footerRow);
      if (dr != null) {
        dr
          .._key = dr._key
          ..rowIndex = index
          ..rowRegion = region
          ..rowType = RowType.footerRow;
        dr._footerView = _buildFooterWidget(dataGridSettings, index);
      } else {
        dr = _createDataRow(
            index, _SfDataGridHelper.getVisibleLines(dataGridStateDetails()));
        items.add(dr);
        dr = null;
      }
    } else {
      _updateDataRow(rows, index, region, dataGridSettings);
    }
  }

  void _updateDataRow(List<DataRowBase> rows, int index, RowRegion region,
      _DataGridSettings dataGridSettings) {
    DataRowBase? row = rows.firstWhereOrNull(
        (DataRowBase row) => row is DataRow && row.rowType == RowType.dataRow);

    if (row != null && row is DataRow) {
      if (index < 0 || index >= container.scrollRows.lineCount) {
        row._isVisible = false;
      } else {
        row
          .._key = row._key
          ..rowIndex = index
          ..rowRegion = region
          .._dataGridRow =
              _SfDataGridHelper.getDataGridRow(dataGridSettings, index)
          .._dataGridRowAdapter = _SfDataGridHelper.getDataGridRowAdapter(
              dataGridSettings, row._dataGridRow!);
        assert(_SfDataGridHelper.debugCheckTheLength(
            dataGridSettings.columns.length,
            row._dataGridRowAdapter!.cells.length,
            'SfDataGrid.columns.length == DataGridRowAdapter.cells.length'));
        _checkForCurrentRow(row);
        _checkForSelection(row);
        row._rowIndexChanged();
      }
      row = null;
    } else {
      DataRowBase? dr = _createDataRow(
          index, _SfDataGridHelper.getVisibleLines(dataGridStateDetails()));
      items.add(dr);
      dr = null;
    }
  }

  double _queryRowHeight(int rowIndex, double height) {
    final _DataGridSettings dataGridSettings = dataGridStateDetails();
    double rowHeight = height;
    if (dataGridSettings.onQueryRowHeight != null) {
      final RowHeightDetails details = RowHeightDetails(rowIndex, height)
        .._columnSizer = dataGridSettings.columnSizer;
      rowHeight = dataGridSettings.onQueryRowHeight!(details);
    }

    return rowHeight;
  }

  void _checkForSelection(DataRowBase row) {
    final _DataGridSettings dataGridSettings = dataGridStateDetails();
    if (dataGridSettings.selectionMode != SelectionMode.none) {
      final RowSelectionManager rowSelectionManager =
          dataGridSettings.rowSelectionManager as RowSelectionManager;
      final int recordIndex = _GridIndexResolver.resolveToRecordIndex(
          dataGridSettings, row.rowIndex);
      final DataGridRow record =
          dataGridSettings.source._effectiveRows[recordIndex];
      row._isSelectedRow = rowSelectionManager._selectedRows.contains(record);
    }
  }

  void _checkForCurrentRow(DataRow dr) {
    final _DataGridSettings dataGridSettings = dataGridStateDetails();
    if (dataGridSettings.navigationMode == GridNavigationMode.cell) {
      final _CurrentCellManager currentCellManager =
          dataGridSettings.currentCell;

      DataCellBase? getDataCell() {
        if (dr._visibleColumns.isEmpty) {
          return null;
        }

        final DataCellBase? dc = dr._visibleColumns.firstWhereOrNull(
            (DataCellBase dataCell) =>
                dataCell.columnIndex == currentCellManager.columnIndex);
        return dc;
      }

      if (currentCellManager.rowIndex != -1 &&
          currentCellManager.columnIndex != -1 &&
          currentCellManager.rowIndex == dr.rowIndex) {
        final DataCellBase? dataCell = getDataCell();
        currentCellManager._setCurrentCellDirty(dr, dataCell, true);
      } else if (dr.isCurrentRow) {
        final DataCellBase? dataCell = getDataCell();
        currentCellManager._setCurrentCellDirty(dr, dataCell, false);
      } else {
        dr.isCurrentRow = false;
      }
    }
  }
}
