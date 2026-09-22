import 'package:customer/controllers/service_list_controller.dart';
import 'package:customer/models/section_model.dart';
import 'package:customer/screen_ui/service_home_screen/service_list_screen.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/utils/home_services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The "More" services panel (spec 7.2 / 18.11): a search bar filtering the
/// services by name, the Favourites group (the 8 on the home circle), then
/// every region-available service under its `service_groups` heading, with
/// ungrouped services under "Others". Empty groups (also after a search) are
/// hidden. The data is prepared by [ServiceListController] / [HomeServices].
class MoreServicesSheet extends StatefulWidget {
  final ServiceListController controller;
  final bool isDark;

  const MoreServicesSheet({super.key, required this.controller, required this.isDark});

  static Future<void> show(BuildContext context, {required ServiceListController controller, required bool isDark}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => FractionallySizedBox(heightFactor: 1, child: MoreServicesSheet(controller: controller, isDark: isDark)),
    );
  }

  @override
  State<MoreServicesSheet> createState() => _MoreServicesSheetState();
}

class _MoreServicesSheetState extends State<MoreServicesSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(SectionModel section) {
    Navigator.of(context).pop();
    widget.controller.onServiceTap(Get.context ?? context, section);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDark;
    final List<ServiceGroupView> groups = [
      ServiceGroupView(id: '_favourites', title: 'Favourites'.tr, services: widget.controller.favouriteList.toList()),
      ...widget.controller.groupList,
    ];
    final List<ServiceGroupView> visible = [
      for (final g in groups)
        if (g.services.any((s) => HomeServices.matches(s, _query))) ServiceGroupView(id: g.id, title: g.title, services: g.services.where((s) => HomeServices.matches(s, _query)).toList()),
    ];

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? AppThemeData.greyDark300 : AppThemeData.grey300, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(child: Text("All services".tr, style: AppThemeData.boldTextStyle(fontSize: 18, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900))),
              IconButton(onPressed: () => Navigator.of(context).pop(), icon: Icon(Icons.close, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
            decoration: InputDecoration(
              hintText: "Search services".tr,
              prefixIcon: const Icon(Icons.search),
              suffixIcon:
                  _query.isEmpty
                      ? null
                      : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              filled: true,
              fillColor: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child:
              visible.isEmpty
                  ? Center(child: Text("No services found".tr, style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.grey300 : AppThemeData.grey700)))
                  : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final ServiceGroupView group = visible[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(group.title, style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900)),
                            const SizedBox(height: 10),
                            GridView.builder(
                              itemCount: group.services.length,
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, mainAxisExtent: 100),
                              itemBuilder: (context, i) => ServiceBubble(section: group.services[i], iconSize: 56, isDark: isDark, onTap: () => _open(group.services[i])),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
