import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/order_model.dart';
import '../core/utils/currency_formatter.dart';

/// Supported thermal printer roll widths and ESC/POS column constraints.
enum PrinterPaperWidth {
  mm58(name: '58mm', columns: 32, label: '58mm (32 cols • Boi Mela Standard)'),
  mm80(name: '80mm', columns: 48, label: '80mm (48 cols • Desktop Standard)');

  final String name;
  final int columns;
  final String label;

  const PrinterPaperWidth({
    required this.name,
    required this.columns,
    required this.label,
  });
}

/// Represents a paired or discovered Bluetooth ESC/POS thermal printer.
class BluetoothPrinterDevice {
  final String name;
  final String address;
  final bool isDefault;

  const BluetoothPrinterDevice({
    required this.name,
    required this.address,
    this.isDefault = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothPrinterDevice &&
          runtimeType == other.runtimeType &&
          address == other.address;

  @override
  int get hashCode => address.hashCode;
}

/// State representation for Bluetooth thermal printer connection and spooling.
class PrinterState {
  final bool isConnected;
  final BluetoothPrinterDevice? selectedDevice;
  final PrinterPaperWidth paperWidth;
  final bool isPrinting;
  final List<BluetoothPrinterDevice> availableDevices;
  final DateTime? lastPrintedAt;
  final String? lastPrintReceiptText;

  const PrinterState({
    this.isConnected = true,
    this.selectedDevice = const BluetoothPrinterDevice(
      name: 'POS-58BT',
      address: '66:32:B1:8A:22:90',
      isDefault: true,
    ),
    this.paperWidth = PrinterPaperWidth.mm58,
    this.isPrinting = false,
    this.availableDevices = const [
      BluetoothPrinterDevice(
        name: 'POS-58BT',
        address: '66:32:B1:8A:22:90',
        isDefault: true,
      ),
      BluetoothPrinterDevice(
        name: 'MPT-II Thermal',
        address: '00:11:22:33:44:55',
      ),
      BluetoothPrinterDevice(
        name: 'RPP02N Mobile',
        address: '88:6B:6E:12:34:56',
      ),
    ],
    this.lastPrintedAt,
    this.lastPrintReceiptText,
  });

  PrinterState copyWith({
    bool? isConnected,
    BluetoothPrinterDevice? selectedDevice,
    bool clearDevice = false,
    PrinterPaperWidth? paperWidth,
    bool? isPrinting,
    List<BluetoothPrinterDevice>? availableDevices,
    DateTime? lastPrintedAt,
    String? lastPrintReceiptText,
  }) {
    return PrinterState(
      isConnected: isConnected ?? this.isConnected,
      selectedDevice:
          clearDevice ? null : (selectedDevice ?? this.selectedDevice),
      paperWidth: paperWidth ?? this.paperWidth,
      isPrinting: isPrinting ?? this.isPrinting,
      availableDevices: availableDevices ?? this.availableDevices,
      lastPrintedAt: lastPrintedAt ?? this.lastPrintedAt,
      lastPrintReceiptText: lastPrintReceiptText ?? this.lastPrintReceiptText,
    );
  }
}

/// State notifier managing printer pairing, paper width, and ESC/POS print simulation.
class PrinterNotifier extends StateNotifier<PrinterState> {
  final Duration simulationDelay;

  PrinterNotifier({
    this.simulationDelay = const Duration(milliseconds: 600),
  }) : super(const PrinterState());

  /// Toggles connection state.
  void toggleConnection() {
    state = state.copyWith(isConnected: !state.isConnected);
  }

  /// Sets printer connection to true.
  void connect() {
    state = state.copyWith(isConnected: true);
  }

  /// Sets printer connection to false.
  void disconnect() {
    state = state.copyWith(isConnected: false);
  }

  /// Sets paper roll width (58mm 32-col or 80mm 48-col).
  void setPaperWidth(PrinterPaperWidth width) {
    state = state.copyWith(paperWidth: width);
  }

  /// Selects a paired Bluetooth printer device.
  void selectDevice(BluetoothPrinterDevice device) {
    state = state.copyWith(
      selectedDevice: device,
      isConnected: true,
    );
  }

  /// Generates and transmits a simulated ESC/POS test receipt.
  /// Returns `true` if transmission succeeded, or `false` if printer is disconnected.
  Future<bool> printTestReceipt([Duration? overrideDelay]) async {
    if (!state.isConnected) return false;

    state = state.copyWith(isPrinting: true);

    // Simulate ESC/POS Bluetooth data transmission buffer delay
    final delay = overrideDelay ?? simulationDelay;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    final sep = state.paperWidth == PrinterPaperWidth.mm58
        ? '--------------------------------'
        : '------------------------------------------------';

    final now = DateTime.now();
    final receiptText = [
      'মেটাপস বুক ফেয়ার স্টল',
      'Amar Ekushey Boi Mela • Dhaka',
      sep,
      '*** TEST RECEIPT / টেস্ট রসিদ ***',
      'Printer: ${state.selectedDevice?.name ?? "ESC/POS"}',
      'Address: ${state.selectedDevice?.address ?? "N/A"}',
      'Paper: ${state.paperWidth.name} (${state.paperWidth.columns} Columns)',
      'Rasterization: 203 DPI Bangla OK',
      sep,
      'Status: CONNECTED & READY',
      'Timestamp: ${now.toIso8601String()}',
      sep,
      'MetaPOS BD • metaposbd.com',
    ].join('\n');

    state = state.copyWith(
      isPrinting: false,
      lastPrintedAt: now,
      lastPrintReceiptText: receiptText,
    );

    return true;
  }

  /// Transmits thermal receipt for [order] to connected ESC/POS printer.
  Future<bool> printOrderReceipt(OrderModel order, [Duration? overrideDelay]) async {
    if (!state.isConnected) return false;

    state = state.copyWith(isPrinting: true);

    final delay = overrideDelay ?? simulationDelay;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    final sep = state.paperWidth == PrinterPaperWidth.mm58
        ? '--------------------------------'
        : '------------------------------------------------';

    final linesText = order.lines.map((l) {
      final name = l.productName;
      final qty = l.qty.toInt();
      final total = CurrencyFormatter.formatBDT(l.priceSubtotalIncl);
      return '$name x $qty: $total';
    }).join('\n');

    final receiptText = [
      'মেটাপস বুক ফেয়ার স্টল',
      'বাংলা একাডেমি প্রাঙ্গণ, ঢাকা',
      sep,
      'Date: ${order.createdAt.toIso8601String().substring(0, 16)}',
      'Ref: ${order.posReference}',
      'Ticket: ${order.ticketCode}',
      sep,
      linesText,
      sep,
      'Subtotal: ${CurrencyFormatter.formatBDT(order.amountTotal)}',
      'Tax (10%): ${CurrencyFormatter.formatBDT(order.amountTax)}',
      'TOTAL: ${CurrencyFormatter.formatBDT(order.amountTotal)}',
      sep,
      'ধন্যবাদ! আবার আসবেন।',
    ].join('\n');

    state = state.copyWith(
      isPrinting: false,
      lastPrintedAt: DateTime.now(),
      lastPrintReceiptText: receiptText,
    );

    return true;
  }
}

/// Global provider for Bluetooth thermal printer state and actions.
final printerProvider =
    StateNotifierProvider<PrinterNotifier, PrinterState>((ref) {
  return PrinterNotifier();
});
