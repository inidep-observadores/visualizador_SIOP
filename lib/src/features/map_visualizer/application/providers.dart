import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:siop_data_visualizer/src/features/map_visualizer/data/services/excel_parser.dart';

part 'providers.g.dart';

/// Provider to hold the parsed Excel data.
///
/// It holds a list of maps, where each map represents a row in the Excel sheet.
/// The value is nullable, indicating that no data has been loaded yet.
@Riverpod(keepAlive: true)
class ExcelData extends _$ExcelData {
  @override
  Future<List<Map<String, dynamic>>?> build() async {
    // No data loaded initially.
    return null;
  }

  /// Loads and parses an Excel file from the given [path].
  ///
  /// Updates the state to loading, then to data/error upon completion.
  Future<void> loadFromFile(String path) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ExcelParser.parseFile(path));
  }
}
