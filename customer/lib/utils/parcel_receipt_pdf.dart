import 'dart:developer';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:customer/constant/constant.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/models/parcel_order_model.dart';
import 'package:customer/models/parcel_shipping_models.dart';
import 'package:customer/screen_ui/parcel_service/parcel_shipping_widgets.dart';
import 'package:customer/service/parcel_shipping_service.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/order_receipt_pdf.dart' show Code128, OrderReceiptPdf;
import 'package:customer/utils/region_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Amounts of a parcel order, computed exactly as the parcel screens do.
class ParcelAmounts {
  final double subTotal;
  final double discount;
  final double platformFee;
  final double taxes;

  /// Fixed intercity / intercountry tax, outside VAT and coupons.
  final double scopeTax;

  ParcelAmounts(this.subTotal, this.discount, this.platformFee, this.taxes, [this.scopeTax = 0]);

  double get total => subTotal - discount + platformFee + taxes + scopeTax;

  factory ParcelAmounts.of(ParcelOrderModel o) {
    final double sub = double.tryParse(o.subTotal ?? '') ?? 0;
    final double disc = double.tryParse(o.discount ?? '') ?? 0;
    final double fee = double.tryParse(o.platformFee ?? '') ?? 0;
    double tax = 0;
    for (final t in o.taxSetting ?? []) {
      tax += Constant.calculateTax(amount: (sub - disc).toString(), taxModel: t);
    }
    if (fee > 0) {
      for (final t in o.platformTax ?? []) {
        tax += Constant.calculateTax(amount: fee.toString(), taxModel: t);
      }
    }
    return ParcelAmounts(sub, disc, fee, tax, o.scopeTaxAmount);
  }
}

/// Parcel / mail PDF receipt (spec 7.6 + 7.4): logo, tracking number with its
/// Code 128 barcode and the QR, date, status, sender / receiver, parcel
/// details, route and methods, price breakdown and total, payment method - in
/// the order's own region currency.
class ParcelReceiptPdf {
  ParcelReceiptPdf._();

  /// A cancelled parcel was never paid for, so its document is an order
  /// summary and never a receipt (WEB spec 8). The parcel's own status wins
  /// over the order status.
  static bool isVoided(ParcelOrderModel order) => OrderReceiptPdf.isVoidedStatus(order.parcelStatus ?? order.status);

  /// "Parcel receipt" / "Mail receipt", or "Order Summary" when cancelled.
  static String documentTitle(ParcelOrderModel order) {
    if (isVoided(order)) return "Order Summary".tr;
    return order.shipmentType == ParcelShipping.mail ? 'Mail receipt'.tr : 'Parcel receipt'.tr;
  }

  static void showOptions(BuildContext context, ParcelOrderModel order) {
    final String what = documentTitle(order);
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
                    await share(order);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.download_outlined, color: AppThemeData.primary300),
                  title: Text("${"Download".tr} $what (PDF)"),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await download(order);
                  },
                ),
                ListTile(leading: const Icon(Icons.close, color: Colors.grey), title: Text("Cancel".tr), onTap: () => Navigator.pop(ctx)),
              ],
            ),
          ),
    );
  }

  static Future<void> share(ParcelOrderModel order) async {
    final File? file = await _save(order);
    if (file == null) return;
    final String what = documentTitle(order);
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'application/pdf')], subject: "$what ${order.trackingNumber ?? order.id}", text: "$what ${order.trackingNumber ?? ''}".trim()),
      );
    } catch (e) {
      log("Parcel receipt share failed: $e");
      ShowToastDialog.showToast("Could not share the document.".tr);
    }
  }

  static Future<void> download(ParcelOrderModel order) async {
    final File? file = await _save(order);
    if (file == null) return;
    final String what = documentTitle(order);
    if (Platform.isAndroid) {
      try {
        final Directory downloads = Directory('/storage/emulated/0/Download');
        if (await downloads.exists()) {
          await file.copy('${downloads.path}/${file.uri.pathSegments.last}');
          ShowToastDialog.showToast("$what ${"downloaded in download folder".tr}");
          return;
        }
      } catch (e) {
        log("Parcel receipt copy failed: $e");
      }
    }
    ShowToastDialog.showToast("$what ${"saved".tr}");
  }

  static Future<File?> _save(ParcelOrderModel order) async {
    ShowToastDialog.showLoader("Please wait...".tr);
    try {
      await RegionService.ensureLoaded();
      final PickupPointModel? from = await ParcelShippingService.pickupPoint(order.originPickupPointId);
      final PickupPointModel? to = await ParcelShippingService.pickupPoint(order.destinationPickupPointId);
      final List<int> qr = await _qrPng(order.qrValue);
      final List<int> logo = await _logo();
      final List<int> bytes = _build(order, RegionService.currencyForRecord(order.regionId), qr, logo, from, to);
      final Directory dir = await getApplicationDocumentsDirectory();
      final String name = (order.trackingNumber ?? order.id ?? 'parcel').replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
      // Never "..._receipt_..." for a cancelled parcel.
      final File file = File('${dir.path}/${isVoided(order) ? 'parcel_order_summary' : 'parcel_receipt'}_$name.pdf');
      await file.writeAsBytes(bytes, flush: true);
      ShowToastDialog.closeLoader();
      return file;
    } catch (e, s) {
      log("Parcel receipt failed: $e", stackTrace: s);
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Could not create the document. Please try again.".tr);
      return null;
    }
  }

  static Future<List<int>> _qrPng(String? value) async {
    if (value == null || value.isEmpty) return const [];
    try {
      final data = await QrPainter(data: value, version: QrVersions.auto, gapless: true, eyeStyle: const QrEyeStyle(color: Colors.black), dataModuleStyle: const QrDataModuleStyle(color: Colors.black)).toImageData(
        400,
        format: ui.ImageByteFormat.png,
      );
      return data == null ? const [] : data.buffer.asUint8List();
    } catch (e) {
      log("QR image failed: $e");
      return const [];
    }
  }

  static Future<List<int>> _logo() async {
    try {
      final data = await rootBundle.load('assets/images/ic_logo.png');
      return data.buffer.asUint8List();
    } catch (_) {
      return const [];
    }
  }

  static String _money(double v, CurrencyModel? c) {
    final String shown = Constant.amountShow(currency: c, amount: v.toString());
    if (!shown.codeUnits.every((u) => u <= 0xFF) && c != null && c.code.isNotEmpty) return shown.replaceAll(c.symbol, c.code).trim();
    return shown;
  }

  static String _safe(String s) => String.fromCharCodes(s.runes.map((r) => r <= 0xFF ? r : 0x3F));

  static List<int> _build(ParcelOrderModel o, CurrencyModel? currency, List<int> qr, List<int> logo, PickupPointModel? from, PickupPointModel? to) {
    final PdfDocument doc = PdfDocument();
    PdfPage page = doc.pages.add();
    double y = 0;
    final double width = page.getClientSize().width;
    final PdfFont title = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final PdfFont heading = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
    final PdfFont body = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final PdfFont bold = PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold);
    final PdfFont small = PdfStandardFont(PdfFontFamily.helvetica, 8.5);
    final PdfBrush muted = PdfSolidBrush(PdfColor(110, 110, 110));
    final PdfPen rule = PdfPen(PdfColor(200, 200, 200), width: 0.7);

    void ensure(double h) {
      if (y + h > page.getClientSize().height) {
        page = doc.pages.add();
        y = 0;
      }
    }

    double text(String s, PdfFont f, double x, double top, double w, {PdfBrush? brush, PdfTextAlignment align = PdfTextAlignment.left}) {
      if (s.isEmpty) return 0;
      final double h = f.measureString(_safe(s), layoutArea: Size(w, 0)).height;
      page.graphics.drawString(_safe(s), f, brush: brush, bounds: Rect.fromLTWH(x, top, w, h), format: PdfStringFormat(alignment: align));
      return h;
    }

    void line(String s, PdfFont f) {
      final double h = f.measureString(_safe(s), layoutArea: Size(width, 0)).height;
      ensure(h);
      text(s, f, 0, y, width);
      y += h + 3;
    }

    void pair(String label, String value, {double w = 0}) {
      final double full = w > 0 ? w : width;
      final double lw = full * 0.34;
      final double h = [body.measureString(_safe(label), layoutArea: Size(lw, 0)).height, body.measureString(_safe(value), layoutArea: Size(full - lw, 0)).height].reduce((a, b) => a > b ? a : b);
      ensure(h);
      text(label, body, 0, y, lw, brush: muted);
      text(value, body, lw, y, full - lw);
      y += h + 3;
    }

    void money(String label, double v, {bool strong = false}) {
      final PdfFont f = strong ? bold : body;
      final double h = f.measureString('0').height;
      ensure(h);
      text(label, f, width * 0.40, y, width * 0.34, brush: strong ? null : muted);
      text(_money(v, currency), f, width * 0.74, y, width * 0.26, align: PdfTextAlignment.right);
      y += h + 4;
    }

    void hr() {
      ensure(4);
      page.graphics.drawLine(rule, Offset(0, y), Offset(width, y));
      y += 6;
    }

    // Header: logo + title, QR on the right.
    const double qrSize = 110;
    final double top = y;
    double left = 0;
    if (logo.isNotEmpty) {
      try {
        page.graphics.drawImage(PdfBitmap(logo), Rect.fromLTWH(0, top, 48, 48));
        left = 60;
      } catch (_) {}
    }
    final double headW = width - left - qrSize - 10;
    double ty = top;
    ty += text(documentTitle(o), title, left, ty, headW) + 4;
    ty += text(o.trackingNumber ?? '', heading, left, ty, headW) + 2;
    ty += text('${'Order'.tr} ${Constant.orderId(orderId: o.id ?? '')}', small, left, ty, headW, brush: muted);
    if (qr.isNotEmpty) {
      try {
        page.graphics.drawImage(PdfBitmap(qr), Rect.fromLTWH(width - qrSize, top, qrSize, qrSize));
      } catch (e) {
        log('QR not drawable: $e');
      }
    }
    y = [ty + 8, top + (qr.isNotEmpty ? qrSize + 6 : 0)].reduce((a, b) => a > b ? a : b);

    // Barcode of the tracking number.
    final List<int>? modules = Code128.encode(o.trackingNumber ?? '');
    if (modules != null) {
      final int total = modules.fold(0, (a, b) => a + b);
      double module = (width * 0.7) / total;
      if (module > 1.5) module = 1.5;
      ensure(46);
      final PdfBrush black = PdfSolidBrush(PdfColor(0, 0, 0));
      double x = 0;
      for (int i = 0; i < modules.length; i++) {
        final double w = modules[i] * module;
        if (i.isEven) page.graphics.drawRectangle(brush: black, bounds: Rect.fromLTWH(x, y, w, 40));
        x += w;
      }
      y += 43;
      line(o.trackingNumber!, small);
    }
    y += 4;
    if (o.createdAt != null) pair('Date'.tr, DateFormat('MMM dd, yyyy hh:mm aa').format(o.createdAt!.toDate()));
    pair('Status'.tr, (o.parcelStatus ?? o.status ?? '').tr);
    pair('Payment method'.tr, (o.paymentMethod ?? '').isEmpty ? '-' : (o.paymentMethod!.toLowerCase() == 'cod' ? 'Cash on delivery'.tr : o.paymentMethod!.capitalizeFirst!));
    if (o.paymentCollectByReceiver == true) pair('Paid by'.tr, 'Receiver'.tr);
    if ((o.pickupCode ?? '').isNotEmpty) pair('Receiver code (give to the driver or at the pickup point)'.tr, o.pickupCode!);
    y += 4;
    hr();

    // Parties.
    line('Sender'.tr, heading);
    for (final s in [o.sender?.name, o.sender?.phone, o.sender?.email, o.sender?.address]) {
      if ((s ?? '').trim().isNotEmpty) line(s!, body);
    }
    y += 4;
    line('Receiver'.tr, heading);
    for (final s in [o.receiver?.name, o.receiver?.phone, o.receiver?.email, o.receiver?.address]) {
      if ((s ?? '').trim().isNotEmpty) line(s!, body);
    }
    y += 4;
    hr();

    // Shipment.
    line('Shipment'.tr, heading);
    pair('Type'.tr, '${ParcelLabels.shipmentType(o.shipmentType)} - ${ParcelLabels.scope(o.scope)}');
    if ((o.origin?.label ?? '').isNotEmpty || (o.destination?.label ?? '').isNotEmpty) pair('Route'.tr, '${o.origin?.label ?? ''} > ${o.destination?.label ?? ''}');
    pair('Pickup'.tr, from != null ? '${ParcelLabels.pickupMethod(o.pickupMethod)}: ${from.name}${from.subtitle.isEmpty ? '' : ' (${from.subtitle})'}' : ParcelLabels.pickupMethod(o.pickupMethod));
    pair('Delivery'.tr, to != null ? '${ParcelLabels.deliveryMethod(o.deliveryMethod)}: ${to.name}${to.subtitle.isEmpty ? '' : ' (${to.subtitle})'}' : ParcelLabels.deliveryMethod(o.deliveryMethod));
    pair('Carrier'.tr, o.carrierName ?? 'Spideli drivers'.tr);
    if ((o.parcelType ?? '').isNotEmpty) pair('Category'.tr, o.parcelType!);
    if ((o.parcelWeight ?? '').isNotEmpty) pair('Weight'.tr, o.parcelWeight!);
    if (o.dimensions != null) pair('Dimensions'.tr, '${o.dimensions!['l'] ?? 0} x ${o.dimensions!['w'] ?? 0} x ${o.dimensions!['h'] ?? 0} cm');
    if ((o.declaredValue ?? '').isNotEmpty) pair('Declared value'.tr, o.declaredValue!);
    if ((o.contentDescription ?? '').isNotEmpty) pair('Content'.tr, o.contentDescription!);
    y += 4;
    hr();

    // Price.
    final ParcelAmounts a = ParcelAmounts.of(o);
    final Map<String, dynamic>? b = o.priceBreakdown;
    if (b != null && (b['source'] ?? '') != 'default') {
      for (final e in ParcelLabels.breakdownLines(b)) {
        money(e.key, e.value);
      }
    } else {
      money('Delivery charge'.tr, a.subTotal);
      if (a.scopeTax > 0) money('Fixed tax'.tr, a.scopeTax);
    }
    if (a.discount > 0) money('Discount'.tr, -a.discount);
    if (a.platformFee > 0) money('Platform fee'.tr, a.platformFee);
    if (a.taxes > 0) money('Taxes'.tr, a.taxes);
    hr();
    money(o.quoteRequested == true && o.manualPrice == null ? 'Quote pending'.tr : 'Total'.tr, a.total, strong: true);
    y += 14;
    line('Thank you for shipping with Spideli!'.tr, small);

    final List<int> bytes = doc.saveSync();
    doc.dispose();
    return bytes;
  }
}
