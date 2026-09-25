import 'dart:developer';
import 'dart:io';

import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/on_demand_order_details_controller.dart';
import 'package:customer/controllers/order_details_controller.dart';
import 'package:customer/models/cart_product_model.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/models/onprovider_order_model.dart';
import 'package:customer/models/order_model.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/region_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Printable / shareable PDF receipt of an order (spec 7.6): logo, order
/// number + Code 128 barcode, date, parties, items with the prices actually
/// charged (wholesale lines marked), taxes, the commission-inclusive total
/// paid, payment method and status - all in the ORDER's currency (its own
/// regionId). Figures come from the order details controllers (the same values
/// the screen shows); nothing is re-derived. Layout/encoder ported from the
/// Store app (vendor/lib/utils/order_receipt_pdf.dart).
class OrderReceiptPdf {
  OrderReceiptPdf._();

  // ---------------- receipt or order summary ----------------

  /// Cancelled and rejected orders are **never headed "Receipt"** - not on
  /// the button, not in the document, not in the file name (WEB spec 8).
  /// Those orders were never paid for, and a document headed Receipt would be
  /// passed on as though they had been.
  ///
  /// "Driver Rejected" is not one of them: the order is back with dispatch and
  /// still live.
  static bool isVoidedStatus(String? status) {
    final String s = (status ?? '').trim().toLowerCase();
    if (s.isEmpty) return false;
    if (s == Constant.driverRejected.toLowerCase()) return false;
    return s.contains('cancel') || s.contains('reject');
  }

  /// "Receipt", or "Order Summary" for a cancelled / rejected order.
  static String documentTitle(String? status) => isVoidedStatus(status) ? "Order Summary".tr : "Receipt".tr;

  // ---------------- entry points ----------------

  /// Bottom sheet with "Share" (WhatsApp, email ... via the share sheet) and
  /// "Download". The receipt is resolved first so both rows can be named for
  /// what the document actually is (WEB spec 8).
  static Future<void> showOptions(BuildContext context, Future<ReceiptData> Function() data) async {
    final ReceiptData receipt = await data();
    if (!context.mounted) return;
    final String what = receipt.documentTitle;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.share_outlined, color: AppThemeData.primary300),
                  title: Text("${"Share".tr} $what ${"(WhatsApp, email...)".tr}"),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await share(receipt);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.download_outlined, color: AppThemeData.primary300),
                  title: Text("${"Download".tr} $what (PDF)"),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await download(receipt);
                  },
                ),
                ListTile(leading: const Icon(Icons.close, color: Colors.grey), title: Text("Cancel".tr), onTap: () => Navigator.pop(ctx)),
              ],
            ),
          ),
    );
  }

  static Future<void> share(ReceiptData data) async {
    final File? file = await _save(data);
    if (file == null) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: "${data.documentTitle} ${data.orderLabel}",
          text: "${data.partyName} - ${data.documentTitle} ${data.orderLabel}".trim(),
        ),
      );
    } catch (e) {
      log("Receipt share failed: $e");
      ShowToastDialog.showToast("Could not share the document.".tr);
    }
  }

  static Future<void> download(ReceiptData data) async {
    final File? file = await _save(data);
    if (file == null) return;
    // The documents directory is private to the app; on Android also drop a
    // copy in the public Download folder (as the Store app does).
    if (Platform.isAndroid) {
      try {
        final Directory downloads = Directory('/storage/emulated/0/Download');
        if (await downloads.exists()) {
          await file.copy('${downloads.path}/${file.uri.pathSegments.last}');
          ShowToastDialog.showToast("${data.documentTitle} ${"downloaded in download folder".tr}");
          return;
        }
      } catch (e) {
        log("Receipt copy to Download failed: $e");
      }
    }
    ShowToastDialog.showToast("${data.documentTitle} ${"saved".tr}");
  }

  static Future<File?> _save(ReceiptData data) async {
    ShowToastDialog.showLoader("Please wait...".tr);
    try {
      final List<int> logo = await _loadLogo(data.logoUrl);
      final List<int> bytes = _build(data, logo);
      final Directory dir = await getApplicationDocumentsDirectory();
      final String orderNo = data.orderId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
      // Never "receipt_..." for an order that was cancelled or rejected.
      final String prefix = data.isOrderSummary ? 'order_summary' : 'receipt';
      final File file = File('${dir.path}/${prefix}_${orderNo.isEmpty ? 'order' : orderNo}.pdf');
      await file.writeAsBytes(bytes, flush: true);
      ShowToastDialog.closeLoader();
      return file;
    } catch (e, s) {
      log("Receipt PDF failed: $e", stackTrace: s);
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Could not create the document. Please try again.".tr);
      return null;
    }
  }

  // ---------------- data from the order screens ----------------

  /// Multivendor / e-commerce order (vendor_orders).
  static Future<ReceiptData> fromOrder(OrderDetailsController c) async {
    await RegionService.ensureLoaded();
    final OrderModel order = c.orderModel.value;
    final CurrencyModel? currency = RegionService.currencyForRecord(order.regionId);
    final List<ReceiptItem> items = [];
    for (final CartProductModel product in order.products ?? <CartProductModel>[]) {
      final double qty = double.tryParse(product.quantity.toString()) ?? 0;
      final double unit = product.unitPrice;
      final List<String> notes = [];
      if (product.isWholesale == true) {
        final String minQty = (product.wholesaleMinQty ?? '').trim();
        notes.add(minQty.isEmpty ? 'Wholesale price'.tr : '${'Wholesale price'.tr} - ${'from'.tr} $minQty ${'pcs'.tr}');
      }
      final Map<String, dynamic>? options = product.variantInfo?.variantOptions?.cast<String, dynamic>();
      if (options != null && options.isNotEmpty) notes.add(options.entries.map((e) => '${e.key}: ${e.value}').join(', '));
      items.add(ReceiptItem(name: product.name ?? '', notes: notes, qty: qty, unit: unit));
      final double extrasUnit = double.tryParse(product.extrasPrice.toString()) ?? 0;
      if ((product.extras ?? []).isNotEmpty && extrasUnit > 0) {
        items.add(ReceiptItem(name: '+ ${'Addons'.tr}', notes: [product.extras!.map((e) => e.toString()).join(', ')], qty: qty, unit: extrasUnit, indent: true));
      }
    }
    final List<ReceiptTotal> totals = [
      ReceiptTotal('Item totals'.tr, c.subTotal.value),
      if (c.couponAmount.value > 0) ReceiptTotal('Coupon discount'.tr, -c.couponAmount.value),
      if (c.specialDiscountAmount.value > 0) ReceiptTotal('Special discount'.tr, -c.specialDiscountAmount.value),
      if (order.takeAway != true) ReceiptTotal('Delivery charge'.tr, c.deliveryCharges.value),
      if (c.deliveryTips.value > 0) ReceiptTotal('Delivery tip'.tr, c.deliveryTips.value),
      if (c.packagingCharge.value > 0) ReceiptTotal('Packaging charge'.tr, c.packagingCharge.value),
      if (c.platformFee.value > 0) ReceiptTotal('Platform fee'.tr, c.platformFee.value),
      if (c.productTaxAmount.value + c.orderTaxAmount.value > 0) ReceiptTotal('Taxes'.tr, c.productTaxAmount.value + c.orderTaxAmount.value),
      if (c.driverDeliveryTaxAmount.value > 0) ReceiptTotal('Delivery tax'.tr, c.driverDeliveryTaxAmount.value),
      if (c.packagingTaxAmount.value > 0) ReceiptTotal('Packaging tax'.tr, c.packagingTaxAmount.value),
      if (c.platformTaxAmount.value > 0) ReceiptTotal('Platform fee tax'.tr, c.platformTaxAmount.value),
    ];
    final String address = order.takeAway == true ? '' : (order.address?.getFullAddress() ?? '');
    return ReceiptData(
      orderId: order.id ?? '',
      orderLabel: '${'Order'.tr} ${Constant.orderId(orderId: order.id.toString())}',
      date: order.createdAt?.toDate(),
      partyTitle: 'Store'.tr,
      partyName: order.vendor?.title ?? '',
      partyAddress: order.vendor?.location ?? '',
      partyPhone: order.vendor?.phonenumber ?? '',
      logoUrl: order.vendor?.photo,
      customerName: order.author?.fullName() ?? '',
      customerPhone: '${order.author?.countryCode ?? ''} ${order.author?.phoneNumber ?? ''}'.trim(),
      customerAddress: address,
      details: [
        MapEntry('Type'.tr, order.takeAway == true ? 'TakeAway'.tr : 'Delivery'.tr),
        MapEntry('Status'.tr, (order.status ?? '').tr),
        MapEntry('Payment method'.tr, paymentLabel(order.paymentMethod)),
      ],
      items: items,
      totals: totals,
      totalPaid: c.totalAmount.value,
      currency: currency,
      status: order.status ?? '',
    );
  }

  /// On-demand booking (provider_orders).
  static Future<ReceiptData> fromProviderOrder(OnDemandOrderDetailsController c) async {
    await RegionService.ensureLoaded();
    final OnProviderOrderModel order = c.onProviderOrder.value!;
    final CurrencyModel? currency = RegionService.currencyForRecord(order.regionId);
    final double qty = order.quantity;
    final double unit = qty > 0 ? c.price.value / qty : c.price.value;
    final double extra = double.tryParse(order.extraCharges ?? '') ?? 0;
    final double platformFee = double.tryParse(order.platformFee ?? '') ?? 0;
    final List<ReceiptTotal> totals = [
      ReceiptTotal('Item totals'.tr, c.price.value),
      if (c.discountAmount.value > 0) ReceiptTotal('Discount'.tr, -c.discountAmount.value),
      if (platformFee > 0) ReceiptTotal('Platform fee'.tr, platformFee),
      if (c.orderTaxAmount.value > 0) ReceiptTotal('Taxes'.tr, c.orderTaxAmount.value),
      if (c.platformTaxAmount.value > 0) ReceiptTotal('Platform fee tax'.tr, c.platformTaxAmount.value),
    ];
    final DateTime date = order.createdAt.toDate();
    return ReceiptData(
      orderId: order.id,
      orderLabel: '${'Booking'.tr} ${Constant.orderId(orderId: order.id)}',
      date: date,
      partyTitle: 'Provider'.tr,
      partyName: c.providerUser.value?.fullName() ?? order.provider.title ?? '',
      partyAddress: order.provider.address ?? '',
      partyPhone: '',
      logoUrl: null,
      customerName: order.author.fullName(),
      customerPhone: '${order.author.countryCode ?? ''} ${order.author.phoneNumber ?? ''}'.trim(),
      customerAddress: order.address?.getFullAddress() ?? '',
      details: [
        if (order.scheduleDateTime != null) MapEntry('Booking date'.tr, DateFormat('MMM dd, yyyy hh:mm aa').format(order.scheduleDateTime!.toDate())),
        MapEntry('Status'.tr, order.status.tr),
        MapEntry('Payment method'.tr, paymentLabel(order.payment_method)),
      ],
      items: [ReceiptItem(name: order.provider.title ?? '', notes: [if ((order.provider.priceUnit ?? '').isNotEmpty) '${'Unit'.tr}: ${order.provider.priceUnit}'], qty: qty, unit: unit)],
      // Extra charges added by the provider after the job, when there are any.
      totals: [...totals, if (extra > 0) ReceiptTotal((order.extraChargesDescription ?? '').isNotEmpty ? '${'Extra charges'.tr} (${order.extraChargesDescription})' : 'Extra charges'.tr, extra)],
      totalPaid: c.totalAmount.value + extra,
      currency: currency,
      status: order.status,
    );
  }

  static String paymentLabel(String? method) {
    if (method == null || method.isEmpty) return '-';
    if (method.toLowerCase() == 'cod') return 'Cash on delivery'.tr;
    return method.capitalizeFirst ?? method;
  }

  static Future<List<int>> _loadLogo(String? url) async {
    if (url != null && url.startsWith('http')) {
      try {
        final HttpClient client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
        final HttpClientRequest request = await client.getUrl(Uri.parse(url));
        final HttpClientResponse response = await request.close().timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final List<int> bytes = await response.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
          client.close();
          if (bytes.isNotEmpty) return bytes;
        }
        client.close();
      } catch (e) {
        log("Receipt logo not loaded: $e");
      }
    }
    try {
      final data = await rootBundle.load('assets/images/ic_logo.png');
      return data.buffer.asUint8List();
    } catch (_) {
      return const [];
    }
  }

  // ---------------- PDF ----------------

  static List<int> _build(ReceiptData d, List<int> logo) {
    String money(double value) => _money(value, d.currency);

    final PdfDocument document = PdfDocument();
    final _Writer w = _Writer(document);

    // Party header (store / provider) with logo.
    final double headerTop = w.y;
    double textLeft = 0;
    if (logo.isNotEmpty) {
      try {
        final PdfBitmap bitmap = PdfBitmap(logo);
        const double size = 56;
        w.page.graphics.drawImage(bitmap, Rect.fromLTWH(0, headerTop, size, size));
        textLeft = size + 12;
      } catch (e) {
        log("Receipt logo not drawable: $e");
      }
    }
    final double partyWidth = w.width - textLeft;
    double ty = headerTop;
    ty += w.textAt(d.partyName, w.titleFont, textLeft, ty, partyWidth) + 2;
    if (d.partyAddress.isNotEmpty) ty += w.textAt(d.partyAddress, w.smallFont, textLeft, ty, partyWidth) + 1;
    if (d.partyPhone.isNotEmpty) ty += w.textAt('${'Phone'.tr}: ${d.partyPhone}', w.smallFont, textLeft, ty, partyWidth);
    w.y = textLeft > 0 ? (ty > headerTop + 56 ? ty : headerTop + 56) : ty;
    w.gap(10);
    w.rule();
    w.gap(8);

    // Order number + barcode. "Order Summary" when the order was cancelled or
    // rejected - it was never paid for (WEB spec 8).
    w.line('${d.documentTitle} - ${d.orderLabel}', w.headingFont);
    w.gap(4);
    if (d.orderId.isNotEmpty) {
      w.barcode(d.orderId, height: 38);
      w.line(d.orderId, w.smallFont);
      w.gap(4);
    }
    if (d.date != null) w.pair('Date'.tr, DateFormat('MMM dd, yyyy hh:mm aa').format(d.date!));
    for (final e in d.details) {
      w.pair(e.key, e.value);
    }
    w.gap(8);

    // Customer.
    w.line('Customer'.tr, w.headingFont);
    if (d.customerName.trim().isNotEmpty) w.line(d.customerName, w.bodyFont);
    if (d.customerPhone.isNotEmpty) w.line(d.customerPhone, w.bodyFont);
    if (d.customerAddress.trim().isNotEmpty) w.line('${'Address'.tr}: ${d.customerAddress}', w.bodyFont);
    w.gap(10);

    // Driver, route, vehicle ... (rides and rentals).
    for (final ReceiptBlock block in d.blocks) {
      if (block.lines.isEmpty) continue;
      w.line(block.title, w.headingFont);
      for (final e in block.lines) {
        w.pair(e.key, e.value);
      }
      w.gap(8);
    }

    // Items (none on a ride: its fare lines are all in the totals).
    if (d.items.isNotEmpty) {
      w.itemHeader(['Item'.tr, 'Qty'.tr, 'Unit price'.tr, 'Total'.tr]);
      for (final ReceiptItem item in d.items) {
        w.itemRow(item.name, item.notes, _qty(item.qty), money(item.unit), money(item.unit * item.qty), indent: item.indent);
      }
      w.gap(4);
    }
    w.rule();
    w.gap(6);

    // Totals.
    for (final ReceiptTotal t in d.totals) {
      w.total(t.label, t.value < 0 ? '- ${money(-t.value)}' : money(t.value));
    }
    w.gap(2);
    w.rule();
    w.gap(4);
    w.total('Total paid'.tr, money(d.totalPaid), bold: true);
    w.gap(16);
    w.line('Thank you for your order!'.tr, w.smallFont, align: PdfTextAlignment.center);

    final List<int> bytes = document.saveSync();
    document.dispose();
    return bytes;
  }

  static String _qty(double qty) => qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(2);

  /// [Constant.amountShow] in the order currency. The standard PDF fonts only
  /// cover Latin-1, so a symbol outside it is written as the currency code.
  static String _money(double value, CurrencyModel? currency) {
    final String shown = Constant.amountShow(currency: currency, amount: value.toString());
    if (!shown.codeUnits.every((u) => u <= 0xFF) && currency != null && currency.code.isNotEmpty) {
      return shown.replaceAll(currency.symbol, currency.code).trim();
    }
    return shown;
  }
}

/// Everything a receipt shows.
class ReceiptData {
  final String orderId;
  final String orderLabel;
  final DateTime? date;
  final String partyTitle;
  final String partyName;
  final String partyAddress;
  final String partyPhone;
  final String? logoUrl;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final List<MapEntry<String, String>> details;
  final List<ReceiptItem> items;
  final List<ReceiptTotal> totals;
  final double totalPaid;
  final CurrencyModel? currency;

  /// The order's own status. Decides whether this document is a receipt or an
  /// order summary (WEB spec 8).
  final String status;

  /// Extra titled blocks printed after the customer (driver, route, vehicle,
  /// rental period ...). Empty for shopping orders.
  final List<ReceiptBlock> blocks;

  /// A cancelled or rejected order is never headed "Receipt".
  bool get isOrderSummary => OrderReceiptPdf.isVoidedStatus(status);

  /// "Receipt" or "Order Summary" - heading, button, share subject and file
  /// name all read this one value.
  String get documentTitle => OrderReceiptPdf.documentTitle(status);

  ReceiptData({
    required this.orderId,
    required this.orderLabel,
    required this.date,
    required this.partyTitle,
    required this.partyName,
    required this.partyAddress,
    required this.partyPhone,
    required this.logoUrl,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.details,
    required this.items,
    required this.totals,
    required this.totalPaid,
    required this.currency,
    this.status = '',
    this.blocks = const [],
  });
}

/// A titled group of label / value lines on the receipt.
class ReceiptBlock {
  final String title;
  final List<MapEntry<String, String>> lines;

  ReceiptBlock(this.title, this.lines);
}

class ReceiptItem {
  final String name;
  final List<String> notes;
  final double qty;
  final double unit;
  final bool indent;

  ReceiptItem({required this.name, required this.notes, required this.qty, required this.unit, this.indent = false});
}

class ReceiptTotal {
  final String label;
  final double value;

  ReceiptTotal(this.label, this.value);
}

/// Top-to-bottom writer with automatic page breaks.
class _Writer {
  final PdfDocument document;
  late PdfPage page;
  double y = 0;

  final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
  final PdfFont headingFont = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
  final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
  final PdfFont boldFont = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
  final PdfFont totalFont = PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold);
  final PdfFont smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8.5);
  final PdfBrush muted = PdfSolidBrush(PdfColor(110, 110, 110));
  final PdfPen rulePen = PdfPen(PdfColor(200, 200, 200), width: 0.7);

  // Item table columns: name | qty | unit price | total.
  static const List<double> _cols = [0.46, 0.10, 0.22, 0.22];

  _Writer(this.document) {
    page = document.pages.add();
  }

  double get width => page.getClientSize().width;

  double get height => page.getClientSize().height;

  void ensure(double needed) {
    if (y + needed > height) {
      page = document.pages.add();
      y = 0;
    }
  }

  void gap(double value) => y += value;

  /// PDF standard fonts only encode Latin-1; anything else becomes "?".
  static String safe(String s) => String.fromCharCodes(s.runes.map((r) => r <= 0xFF ? r : 0x3F));

  double measure(String text, PdfFont font, double w) => font.measureString(safe(text), layoutArea: Size(w, 0)).height;

  double textAt(String text, PdfFont font, double x, double top, double w, {PdfTextAlignment align = PdfTextAlignment.left, PdfBrush? brush}) {
    if (text.isEmpty) return 0;
    final double h = measure(text, font, w);
    page.graphics.drawString(safe(text), font, brush: brush, bounds: Rect.fromLTWH(x, top, w, h), format: PdfStringFormat(alignment: align));
    return h;
  }

  void line(String text, PdfFont font, {PdfTextAlignment align = PdfTextAlignment.left}) {
    final double h = measure(text, font, width);
    ensure(h);
    textAt(text, font, 0, y, width, align: align);
    y += h + (font.size > 11 ? 4 : 3);
  }

  void pair(String label, String value) {
    final double labelW = width * 0.32;
    final double h = [measure(label, bodyFont, labelW), measure(value, bodyFont, width - labelW)].reduce((a, b) => a > b ? a : b);
    ensure(h);
    textAt(label, bodyFont, 0, y, labelW, brush: muted);
    textAt(value, bodyFont, labelW, y, width - labelW);
    y += h + 3;
  }

  void rule() {
    ensure(2);
    page.graphics.drawLine(rulePen, Offset(0, y), Offset(width, y));
  }

  List<double> get _colX {
    final List<double> xs = [];
    double x = 0;
    for (final f in _cols) {
      xs.add(x);
      x += width * f;
    }
    return xs;
  }

  void itemHeader(List<String> titles) {
    final double h = measure(titles.first, boldFont, width) + 6;
    ensure(h + 20);
    page.graphics.drawRectangle(brush: PdfSolidBrush(PdfColor(240, 240, 240)), bounds: Rect.fromLTWH(0, y, width, h));
    final xs = _colX;
    for (int i = 0; i < titles.length; i++) {
      textAt(titles[i], boldFont, xs[i] + 4, y + 3, width * _cols[i] - 8, align: i == 0 ? PdfTextAlignment.left : PdfTextAlignment.right);
    }
    y += h + 4;
  }

  void itemRow(String name, List<String> notes, String qty, String unit, String total, {bool indent = false}) {
    final xs = _colX;
    final double nameW = width * _cols[0] - 8 - (indent ? 10 : 0);
    final double nameX = xs[0] + 4 + (indent ? 10 : 0);
    final PdfFont nameFont = indent ? bodyFont : boldFont;
    double h = measure(name, nameFont, nameW);
    for (final n in notes) {
      h += measure(n, smallFont, nameW) + 1;
    }
    ensure(h + 4);
    double top = y;
    top += textAt(name, nameFont, nameX, top, nameW);
    for (final n in notes) {
      top += 1;
      top += textAt(n, smallFont, nameX, top, nameW, brush: muted);
    }
    final List<String> cells = [qty, unit, total];
    for (int i = 0; i < cells.length; i++) {
      textAt(cells[i], i == 2 && !indent ? boldFont : bodyFont, xs[i + 1] + 4, y, width * _cols[i + 1] - 8, align: PdfTextAlignment.right);
    }
    y += h + 6;
  }

  void total(String label, String value, {bool bold = false}) {
    final PdfFont font = bold ? totalFont : bodyFont;
    final double labelX = width * 0.40;
    final double labelW = width * 0.34;
    final double valueW = width - labelX - labelW - 4;
    final double h = [measure(label, font, labelW), measure(value, font, valueW)].reduce((a, b) => a > b ? a : b);
    ensure(h);
    textAt(label, font, labelX, y, labelW, brush: bold ? null : muted);
    textAt(value, font, labelX + labelW, y, valueW, align: PdfTextAlignment.right);
    y += h + 4;
  }

  /// Code 128 (set B) barcode of [value].
  void barcode(String value, {required double height}) {
    final List<int>? modules = Code128.encode(value);
    if (modules == null) return;
    final int total = modules.fold(0, (a, b) => a + b);
    final double maxWidth = width * 0.75;
    double module = maxWidth / total;
    if (module > 1.4) module = 1.4;
    ensure(height + 4);
    final PdfBrush black = PdfSolidBrush(PdfColor(0, 0, 0));
    double x = 0;
    for (int i = 0; i < modules.length; i++) {
      final double w = modules[i] * module;
      if (i.isEven) page.graphics.drawRectangle(brush: black, bounds: Rect.fromLTWH(x, y, w, height));
      x += w;
    }
    y += height + 3;
  }
}

/// Minimal Code 128 encoder (code set B: printable ASCII 32..127), copied from
/// the Store app. Returns module widths alternating bar / space starting with a
/// bar, including start, checksum and stop symbols. Null when [value] has a
/// character outside set B.
class Code128 {
  Code128._();

  static const List<String> _patterns = [
    '212222', '222122', '222221', '121223', '121322', '131222', '122213', '122312', '132212', '221213', //
    '221312', '231212', '112232', '122132', '122231', '113222', '123122', '123221', '223211', '221132',
    '221231', '213212', '223112', '312131', '311222', '321122', '321221', '312212', '322112', '322211',
    '212123', '212321', '232121', '111323', '131123', '131321', '112313', '132113', '132311', '211313',
    '231113', '231311', '112133', '112331', '132131', '113123', '113321', '133121', '313121', '211331',
    '231131', '213113', '213311', '213131', '311123', '311321', '331121', '312113', '312311', '332111',
    '314111', '221411', '431111', '111224', '111422', '121124', '121421', '141122', '141221', '112214',
    '112412', '122114', '122411', '142112', '142211', '241211', '221114', '413111', '241112', '134111',
    '111242', '121142', '121241', '114212', '124112', '124211', '411212', '421112', '421211', '212141',
    '214121', '412121', '111143', '111341', '131141', '114113', '114311', '411113', '411311', '113141',
    '114131', '311141', '411131', '211412', '211214', '211232', '2331112',
  ];
  static const int _startB = 104;
  static const int _stop = 106;

  static List<int>? encode(String value) {
    if (value.isEmpty) return null;
    final List<int> codes = [_startB];
    for (final int unit in value.codeUnits) {
      if (unit < 32 || unit > 127) return null;
      codes.add(unit - 32);
    }
    int checksum = _startB;
    for (int i = 1; i < codes.length; i++) {
      checksum += codes[i] * i;
    }
    codes.add(checksum % 103);
    codes.add(_stop);
    final List<int> modules = [];
    for (final int code in codes) {
      modules.addAll(_patterns[code].split('').map(int.parse));
    }
    return modules;
  }
}
