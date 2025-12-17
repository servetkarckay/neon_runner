import 'dart:collection';
import 'package:flutter/painting.dart';
import 'package:flutter_neon_runner/game/collision/collision_types.dart';

/// Spatial hash grid for efficient broad-phase collision detection
class SpatialHash {
  final double cellSize;
  final Map<String, Set<CollidableEntity>> _cells;
  final Map<String, String> _entityCellMap;

  SpatialHash({
    required this.cellSize,
  }) : _cells = HashMap(),
       _entityCellMap = HashMap();

  /// Inserts an entity into the spatial hash
  void insert(CollidableEntity entity) {
    final cells = _getCellsForBounds(entity.bounds);
    final cellKey = cells.join(',');

    // Remove entity from previous cells if it exists
    remove(entity);

    // Add entity to all cells it occupies
    for (final cell in cells) {
      _cells.putIfAbsent(cell, () => HashSet()).add(entity);
    }

    _entityCellMap[entity.id] = cellKey;
  }

  /// Removes an entity from the spatial hash
  void remove(CollidableEntity entity) {
    final cellKey = _entityCellMap[entity.id];
    if (cellKey != null) {
      final cells = cellKey.split(',');
      for (final cell in cells) {
        _cells[cell]?.remove(entity);
        if (_cells[cell]?.isEmpty == true) {
          _cells.remove(cell);
        }
      }
      _entityCellMap.remove(entity.id);
    }
  }

  /// Queries for potential collision candidates within the given bounds
  List<CollidableEntity> query(Rect bounds) {
    final candidates = <CollidableEntity>{};
    final cells = _getCellsForBounds(bounds);

    for (final cell in cells) {
      final cellEntities = _cells[cell];
      if (cellEntities != null) {
        candidates.addAll(cellEntities);
      }
    }

    return candidates.toList();
  }

  /// Clears all entities from the spatial hash
  void clear() {
    _cells.clear();
    _entityCellMap.clear();
  }

  /// Gets the number of cells currently in use
  int get cellCount => _cells.length;

  /// Gets debug information about the spatial hash
  SpatialHashDebugInfo get debugInfo {
    final entityCounts = _cells.values.map((cell) => cell.length);
    return SpatialHashDebugInfo(
      cellCount: _cells.length,
      totalEntities: _entityCellMap.length,
      averageEntitiesPerCell: entityCounts.isEmpty ? 0.0 : entityCounts.reduce((a, b) => a + b) / entityCounts.length,
      maxEntitiesPerCell: entityCounts.isEmpty ? 0 : entityCounts.reduce((a, b) => a > b ? a : b),
    );
  }

  /// Gets the cell coordinates that intersect with the given bounds
  List<String> _getCellsForBounds(Rect bounds) {
    final cells = <String>[];

    final startX = (bounds.left / cellSize).floor();
    final startY = (bounds.top / cellSize).floor();
    final endX = (bounds.right / cellSize).floor();
    final endY = (bounds.bottom / cellSize).floor();

    for (var y = startY; y <= endY; y++) {
      for (var x = startX; x <= endX; x++) {
        cells.add('${x}_$y');
      }
    }

    return cells;
  }
}

/// Debug information for the spatial hash
class SpatialHashDebugInfo {
  final int cellCount;
  final int totalEntities;
  final double averageEntitiesPerCell;
  final int maxEntitiesPerCell;

  SpatialHashDebugInfo({
    required this.cellCount,
    required this.totalEntities,
    required this.averageEntitiesPerCell,
    required this.maxEntitiesPerCell,
  });

  @override
  String toString() {
    return 'SpatialHashDebugInfo('
        'cellCount: $cellCount, '
        'totalEntities: $totalEntities, '
        'averageEntitiesPerCell: ${averageEntitiesPerCell.toStringAsFixed(2)}, '
        'maxEntitiesPerCell: $maxEntitiesPerCell'
        ')';
  }
}