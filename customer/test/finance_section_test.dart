import 'package:customer/models/section_model.dart';
import 'package:customer/themes/ds/tokens/ds_section.dart';
import 'package:customer/utils/finance_section.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spideli Finance as a service of the service list.
void main() {
  SectionModel s(String id, String flag) => SectionModel(id: id, name: id, serviceTypeFlag: flag);
  final List<SectionModel> eight = [for (var i = 0; i < 8; i++) s('s$i', 'delivery-service')];

  test('without an admin finance section, the built-in one is added at the end', () {
    final all = FinanceSection.withFinance(eight);
    expect(all.length, 9);
    expect(all.last.id, FinanceSection.builtInId);
    expect(FinanceSection.isFinance(all.last), isTrue);
    expect(all.last.color, FinanceSection.color);
  });

  test('the admin\'s own finance section is used as it is', () {
    final mine = s('finance-doc', 'finance-service');
    final all = FinanceSection.withFinance([...eight, mine]);
    expect(all.where(FinanceSection.isFinance).single.id, 'finance-doc');
  });

  test('Finance is always on the circle, once', () {
    final all = FinanceSection.withFinance(eight);
    final circle = FinanceSection.onCircle(eight, all);
    expect(circle.length, 9);
    expect(circle.where(FinanceSection.isFinance).length, 1);
    // Already a favourite (the admin put their finance section there): unchanged.
    final mine = s('finance-doc', 'Finance-Service');
    expect(FinanceSection.onCircle([...eight.take(7), mine], [...eight, mine]).length, 8);
  });

  test('the finance section has its own design-system identity', () {
    expect(DsSection.fromServiceFlag('finance-service'), DsSection.finance);
    expect(DsSection.finance.icon, isNotNull);
  });
}
