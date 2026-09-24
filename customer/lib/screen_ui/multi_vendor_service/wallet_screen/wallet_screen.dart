import 'package:customer/utils/region_service.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/wallet_controller.dart';
import 'package:customer/models/wallet_transaction_model.dart';
import 'package:customer/screen_ui/multi_vendor_service/wallet_screen/payment_list_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import '../../../constant/collection_name.dart';
import '../../../models/cab_order_model.dart';
import '../../../models/onprovider_order_model.dart';
import '../../../models/order_model.dart';
import '../../../models/parcel_order_model.dart';
import '../../../models/rental_order_model.dart';
import '../../../service/fire_store_utils.dart';
import '../../../themes/show_toast_dialog.dart';
import '../../auth_screens/login_screen.dart';
import '../../cab_service_screens/cab_order_details.dart';
import '../../on_demand_service/on_demand_order_details_screen.dart';
import '../../parcel_service/parcel_order_details.dart';
import '../../rental_service/rental_order_details_screen.dart';
import '../order_list_screen/order_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

/// Archetype **G — wallet / finance**: a deep gradient balance hero with an
/// animated counter, a Top-up action overlapping it, then the transaction
/// ledger with credit / debit icon wells.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: WalletController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final loading = controller.isLoading.value;
        final balance = controller.userModel.value.walletAmount ?? 0;
        final transactions = controller.walletTransactionList.toList();
        return Scaffold(
          backgroundColor: c.background,
          body: DsAsync(
            isLoading: loading,
            skeleton: const _WalletSkeleton(),
            builder: (_) => Constant.userModel == null
                ? const _GuestState()
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: DsHeroHeader(
                          title: "My Wallet".tr,
                          subtitle: "Keep track of your balance, transactions, and payment methods all in one place.".tr,
                          showBack: false,
                          gradient: DsGradients.deep(context),
                          overlap: DsCard(
                            padding: const EdgeInsets.all(DsSpace.lg),
                            child: Row(
                              children: [
                                DsIconWell(icon: Icons.add_card_rounded, tone: DsTone.brand, size: 44),
                                const DsGap(DsSpace.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Top up".tr, style: t.titleSm),
                                      Text("Add money to your wallet".tr, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption),
                                    ],
                                  ),
                                ),
                                const DsGap(DsSpace.md),
                                DsButton.primary(
                                  label: "Top up".tr,
                                  icon: Icons.add_rounded,
                                  size: DsButtonSize.sm,
                                  onPressed: () {
                                    Get.to(const PaymentListScreen());
                                  },
                                ),
                              ],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: DsSpace.lg),
                                child: Text("Available balance".tr, style: DsTypography.overline.copyWith(color: Colors.white.withValues(alpha: 0.75))),
                              ),
                              const DsGap(DsSpace.xs),
                              DsAnimatedCounter(
                                value: balance,
                                style: DsTypography.metricLg.copyWith(color: Colors.white),
                                format: (v) => Constant.amountShow(amount: v.toString(), currency: RegionService.customerCurrency),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: DsResponsive(
                          maxWidth: DsLayout.contentMax,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
                            child: DsSectionHeader(title: "Transactions".tr, icon: Icons.receipt_long_outlined),
                          ),
                        ),
                      ),
                      if (transactions.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: DsEmptyState(icon: Icons.account_balance_wallet_outlined, title: "Transaction not found".tr, message: "Your wallet activity will show up here.".tr),
                        )
                      else
                        DsSliverResponsive(
                          maxWidth: DsLayout.contentMax,
                          bottom: DsSpace.xxxl,
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((context, index) {
                              WalletTransactionModel walletTractionModel = transactions[index];
                              return DsFadeSlideIn(index: index, child: transactionCard(context, controller, walletTractionModel));
                            }, childCount: transactions.length),
                          ),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget transactionCard(BuildContext context, WalletController controller, WalletTransactionModel transactionModel) {
    final c = context.dsColors;
    final t = context.dsText;
    final isCredit = transactionModel.isTopup == true;
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.sm),
      padding: const EdgeInsets.all(DsSpace.md),
      semanticLabel: transactionModel.note.toString(),
      onTap: () async {
        final orderId = transactionModel.orderId.toString();
        final orderData = await FireStoreUtils.getOrderByIdFromAllCollections(orderId);

        if (orderData != null) {
          final collection = orderData['collection_name'];

          switch (collection) {
            case CollectionName.parcelOrders:
              Get.to(const ParcelOrderDetails(), arguments: ParcelOrderModel.fromJson(orderData));
              break;
            case CollectionName.providerOrders:
              Get.to(const OnDemandOrderDetailsScreen(), arguments: OnProviderOrderModel.fromJson(orderData));
              break;
            case CollectionName.rentalOrders:
              Get.to(() => RentalOrderDetailsScreen(), arguments: RentalOrderModel.fromJson(orderData));
              break;
            case CollectionName.rides:
              Get.to(const CabOrderDetails(), arguments: {"cabOrderModel": CabOrderModel.fromJson(orderData)});
              break;
            case CollectionName.vendorOrders:
              Get.to(const OrderDetailsScreen(), arguments: {"orderModel": OrderModel.fromJson(orderData)});
              break;
            default:
              ShowToastDialog.showToast("Order details not available".tr);
          }
        }
      },
      // onTap: () async {
      //   await FireStoreUtils
      //       .getOrderByOrderId(transactionModel.orderId.toString())
      //       .then((value) {
      //         if (value != null) {
      //           Get.to(
      //             const OrderDetailsScreen(),
      //             arguments: {"orderModel": value},
      //           );
      //         }
      //       });
      // },
      child: Row(
        children: [
          DsIconWell(
            tone: isCredit ? DsTone.success : DsTone.danger,
            size: 44,
            child: SvgPicture.asset(
              isCredit ? "assets/icons/ic_credit.svg" : "assets/icons/ic_debit.svg",
              height: 18,
              width: 18,
              colorFilter: ColorFilter.mode(isCredit ? c.successStrong : c.dangerStrong, BlendMode.srcIn),
            ),
          ),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(transactionModel.note.toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodyStrong),
                const DsGap(DsSpace.xxs),
                Text(Constant.timestampToDateTime(transactionModel.date!), style: t.caption.tabular),
              ],
            ),
          ),
          const DsGap(DsSpace.sm),
          Text(
            Constant.amountShow(amount: transactionModel.amount.toString(), currency: controller.currencyFor(transactionModel)),
            style: t.titleSm.tabular.withColor(isCredit ? c.successStrong : c.dangerStrong),
          ),
        ],
      ),
    );
  }
}

/// Logged-out state (archetype K).
class _GuestState extends StatelessWidget {
  const _GuestState();

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DsSpace.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: DsFadeSlideIn(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset("assets/images/login.gif", height: 120),
                  const DsGap(DsSpace.lg),
                  Text("Please Log In to Continue".tr, textAlign: TextAlign.center, style: t.headline),
                  const DsGap(DsSpace.sm),
                  Text(
                    "You’re not logged in. Please sign in to access your account and explore all features.".tr,
                    textAlign: TextAlign.center,
                    style: t.body.withColor(c.textSecondary),
                  ),
                  const DsGap(DsSpace.xxl),
                  DsButton.primary(
                    label: "Log in".tr,
                    size: DsButtonSize.lg,
                    icon: Icons.login_rounded,
                    onPressed: () async {
                      Get.offAll(const LoginScreen());
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Balance hero + ledger skeleton.
class _WalletSkeleton extends StatelessWidget {
  const _WalletSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DsShimmer(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(DsSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: double.infinity, child: DsSkeleton.box(height: 170, radius: DsRadius.xxl)),
              const DsGap(DsSpace.xxl),
              DsSkeleton.line(width: 120, height: 14),
              const DsGap(DsSpace.lg),
              for (var i = 0; i < 5; i++) ...[
                SizedBox(width: double.infinity, child: DsSkeleton.box(height: 72, radius: DsRadius.lg)),
                const DsGap(DsSpace.sm),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum PaymentGateway { payFast, mercadoPago, paypal, stripe, flutterWave, payStack, razorpay, cod, wallet, midTrans, orangeMoney, xendit }
