import 'package:customer/models/section_model.dart';

/// Spideli Finance as a service of the service list (the circle and "More"),
/// next to Restaurants, Parcel Service and the others.
///
/// A section the admin creates with `serviceTypeFlag: "finance-service"` is
/// used as it is (its name, image, colour and order). Without one, the app
/// adds a built-in Finance section, so the service is always offered. It
/// opens the Finance dashboard, never a store-type section: nothing of the
/// selected section (taxes, theme colour) is touched.
abstract final class FinanceSection {
  /// `sections/{id}.serviceTypeFlag` of the finance service.
  static const String flag = 'finance-service';

  /// Id of the built-in section (never a Firestore document).
  static const String builtInId = 'spideli-finance';

  /// Navy, the Finance identity.
  static const String color = '#0B2A4A';

  static bool isFinance(SectionModel? section) => (section?.serviceTypeFlag ?? '').trim().toLowerCase() == flag;

  /// The built-in section: shown with the finance icon (no image).
  static SectionModel builtIn() => SectionModel(
        id: builtInId,
        name: 'Spideli Finance',
        serviceTypeFlag: flag,
        color: color,
        sectionImage: '',
        isActive: true,
      );

  /// [sections] with Finance: the admin's own finance section when there is
  /// one, else the built-in one at the end.
  static List<SectionModel> withFinance(List<SectionModel> sections) => sections.any(isFinance) ? sections : [...sections, builtIn()];

  /// The services on the circle: [favourites] plus Finance (from [all]) when
  /// it is not among them, so it is always one tap away.
  static List<SectionModel> onCircle(List<SectionModel> favourites, List<SectionModel> all) {
    if (favourites.any(isFinance)) return favourites;
    final SectionModel finance = all.firstWhere(isFinance, orElse: builtIn);
    return [...favourites, finance];
  }
}
