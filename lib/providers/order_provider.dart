import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/order_model.dart';

/// Holds the most recently validated & submitted order for receipt display, thermal printing, and verification.
final lastCompletedOrderProvider = StateProvider<OrderModel?>((ref) => null);
