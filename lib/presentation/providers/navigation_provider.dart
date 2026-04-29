import 'package:flutter_riverpod/legacy.dart';

/// Provider do índice do tab ativo.
final currentTabProvider = StateProvider<int>((ref) => 0);
