import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/controllers/wallet_controller.dart';
import 'package:customer/payment/create_razor_pay_order_model.dart';
import 'package:customer/payment/rozorpay_conroller.dart';
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/service/finance_region_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_payment_rules.dart';
import 'package:customer/utils/finance_security_rules.dart';
import 'package:customer/utils/region_service.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// The app's payment gateways for one Spideli Finance payment
/// (.claude/FINANCE-DIRECT-FIRESTORE.md section 2.3): the checkouts of the
/// shopping wallet ([WalletController]) with its per-region settings, run
/// for an amount and a currency, reporting the gateway's transaction id.
class FinanceCheckout {
  final WalletController _ctrl;

  /// The gateways the admin enabled for the user's region (FinanceGateways keys).
  final Set<String> enabled;

  FinanceCheckout._(this._ctrl, this.enabled);

  /// FinanceGateways key -> the app's gateway name (RegionService.isGatewayUsable).
  static const Map<String, String> _gatewayNames = {
    FinanceGateways.orangeMoney: 'orangeMoney',
    FinanceGateways.flutterwave: 'flutterWave',
    FinanceGateways.stripe: 'stripe',
    FinanceGateways.paypal: 'paypal',
    FinanceGateways.payStack: 'payStack',
    FinanceGateways.mercadoPago: 'mercadoPago',
    FinanceGateways.xendit: 'xendit',
    FinanceGateways.midTrans: 'midTrans',
    FinanceGateways.payFast: 'payFast',
    FinanceGateways.razorpay: 'razorpay',
  };

  /// Loads the region's gateway settings. Never throws: no gateway when they cannot be read.
  static Future<FinanceCheckout> open() async {
    // Not registered with Get: its onInit (the shopping wallet's history) does not run.
    final ctrl = WalletController();
    try {
      final user = await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid());
      if (user != null) ctrl.userModel.value = user;
      await ctrl.getPaymentSettings();
    } catch (e) {
      log('finance checkout: gateway settings not loaded: $e');
    }
    final enabled = <String>{
      if (ctrl.orangeMoneyModel.value.enable == true) FinanceGateways.orangeMoney,
      if (ctrl.flutterWaveModel.value.isEnable == true) FinanceGateways.flutterwave,
      if (ctrl.stripeModel.value.isEnabled == true) FinanceGateways.stripe,
      if (ctrl.payPalModel.value.isEnabled == true) FinanceGateways.paypal,
      if (ctrl.payStackModel.value.isEnable == true) FinanceGateways.payStack,
      if (ctrl.mercadoPagoModel.value.isEnabled == true) FinanceGateways.mercadoPago,
      if (ctrl.xenditModel.value.enable == true) FinanceGateways.xendit,
      if (ctrl.midTransModel.value.enable == true) FinanceGateways.midTrans,
      if (ctrl.payFastModel.value.isEnable == true) FinanceGateways.payFast,
      if (ctrl.razorPayModel.value.isEnabled == true) FinanceGateways.razorpay,
    };
    // Only the gateways serving the customer's Finance region (their
    // "Available in Regions"), as the admin's region settings assume.
    final String? region = FinanceRegion.currentId;
    if (region != null) enabled.removeWhere((key) => !RegionService.isGatewayUsable(_gatewayNames[key] ?? key, region));
    return FinanceCheckout._(ctrl, enabled);
  }

  /// Runs [gateway]'s checkout for [amount] (minor units of [currency]).
  /// Returns the funding to post (the gateway and its transaction id: a
  /// generated checkout id when the gateway gives none). Throws a
  /// [FinanceException] `payment_not_completed` (with the gateway's message
  /// as `details.message`) when the payment did not go through.
  Future<FinanceFunding> pay(BuildContext context, {required String gateway, required int amount, required String currency}) async {
    if (!enabled.contains(gateway) || !FinanceGateways.chargeable(gateway, amount, currency)) throw const FinanceException('gateway_unavailable');
    final c = _ctrl;
    final done = Completer<FinanceFunding>();
    c.chargeCurrency = currency;
    c.chargeUnits = FinanceGateways.units(gateway, amount, currency);
    c.onPaid = (method, reference) async {
      if (done.isCompleted) return;
      final String ref = (reference ?? '').trim().isNotEmpty ? reference!.trim() : 'chk_${const Uuid().v4()}';
      done.complete(FinanceFunding.gateway(gateway, ref));
    };
    c.onPaymentFailed = (method, message) {
      if (!done.isCompleted) done.completeError(FinanceException('payment_not_completed', {if ((message ?? '').isNotEmpty) 'message': message}));
    };
    final String major = FinanceGateways.major(amount, currency);
    try {
      switch (gateway) {
        case FinanceGateways.stripe:
          await c.stripeMakePayment(amount: major);
        case FinanceGateways.paypal:
          if (!context.mounted) throw const FinanceException('payment_not_completed');
          c.paypalPaymentSheet(major, context);
        case FinanceGateways.payStack:
          await c.payStackPayment(major);
        case FinanceGateways.mercadoPago:
          if (!context.mounted) throw const FinanceException('payment_not_completed');
          await c.mercadoPagoMakePayment(context: context, amount: major);
        case FinanceGateways.flutterwave:
          if (!context.mounted) throw const FinanceException('payment_not_completed');
          await c.flutterWaveInitiatePayment(context: context, amount: major);
        case FinanceGateways.payFast:
          if (!context.mounted) throw const FinanceException('payment_not_completed');
          await c.payFastPayment(context: context, amount: major);
        case FinanceGateways.midTrans:
          if (!context.mounted) throw const FinanceException('payment_not_completed');
          await c.midtransMakePayment(context: context, amount: major);
        case FinanceGateways.orangeMoney:
          if (!context.mounted) throw const FinanceException('payment_not_completed');
          await c.orangeMakePayment(context: context, amount: major);
        case FinanceGateways.xendit:
          if (!context.mounted) throw const FinanceException('payment_not_completed');
          await c.xenditPayment(context, FinanceGateways.majorNum(amount, currency));
        case FinanceGateways.razorpay:
          final CreateRazorPayOrderModel? order =
              await RazorPayController().createOrderRazorPay(amount: FinanceGateways.majorNum(amount, currency).toDouble(), razorpayModel: c.razorPayModel.value);
          if (order == null) throw const FinanceException('payment_not_completed');
          c.openCheckout(amount: FinanceGateways.majorNum(amount, currency), orderId: order.id);
        default:
          throw const FinanceException('gateway_unavailable');
      }
      final funding = await done.future;
      // PayPal closes its page just after reporting the payment: let it go
      // before the next sheet opens over it.
      if (gateway == FinanceGateways.paypal) await Future<void>.delayed(const Duration(milliseconds: 400));
      return funding;
    } on FinanceException {
      ShowToastDialog.closeLoader();
      rethrow;
    } catch (e) {
      ShowToastDialog.closeLoader();
      if (done.isCompleted) {
        // The gateway reported first (a late error after its success).
        return done.future;
      }
      log('finance checkout $gateway failed: $e');
      throw const FinanceException('payment_not_completed');
    } finally {
      c.onPaid = null;
      c.onPaymentFailed = null;
      c.chargeCurrency = null;
      c.chargeUnits = null;
    }
  }

  void close() {
    try {
      _ctrl.razorPay.clear();
    } catch (_) {
      // Already cleared.
    }
  }
}

/// Direct Firestore writes of Spideli Finance (no Cloud Functions): one
/// batch per operation, checked by the security rules, idempotent through
/// the request document's deterministic id.
abstract final class FinancePaymentService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// The ledger transaction id of a request key (`1697000000000-abc...`):
  /// `tx_<millis>_<random>`, the same on every retry of that request.
  static String txIdOf(String requestKey) => 'tx_${requestKey.replaceAll('-', '_')}';

  /// Commits [writes] in one batch. [guard] is the path of the request
  /// document the batch creates (create-only for the rules): when the
  /// commit fails and that document exists and belongs to the user ([owner]
  /// field), an earlier attempt of the same request went through, and its
  /// data is returned. Null after a normal commit. A refusal by the rules
  /// becomes `permission_denied`, a lost connection `network`.
  static Future<Map<String, dynamic>?> commit(List<FinanceWrite> writes, {String? guard, String owner = 'userId'}) async {
    if (FinanceService.uid.isEmpty) throw const FinanceException('sign_in_required');
    try {
      await FinanceLedger.commit(writes, db: _db);
      return null;
    } catch (e) {
      if (guard != null) {
        try {
          final snap = await _db.doc(guard).get(const GetOptions(source: Source.server));
          final data = snap.data();
          if (snap.exists && data != null && data[owner] == FinanceService.uid) return {...data, 'id': snap.id};
        } catch (_) {
          // Unknown: report the commit's own error.
        }
      }
      throw mapError(e);
    }
  }

  /// A Firestore / network failure as a [FinanceException].
  static FinanceException mapError(Object e) {
    if (e is FinanceException) return e;
    if (e is TimeoutException) return const FinanceException('network');
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return const FinanceException('permission_denied');
        case 'unauthenticated':
          return const FinanceException('sign_in_required');
        case 'unavailable':
        case 'deadline-exceeded':
          return const FinanceException('network');
      }
      return FinanceException(e.code);
    }
    return const FinanceException('unknown');
  }

  /// Reads a document of the user's own (a guard, a request).
  static Future<Map<String, dynamic>?> read(String path) async {
    try {
      final snap = await _db.doc(path).get();
      return snap.data() == null ? null : {...snap.data()!, 'id': snap.id};
    } catch (e) {
      throw mapError(e);
    }
  }

  /// Fails with `finance_restricted` when the admin restricted the user for
  /// [scope] (`users/{uid}.financeRestriction`; 'all' covers every scope).
  /// Checked before any payment is taken; the rules refuse it anyway, so a
  /// profile that cannot be read does not block here.
  static Future<void> requireAllowed(String scope) async {
    Map<String, dynamic>? profile;
    try {
      profile = (await _db.collection('users').doc(FinanceService.uid).get()).data();
    } catch (_) {
      return;
    }
    if (FinanceRestriction.blocks(profile, scope)) throw const FinanceException('finance_restricted');
  }

  /// Fails with `insufficient_funds` unless the user's [currency] wallet
  /// holds [total]. Returns the wallet (its id, whether it exists, its balance).
  static Future<({String id, bool exists, int balance})> requireBalance(String currency, int total) async {
    final ({String id, bool exists, int balance}) w;
    try {
      w = await FinanceLedger.wallet(FinanceService.uid, currency);
    } catch (e) {
      throw mapError(e);
    }
    if (!w.exists || w.balance < total) throw const FinanceException('insufficient_funds');
    return w;
  }
}
