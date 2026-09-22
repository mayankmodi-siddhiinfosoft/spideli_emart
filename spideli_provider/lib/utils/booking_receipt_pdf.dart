import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/model/currency_model.dart';
import 'package:spideliprovider/model/onprovider_order_model.dart';
import 'package:spideliprovider/model/tax_model.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/region_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Figures of one booking, computed exactly like the booking details screen
/// (`priceTotalRow`): price x quantity, coupon discount, taxes on the
/// subtotal, plus the extra charges added by the provider.
class BookingTotals {
  final double unitPrice;
  final double price;
  final double discount;
  final double subTotal;
  final List<MapEntry<TaxModel, double>> taxes;
  final double total;
  final double extraCharges;

  BookingTotals._(this.unitPrice, this.price, this.discount, this.subTotal, this.taxes, this.total, this.extraCharges);

  double get grandTotal => total + extraCharges;

  static double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;

  factory BookingTotals.of(OnProviderOrderModel order) {
    final bool noDiscountPrice = order.provider.disPrice == "" || order.provider.disPrice == "0" || order.provider.disPrice == null;
    final double unit = noDiscountPrice ? _d(order.provider.price) : _d(order.provider.disPrice);
    final double price = unit * order.quantity;
    final double discount = (order.discountType == 'Percentage' || order.discountType == 'Percent') ? price * _d(order.discountLabel) / 100 : _d(order.discountLabel);
    final double subTotal = price - discount;
    final List<MapEntry<TaxModel, double>> taxes = [];
    double total = subTotal;
    for (final TaxModel tax in order.taxModel ?? <TaxModel>[]) {
      final double value = getTaxValue(amount: subTotal.toString(), taxModel: tax);
      if (tax.enable == true) taxes.add(MapEntry(tax, value));
      total += value;
    }
    return BookingTotals._(unit, price, discount, subTotal, taxes, total, _d(order.extraCharges));
  }
}

/// PDF receipt of one booking (spec 7.6 / 10), built with syncfusion_flutter_pdf
/// like the Store app's order receipt. Amounts are in the booking's own
/// currency (its `regionId`, else the provider's region, else global).
class BookingReceiptPdf {
  BookingReceiptPdf._();

  static Future<File> save(OnProviderOrderModel order, {User? provider}) async {
    final List<int> logo = await _loadLogo(provider?.profilePictureURL);
    final List<int> bytes = _build(order, provider, logo);
    final Directory dir = await getApplicationDocumentsDirectory();
    final String no = (order.id.isEmpty ? 'booking' : order.id).replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final File file = File('${dir.path}/receipt_$no.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Builds + saves, then copies to the public Download folder on Android.
  static Future<void> download(OnProviderOrderModel order, {User? provider}) async {
    final File? file = await _saveWithLoader(order, provider);
    if (file == null) return;
    if (Platform.isAndroid) {
      try {
        final Directory downloads = Directory('/storage/emulated/0/Download');
        if (await downloads.exists()) {
          await file.copy('${downloads.path}/${file.uri.pathSegments.last}');
          ShowToastDialog.showToast("Receipt downloaded in download folder".tr);
          return;
        }
      } catch (e) {
        log("Receipt copy to Download failed: $e");
      }
    }
    ShowToastDialog.showToast("Receipt saved".tr);
  }

  /// Builds the receipt and opens the share sheet (WhatsApp, e-mail...).
  static Future<void> share(OnProviderOrderModel order, {User? provider}) async {
    final File? file = await _saveWithLoader(order, provider);
    if (file == null) return;
    final String no = orderIdLabel(order.id);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: "${"Receipt".tr} ${"Booking".tr} $no",
          text: "${order.provider.title ?? ''} - ${"Receipt".tr} ${"Booking".tr} $no".trim(),
        ),
      );
    } catch (e) {
      log("Receipt share failed: $e");
      ShowToastDialog.showToast("Could not share the receipt.".tr);
    }
  }

  static String orderIdLabel(String id) => id.length > 10 ? orderId(orderId: id) : "#$id";

  static Future<File?> _saveWithLoader(OnProviderOrderModel order, User? provider) async {
    ShowToastDialog.showLoader("Please wait".tr);
    try {
      final File file = await save(order, provider: provider);
      ShowToastDialog.closeLoader();
      return file;
    } catch (e, s) {
      log("Receipt PDF failed: $e", stackTrace: s);
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Could not create the receipt. Please try again.".tr);
      return null;
    }
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

  static List<int> _build(OnProviderOrderModel order, User? provider, List<int> logo) {
    final CurrencyModel? currency = RegionService.currencyForBooking(order.regionId);
    String money(double value) => _money(value, currency);
    final BookingTotals t = BookingTotals.of(order);

    final PdfDocument document = PdfDocument();
    final _Writer w = _Writer(document);

    // ---------------- Provider ----------------
    final String providerName = (provider?.companyName ?? '').isNotEmpty
        ? provider!.companyName!
        : (order.provider.authorName ?? '').isNotEmpty
            ? order.provider.authorName!
            : (provider?.fullName() ?? '');
    final double headerTop = w.y;
    double textLeft = 0;
    if (logo.isNotEmpty) {
      try {
        const double size = 56;
        w.page.graphics.drawImage(PdfBitmap(logo), Rect.fromLTWH(0, headerTop, size, size));
        textLeft = size + 12;
      } catch (e) {
        log("Receipt logo not drawable: $e");
      }
    }
    final double headerWidth = w.width - textLeft;
    double ty = headerTop;
    ty += w.textAt(providerName, w.titleFont, textLeft, ty, headerWidth) + 2;
    final String providerPhone = (order.provider.phoneNumber ?? provider?.phoneNumber ?? '').trim();
    if (providerPhone.isNotEmpty) ty += w.textAt('${'Phone'.tr}: $providerPhone', w.smallFont, textLeft, ty, headerWidth) + 1;
    if ((provider?.commercialRegister ?? '').isNotEmpty) ty += w.textAt('${'Commercial register'.tr}: ${provider!.commercialRegister}', w.smallFont, textLeft, ty, headerWidth) + 1;
    if ((provider?.uniqueIdNumber ?? '').isNotEmpty) ty += w.textAt('${'Unique identification number'.tr}: ${provider!.uniqueIdNumber}', w.smallFont, textLeft, ty, headerWidth);
    w.y = (logo.isNotEmpty && textLeft > 0) ? (ty > headerTop + 56 ? ty : headerTop + 56) : ty;
    w.gap(10);
    w.rule();
    w.gap(8);

    // ---------------- Booking ----------------
    w.line('${'Receipt'.tr} - ${'Booking'.tr} ${orderIdLabel(order.id)}', w.headingFont);
    w.gap(4);
    if (order.id.isNotEmpty) {
      w.barcode(order.id, height: 38);
      w.line(order.id, w.smallFont);
      w.gap(4);
    }
    final DateFormat fmt = DateFormat('MMM dd, yyyy hh:mm aa');
    w.pair('Booked on'.tr, fmt.format(order.createdAt.toDate()));
    final scheduled = order.newScheduleDateTime ?? order.scheduleDateTime;
    if (scheduled != null) w.pair('Scheduled for'.tr, fmt.format(scheduled.toDate()));
    if (order.startTime != null) w.pair('Started'.tr, fmt.format(order.startTime!.toDate()));
    if (order.endTime != null) w.pair('Completed'.tr, fmt.format(order.endTime!.toDate()));
    w.pair('Status'.tr, order.status.tr);
    w.pair('Payment method'.tr, _paymentLabel(order.payment_method));
    if (order.paymentStatus != null) w.pair('Payment status'.tr, order.paymentStatus == true ? 'Paid'.tr : 'Pending'.tr);
    w.gap(8);

    // ---------------- Customer ----------------
    w.line('Customer'.tr, w.headingFont);
    final String customerName = order.author.fullName().trim();
    if (customerName.isNotEmpty) w.line(customerName, w.bodyFont);
    final String phone = '${order.author.countryCode ?? ''} ${order.author.phoneNumber}'.trim();
    if (phone.isNotEmpty) w.line(phone, w.bodyFont);
    final String address = order.address?.getFullAddress() ?? '';
    if (address.trim().isNotEmpty) w.line('${'Service address'.tr}: $address', w.bodyFont);
    w.gap(10);

    // ---------------- Service ----------------
    final bool hourly = order.provider.priceUnit != null && order.provider.priceUnit != 'Fixed';
    w.itemHeader(['Service'.tr, hourly ? 'Hours'.tr : 'Qty'.tr, 'Unit price'.tr, 'Total'.tr]);
    w.itemRow(order.provider.title ?? '', [if (hourly) 'Hourly'.tr], _qty(order.quantity), money(t.unitPrice), money(t.price));
    w.gap(4);
    w.rule();
    w.gap(6);

    // ---------------- Totals ----------------
    w.total('Price'.tr, money(t.price));
    if (t.discount > 0) w.total('${'Discount'.tr}${(order.couponCode ?? '').isNotEmpty ? ' (${order.couponCode})' : ''}', '- ${money(t.discount)}');
    w.total('SubTotal'.tr, money(t.subTotal));
    for (final entry in t.taxes) {
      final TaxModel tax = entry.key;
      final String label = '${tax.title ?? 'Tax'.tr} (${tax.type == "fix" ? money(_d(tax.tax)) : "${tax.tax}%"})';
      w.total(label, money(entry.value));
    }
    w.total('Total Amount'.tr, money(t.total), bold: t.extraCharges <= 0);
    if (t.extraCharges > 0) {
      final String desc = (order.extraChargesDescription ?? '').trim();
      w.total('${'Extra charges'.tr}${desc.isNotEmpty ? ' ($desc)' : ''}', money(t.extraCharges));
      if (order.extraPaymentStatus != null) w.total('Extra charges payment'.tr, order.extraPaymentStatus == true ? 'Paid'.tr : 'Pending'.tr);
      w.gap(2);
      w.rule();
      w.gap(4);
      w.total('Grand total'.tr, money(t.grandTotal), bold: true);
    }
    w.gap(16);
    w.line('Thank you for your booking!'.tr, w.smallFont, align: PdfTextAlignment.center);

    final List<int> bytes = document.saveSync();
    document.dispose();
    return bytes;
  }

  static double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;

  static String _qty(double qty) => qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(2);

  static String _paymentLabel(String? method) {
    if (method == null || method.isEmpty) return '-';
    if (method.toLowerCase() == 'cod') return 'Cash on delivery'.tr;
    return method;
  }

  /// [amountShow] in the booking currency. Standard PDF fonts only cover
  /// Latin-1, so a symbol outside it is written as the currency code.
  static String _money(double value, CurrencyModel? currency) {
    final String shown = amountShow(currency: currency, amount: value.toString());
    if (!shown.codeUnits.every((u) => u <= 0xFF) && currency != null && (currency.code ?? '').isNotEmpty) {
      return shown.replaceAll(currency.symbol ?? '', ' ${currency.code!} ').trim();
    }
    return shown;
  }
}

/// Top-to-bottom writer with automatic page breaks (port of the Store app's).
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

  void itemRow(String name, List<String> notes, String qty, String unit, String total) {
    final xs = _colX;
    final double nameW = width * _cols[0] - 8;
    final double nameX = xs[0] + 4;
    double h = measure(name, boldFont, nameW);
    for (final n in notes) {
      h += measure(n, smallFont, nameW) + 1;
    }
    ensure(h + 4);
    double top = y;
    top += textAt(name, boldFont, nameX, top, nameW);
    for (final n in notes) {
      top += 1;
      top += textAt(n, smallFont, nameX, top, nameW, brush: muted);
    }
    final List<String> cells = [qty, unit, total];
    for (int i = 0; i < cells.length; i++) {
      textAt(cells[i], i == 2 ? boldFont : bodyFont, xs[i + 1] + 4, y, width * _cols[i + 1] - 8, align: PdfTextAlignment.right);
    }
    y += h + 6;
  }

  void total(String label, String value, {bool bold = false}) {
    final PdfFont font = bold ? totalFont : bodyFont;
    final double labelX = width * 0.36;
    final double labelW = width * 0.38;
    final double valueW = width - labelX - labelW - 4;
    final double h = [measure(label, font, labelW), measure(value, font, valueW)].reduce((a, b) => a > b ? a : b);
    ensure(h);
    textAt(label, font, labelX, y, labelW, brush: bold ? null : muted);
    textAt(value, font, labelX + labelW, y, valueW, align: PdfTextAlignment.right);
    y += h + 4;
  }

  /// Code 128 (set B) barcode of [value].
  void barcode(String value, {required double height}) {
    final List<int>? modules = _Code128.encode(value);
    if (modules == null) return;
    final int total = modules.fold(0, (a, b) => a + b);
    double module = (width * 0.75) / total;
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

/// Minimal Code 128 encoder (code set B, printable ASCII 32..127).
class _Code128 {
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
