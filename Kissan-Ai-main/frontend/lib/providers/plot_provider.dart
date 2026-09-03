import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';

/// Immutable state for plot management.
class PlotState {
  const PlotState({
    this.plots = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Map<String, dynamic>> plots;
  final bool isLoading;
  final String? error;

  PlotState copyWith({
    List<Map<String, dynamic>>? plots,
    bool? isLoading,
    String? error,
  }) =>
      PlotState(
        plots: plots ?? this.plots,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

/// Riverpod StateNotifier managing the farmer's plot list.
///
/// Exposes CRUD operations that call the backend through [ApiClient]
/// and keeps the UI in sync via immutable state snapshots.
class PlotNotifier extends StateNotifier<PlotState> {
  PlotNotifier({ApiClient? api})
      : _api = api ?? ApiClient.instance,
        super(const PlotState());

  final ApiClient _api;

  // ── Read ──────────────────────────────────────────────────

  /// Fetch all plots for the current user.
  Future<void> fetchPlots() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.getPlots();
      final list = (res.data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      state = state.copyWith(plots: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load plots: $e',
      );
    }
  }

  // ── Create ────────────────────────────────────────────────

  /// Create a new plot and prepend it to the list.
  Future<bool> createPlot({
    required String name,
    String? location,
    double? areaHectares,
    String? soilType,
    double? latitude,
    double? longitude,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.createPlot(
        name: name,
        location: location,
        areaHectares: areaHectares,
        soilType: soilType,
        latitude: latitude,
        longitude: longitude,
      );
      final newPlot = Map<String, dynamic>.from(res.data as Map);
      state = state.copyWith(
        plots: [newPlot, ...state.plots],
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to create plot: $e',
      );
      return false;
    }
  }

  // ── Update ────────────────────────────────────────────────

  /// Update an existing plot in-place.
  Future<bool> updatePlot(String plotId, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.updatePlot(plotId, data);
      final updated = Map<String, dynamic>.from(res.data as Map);
      final idx = state.plots.indexWhere((p) => p['id'].toString() == plotId);
      final list = List<Map<String, dynamic>>.from(state.plots);
      if (idx != -1) {
        list[idx] = updated;
      }
      state = state.copyWith(plots: list, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update plot: $e',
      );
      return false;
    }
  }

  // ── Delete ────────────────────────────────────────────────

  /// Delete a plot by id.
  Future<bool> deletePlot(String plotId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _api.deletePlot(plotId);
      final list =
          state.plots.where((p) => p['id'].toString() != plotId).toList();
      state = state.copyWith(plots: list, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete plot: $e',
      );
      return false;
    }
  }

  /// Clear any error message.
  void clearError() => state = state.copyWith(error: null);
}

final plotProvider =
    StateNotifierProvider<PlotNotifier, PlotState>((ref) => PlotNotifier());
