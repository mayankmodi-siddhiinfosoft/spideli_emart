import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vendor/lang/app_ar.dart';
import 'package:vendor/lang/app_de.dart';
import 'package:vendor/lang/app_en.dart';
import 'package:vendor/lang/app_fr.dart';
import 'package:vendor/lang/app_hi.dart';
import 'package:vendor/lang/app_ja.dart';
import 'package:vendor/lang/app_pt.dart';
import 'package:vendor/lang/app_ru.dart';
import 'package:vendor/lang/app_zh.dart';
import 'package:vendor/utils/password_rule.dart';

/// Report 56: the password of a new employee / delivery man is checked before
/// Firebase is called (lib/utils/password_rule.dart).
void main() {
  test('six characters is the floor (Firebase)', () {
    expect(PasswordRule.minLength, 6);
    expect(PasswordRule.isLongEnough('12345'), isFalse);
    expect(PasswordRule.isLongEnough('123456'), isTrue);
    expect(PasswordRule.isLongEnough('a much longer password'), isTrue);
    expect(PasswordRule.isLongEnough(null), isFalse);
    expect(PasswordRule.isLongEnough(''), isFalse);
  });

  test('the trimmed length counts (the controllers trim before Firebase)', () {
    expect(PasswordRule.isLongEnough('  123  '), isFalse);
    expect(PasswordRule.isLongEnough(' 123456 '), isTrue);
  });

  test('field error: too short, none when long enough, none when empty', () {
    expect(PasswordRule.errorFor('abc'), PasswordRule.tooShort);
    expect(PasswordRule.errorFor('abcde'), PasswordRule.tooShort);
    expect(PasswordRule.errorFor('abcdef'), isNull);
    expect(PasswordRule.errorFor(''), isNull, reason: '"Please enter password" covers it');
    expect(PasswordRule.errorFor(null), isNull);
  });

  test('the stated number is the enforced one', () {
    expect(PasswordRule.hint, contains('${PasswordRule.minLength}'));
    expect(PasswordRule.tooShort, contains('${PasswordRule.minLength}'));
  });

  test('hint and error are translated in every language', () {
    for (final lang in [enUS, lnAr, deGR, trFR, hiIN, jaJP, ptPO, ruRU, zhCH]) {
      expect(lang[PasswordRule.hint], isNotNull);
      expect(lang[PasswordRule.tooShort], isNotNull);
    }
  });

  test('employee and delivery man forms check before Firebase and show both messages', () {
    for (final pair in [
      ['lib/controller/add_employee_controller.dart', 'lib/app/employee_screens/add_employee_screen.dart'],
      ['lib/controller/add_driver_controller.dart', 'lib/app/driver_screens/add_driver_screen.dart'],
    ]) {
      final String controller = File(pair[0]).readAsStringSync();
      final String screen = File(pair[1]).readAsStringSync();
      final int check = controller.indexOf('!checkPasswordLength()');
      expect(check, greaterThan(0), reason: pair[0]);
      expect(check, lessThan(controller.indexOf('createUserWithEmailAndPassword')), reason: pair[0]);
      expect(controller.contains('addListener(_clearFixedPasswordError)'), isTrue, reason: pair[0]);
      expect(screen.contains('helper: PasswordRule.hint.tr'), isTrue, reason: pair[1]);
      expect(screen.contains('error: controller.passwordError.value?.tr'), isTrue, reason: pair[1]);
      expect(screen.contains('controller.passwordError.value = null;'), isTrue, reason: pair[1]);
    }
  });
}
