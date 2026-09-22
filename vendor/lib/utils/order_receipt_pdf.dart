import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/controller/order_details_controller.dart';
import 'package:vendor/models/cart_product_model.dart';
import 'package:vendor/models/currency_model.dart';
import 'package:vendor/models/order_model.dart';

/// PDF receipt of one order (spec 7.6 / 8.4), built with syncfusion_flutter_pdf
/// like the wallet statement.
///
/// Every figure comes from [OrderDetailsController] (the same values the order
/// details screen shows); nothing is recalculated here. Amounts are in the
/// order's own currency.
class OrderReceiptPdf {
  OrderReceiptPdf._();

  static const double _margin = 0; // the page already has default margins
  static const double _lineGap = 4;

  /// Builds the receipt and writes it to the app documents directory.
  static Future<File> save(OrderDetailsController controller) async {
    final OrderModel order = controller.orderModel.value;
    final List<int> logo = await _loadLogo(order.vendor?.photo);
    final List<int> bytes = _build(controller, logo);
    final Directory dir = await getApplicationDocumentsDirectory();
    final String orderNo = (order.id ?? 'order').replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final File file = File('${dir.path}/receipt_$orderNo.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<List<int>> _loadLogo(String? url) async {
    if (url == null || url.isEmpty || !url.startsWith('http')) return const [];
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (e) {
      log("Receipt logo not loaded: $e");
    }
    return const [];
  }

  static List<int> _build(OrderDetailsController c, List<int> logo) {
    final OrderModel order = c.orderModel.value;
    final CurrencyModel? currency = c.orderCurrency;
    String money(double value) => _money(value, currency);

    final PdfDocument document = PdfDocument();
    final _Writer w = _Writer(document);

    // ---------------- Store ----------------
    double headerTop = w.y;
    double textLeft = _margin;
    if (logo.isNotEmpty) {
      try {
        final PdfBitmap bitmap = PdfBitmap(logo);
        const double size = 56;
        w.page.graphics.drawImage(bitmap, Rect.fromLTWH(_margin, headerTop, size, size));
        textLeft = _margin + size + 12;
      } catch (e) {
        log("Receipt logo not drawable: $e");
      }
    }
    final double storeWidth = w.width - textLeft;
    double ty = headerTop;
    ty += w.textAt(order.vendor?.title ?? '', w.titleFont, textLeft, ty, storeWidth) + 2;
    if ((order.vendor?.location ?? '').isNotEmpty) ty += w.textAt(order.vendor!.location!, w.smallFont, textLeft, ty, storeWidth) + 1;
    if ((order.vendor?.phonenumber ?? '').isNotEmpty) ty += w.textAt('${'Phone'.tr}: ${order.vendor!.phonenumber}', w.smallFont, textLeft, ty, storeWidth);
    w.y = (logo.isNotEmpty && textLeft > _margin) ? (ty > headerTop + 56 ? ty : headerTop + 56) : ty;
    w.gap(10);
    w.rule();
    w.gap(8);

    // ---------------- Order ----------------
    w.line('${'Receipt'.tr} - ${'Order'.tr} ${Constant.orderId(orderId: order.id.toString())}', w.headingFont);
    w.gap(4);
    final String orderIdText = order.id ?? '';
    if (orderIdText.isNotEmpty) {
      w.barcode(orderIdText, height: 38);
      w.line(orderIdText, w.smallFont);
      w.gap(4);
    }
    if (order.createdAt != null) {
      w.pair('Date'.tr, DateFormat('MMM dd, yyyy hh:mm aa').format(order.createdAt!.toDate()));
    }
    w.pair('Type'.tr, order.takeAway == true ? 'Takeaway'.tr : 'Deliver to door'.tr);
    w.pair('Status'.tr, (order.status ?? '').tr);
    w.pair('Payment method'.tr, _paymentLabel(order.paymentMethod));
    w.gap(8);

    // ---------------- Customer ----------------
    w.line('Customer'.tr, w.headingFont);
    final String customerName = order.author?.fullName() ?? '';
    if (customerName.trim().isNotEmpty) w.line(customerName, w.bodyFont);
    final String phone = '${order.author?.countryCode ?? ''} ${order.author?.phoneNumber ?? ''}'.trim();
    if (phone.isNotEmpty) w.line(phone, w.bodyFont);
    if (order.takeAway != true && order.address != null) {
      final String address = [order.address!.address, order.address!.locality, order.address!.landmark].where((e) => (e ?? '').trim().isNotEmpty).join(', ');
      if (address.trim().isNotEmpty) w.line('${'Delivery address'.tr}: $address', w.bodyFont);
    }
    w.gap(10);

    // ---------------- Items ----------------
    w.itemHeader(['Item'.tr, 'Qty'.tr, 'Unit price'.tr, 'Total'.tr]);
    for (final CartProductModel product in order.products ?? <CartProductModel>[]) {
      final double qty = double.tryParse(product.quantity.toString()) ?? 0;
      final double unit = product.unitPrice;
      final List<String> notes = [];
      if (product.isWholesale == true) {
        final String minQty = (product.wholesaleMinQty ?? '').trim();
        notes.add(minQty.isEmpty ? 'Wholesale'.tr : '${'Wholesale'.tr} - ${'from'.tr} $minQty ${'units'.tr}');
      }
      final Map<String, dynamic>? options = product.variantInfo?.variantOptions?.cast<String, dynamic>();
      if (options != null && options.isNotEmpty) {
        notes.add(options.entries.map((e) => '${e.key}: ${e.value}').join(', '));
      }
      w.itemRow(product.name ?? '', notes, _qty(qty), money(unit), money(unit * qty));

      final double extrasUnit = double.tryParse(product.extrasPrice.toString()) ?? 0;
      if ((product.extras ?? []).isNotEmpty) {
        w.itemRow('+ ${'Extras'.tr}', [product.extras!.map((e) => e.toString()).join(', ')], _qty(qty), money(extrasUnit), money(extrasUnit * qty), indent: true);
      }
    }
    w.gap(4);
    w.rule();
    w.gap(6);

    // ---------------- Totals (the figures the details screen computes) ----------------
    w.total('Item totals'.tr, money(c.subTotal.value));
    if (c.couponAmount.value > 0) w.total('Coupon discount'.tr, '- ${money(c.couponAmount.value)}');
    if (c.specialDiscountAmount.value > 0) w.total('Special discount'.tr, '- ${money(c.specialDiscountAmount.value)}');
    if (c.packagingCharge.value > 0) w.total('Packaging charge'.tr, money(c.packagingCharge.value));
    if (c.totalTaxAmount.value > 0) w.total('Taxes'.tr, money(c.totalTaxAmount.value));
    if (c.platformFee.value > 0) w.total('Platform fee'.tr, money(c.platformFee.value));
    if (c.platformTaxAmount.value > 0) w.total('Platform fee tax'.tr, money(c.platformTaxAmount.value));
    // Delivery charge and tip count towards the total only when delivery is
    // not free (the same rule as the controller's total).
    if (order.isFreeDelivery == false) {
      if (order.takeAway != true || c.deliveryCharges.value > 0) w.total('Delivery charge'.tr, money(c.deliveryCharges.value));
      if (c.deliveryTips.value > 0) w.total('Delivery tip'.tr, money(c.deliveryTips.value));
    } else if (order.takeAway != true) {
      w.total('Delivery charge'.tr, 'Free'.tr);
    }
    if (c.driverDeliveryTaxAmount.value > 0) w.total('Delivery tax'.tr, money(c.driverDeliveryTaxAmount.value));
    w.gap(2);
    w.rule();
    w.gap(4);
    // totalRejectAmount is the controller's "everything the customer paid"
    // figure (store total + platform fee and tax + delivery tax + delivery
    // charge and tip unless free).
    w.total('Total'.tr, money(c.totalRejectAmount.value), bold: true);
    w.gap(16);
    w.line('Thank you for your order!'.tr, w.smallFont, align: PdfTextAlignment.center);

    final List<int> bytes = document.saveSync();
    document.dispose();
    return bytes;
  }

  static String _qty(double qty) => qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();

  static String _paymentLabel(String? method) {
    if (method == null || method.isEmpty) return '-';
    if (method.toLowerCase() == 'cod') return 'Cash on delivery'.tr;
    return method;
  }

  /// [Constant.amountShow] in the order currency. The standard PDF fonts only
  /// cover Latin-1, so a symbol outside it (e.g. the rupee sign) is written as
  /// the currency code instead.
  static String _money(double value, CurrencyModel? currency) {
    final String shown = Constant.amountShow(currency: currency, amount: value.toString());
    if (!_isLatin1(shown) && currency != null && (currency.code ?? '').isNotEmpty) {
      return shown.replaceAll(currency.symbol ?? '', currency.code!).trim();
    }
    return shown;
  }

  static bool _isLatin1(String s) => s.codeUnits.every((u) => u <= 0xFF);
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

  /// Pdf standard fonts only encode Latin-1; anything else becomes "?".
  static String safe(String s) => String.fromCharCodes(s.runes.map((r) => r <= 0xFF ? r : 0x3F));

  double measure(String text, PdfFont font, double w) => font.measureString(safe(text), layoutArea: Size(w, 0)).height;

  /// Draws wrapped text at an absolute position; returns its height.
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
    y += h + _lineGapOf(font);
  }

  double _lineGapOf(PdfFont font) => OrderReceiptPdf._lineGap - (font.size > 11 ? 0 : 1);

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
    final List<double> noteHeights = notes.map((n) => measure(n, smallFont, nameW)).toList();
    for (final nh in noteHeights) {
      h += nh + 1;
    }
    ensure(h + 4);
    double top = y;
    top += textAt(name, nameFont, nameX, top, nameW);
    for (int i = 0; i < notes.length; i++) {
      top += 1;
      top += textAt(notes[i], smallFont, nameX, top, nameW, brush: muted);
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

  /// Code 128 (set B) barcode of [value], scaled to the page width.
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

/// Minimal Code 128 encoder (code set B: printable ASCII 32..127). Returns the
/// module widths, alternating bar / space starting with a bar, including the
/// quiet-zone-free start, checksum and stop symbols. Null when [value] has a
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
