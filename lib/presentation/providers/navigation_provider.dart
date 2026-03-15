import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider do índice do tab ativo.
final currentTabProvider = StateProvider<int>((ref) => 0);
