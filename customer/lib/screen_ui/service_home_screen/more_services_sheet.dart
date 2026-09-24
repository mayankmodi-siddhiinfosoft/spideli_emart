import 'package:customer/controllers/service_list_controller.dart';
import 'package:customer/models/section_model.dart';
import 'package:customer/screen_ui/service_home_screen/service_list_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/home_services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The "More" services panel (spec 7.2 / 18.11): a search bar filtering the
/// services by name, the Favourites group (the 8 on the home circle), then
/// every region-available service under its `service_groups` heading, with
/// ungrouped services under "Others". Empty groups (also after a search) are
/// hidden. The data is prepared by [ServiceListController] / [HomeServices].
///
/// Like the home circle, every tile is coloured from its own service colour,
/// so the panel never inherits the last-opened service's brand.
class MoreServicesSheet extends StatefulWidget {
  final ServiceListController controller;
  final bool isDark;

  const MoreServicesSheet({super.key, required this.controller, required this.isDark});

  static Future<void> show(BuildContext context, {required ServiceListController controller, required bool isDark}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: DsColors.of(context).surfaceRaised,
      shape: const RoundedRectangleBorder(borderRadius: DsRadius.sheetTop),
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
    final c = context.dsColors;
    final t = context.dsText;
    final l = context.dsLayout;
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
        const DsGap(DsSpace.sm),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: c.borderStrong, borderRadius: DsRadius.brPill)),
        Padding(
          padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.sm, DsSpace.sm, 0),
          child: Row(
            children: [
              Expanded(child: Text("All services".tr, style: t.headline.w700)),
              DsIconButton(icon: Icons.close_rounded, semanticLabel: "Close".tr, onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.sm, l.gutter, 0),
          child: DsSearchBar(
            controller: _search,
            hint: "Search services".tr,
            onChanged: (v) => setState(() => _query = v),
            onClear: () {
              _search.clear();
              setState(() => _query = '');
            },
          ),
        ),
        const DsGap(DsSpace.sm),
        Expanded(
          child: visible.isEmpty
              ? DsEmptyState(icon: Icons.search_off_rounded, title: "No services found".tr, message: "Try another name.".tr, compact: true)
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.sm, l.gutter, DsSpace.xxl),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final ServiceGroupView group = visible[index];
                    return DsFadeSlideIn(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: DsSpace.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DsSectionHeader(title: group.title, padding: const EdgeInsets.only(bottom: DsSpace.md)),
                            GridView.builder(
                              itemCount: group.services.length,
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: DsLayout.gridDelegate(maxItemWidth: 110, spacing: DsSpace.sm, mainAxisExtent: 108),
                              itemBuilder: (context, i) => ServiceBubble(section: group.services[i], iconSize: 56, isDark: widget.isDark, onTap: () => _open(group.services[i])),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
