import 'package:customer/constant/collection_name.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../../controllers/theme_controller.dart';

class TermsAndConditionScreen extends StatefulWidget {
  final String? type;

  const TermsAndConditionScreen({super.key, this.type});

  @override
  State<TermsAndConditionScreen> createState() => _TermsAndConditionScreenState();
}

class _TermsAndConditionScreenState extends State<TermsAndConditionScreen> {
  String _content = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchContent();
  }

  Future<void> _fetchContent() async {
    try {
      if (widget.type == "privacy") {
        final doc = await FireStoreUtils.fireStore.collection(CollectionName.settings).doc("privacyPolicy").get();
        if (doc.exists && doc.data() != null) {
          _content = doc.data()?["privacy_policy"] ?? "";
        }
      } else {
        final doc = await FireStoreUtils.fireStore.collection(CollectionName.settings).doc("termsAndConditions").get();
        if (doc.exists && doc.data() != null) {
          _content = doc.data()?["terms_and_condition"] ?? "";
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return Scaffold(
      backgroundColor: isDark ? AppThemeData.grey50 : AppThemeData.grey50,
      appBar: AppBar(
        backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
        centerTitle: false,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        leading: InkWell(
          onTap: () {
            Get.back();
          },
          child: Icon(Icons.chevron_left_outlined, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
        ),
        title: Text(
          widget.type == "privacy" ? "Privacy Policy".tr : "Terms & Conditions".tr,
          style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontFamily: AppThemeData.bold, fontSize: 18),
        ),
        elevation: 0,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(4.0), child: Container(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200, height: 4.0)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: SingleChildScrollView(child: Html(shrinkWrap: true, data: _content)),
            ),
    );
  }
}
