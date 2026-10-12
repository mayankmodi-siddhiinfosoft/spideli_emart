import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/employee_role_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/store_chat.dart';

/// The signed-in user's [StoreChatIdentity], read from Firestore (the rules
/// themselves are in [StoreChat]).
class StoreChatSession {
  StoreChatSession._();

  /// Whether the signed-in user may open the store's chats, from what the
  /// session already holds (the profile and the employee's role). Used to
  /// show or hide the chat entries; the screens re-check with [resolve].
  static bool get canChat => StoreChat.allowed(role: Constant.userModel?.role, permissions: Constant.employeeRoleModel?.permissions);

  /// The signed-in user is an employee of the store.
  static bool get isEmployee => StoreChat.isEmployee(Constant.userModel?.role);

  static String _storeKey = '';
  static VendorModel? _store;
  static UserModel? _owner;

  /// The store side of the chats for the signed-in user; null when nobody is
  /// signed in or the profile cannot be read. For an employee the store and
  /// its owner are read once per store and kept (the owner of a store does
  /// not change).
  static Future<StoreChatIdentity?> resolve() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      UserModel? me = Constant.userModel;
      // getUserById, never getUserProfile: that one also makes the user it
      // reads the session's user.
      if (me?.id != user.uid) me = await FireStoreUtils.getUserById(user.uid);
      if (me == null) return null;

      if (!StoreChat.isEmployee(me.role)) {
        return StoreChatIdentity.of(uid: user.uid, role: me.role, actorName: me.fullName(), ownPhoto: me.profilePictureURL);
      }

      final String vendorId = (me.vendorID ?? '').trim();
      if (vendorId != _storeKey || _store == null || (_store?.author ?? '').trim().isEmpty) {
        _store = await FireStoreUtils.getVendorById(vendorId);
        final String ownerId = (_store?.author ?? '').trim();
        _owner = ownerId.isEmpty ? null : await FireStoreUtils.getUserById(ownerId);
        _storeKey = vendorId;
      }

      // The role is read fresh (one document): the owner may have just
      // ticked or cleared its "Chat" permission. The session's copy is the
      // fallback when the read fails.
      final String roleId = (me.employeePermissionId ?? '').trim();
      EmployeeRoleModel? role = roleId.isEmpty ? null : await FireStoreUtils.getEmployeeRoleById(roleId);
      if (role != null && Constant.userModel?.id == user.uid) Constant.employeeRoleModel = role;
      role ??= Constant.employeeRoleModel?.id == roleId ? Constant.employeeRoleModel : null;

      return StoreChatIdentity.of(
        uid: user.uid,
        role: me.role,
        actorName: me.fullName(),
        storeOwnerId: _store?.author,
        ownerName: _owner?.fullName(),
        storeName: _store?.title,
        storePhoto: _store?.photo,
        permissions: roleId.isEmpty ? null : role?.permissions,
      );
    } catch (e) {
      log("store chat identity: $e");
      return null;
    }
  }
}
