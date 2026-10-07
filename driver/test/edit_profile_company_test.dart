import 'package:driver/controllers/edit_profile_controller.dart';
import 'package:driver/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Doc 38: the company part of the profile form is validated only when it
/// was edited, so a company or owner account without a `companyAddress` can
/// still save its name or photo.
void main() {
  EditProfileController company() => EditProfileController()..userModel.value = UserModel(id: 'c1', driverType: 'company');

  test('company part untouched: no company field is required', () {
    final EditProfileController controller = company();
    expect(controller.companyEdited, isFalse);
    expect(controller.companyValidationError(), isNull);
  });

  test('owner account without company details: still saves', () {
    final EditProfileController controller = EditProfileController()..userModel.value = UserModel(id: 'o1', isOwner: true);
    expect(controller.companyValidationError(), isNull);
  });

  test('company part edited: name and address are required', () {
    final EditProfileController controller = company();
    controller.companyFields['companyName']!.text = 'Acme';
    expect(controller.companyEdited, isTrue);
    expect(controller.companyValidationError(), 'Please enter the company address');
    controller.companyFields['companyAddress']!.text = 'Rue 1, Douala';
    expect(controller.companyValidationError(), isNull);
  });

  test('a document picked counts as an edit', () {
    final EditProfileController controller = company();
    controller.pendingCompanyFiles['companyRegistrationFile'] = '/tmp/x.png';
    expect(controller.companyValidationError(), 'Please enter company name');
  });
}
