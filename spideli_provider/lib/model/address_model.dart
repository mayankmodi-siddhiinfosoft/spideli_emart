import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/utils/address_format.dart';

class AddressModel {
  String? id;
  String? address;
  String? addressAs;
  String? landmark;
  String? locality;
  UserLocation? location;
  bool? isDefault;

  AddressModel({this.address, this.landmark, this.locality, this.location, this.isDefault, this.addressAs, this.id});

  AddressModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    address = json['address'];
    landmark = json['landmark'];
    locality = json['locality'];
    isDefault = json['isDefault'];
    addressAs = json['addressAs'];
    location = json['location'] == null ? null : UserLocation.fromJson(json['location']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['address'] = this.address;
    data['landmark'] = this.landmark;
    data['locality'] = this.locality;
    data['isDefault'] = this.isDefault;
    data['addressAs'] = this.addressAs;
    if (this.location != null) {
      data['location'] = this.location!.toJson();
    }
    return data;
  }

  /// Display form of the address. `locality` used to be interpolated without a
  /// guard, so a booking whose locality was never set rendered the literal word
  /// "null"; [formatAddressParts] drops that and collapses the separators.
  String getFullAddress() {
    return formatAddressParts(<Object?>[address, locality, landmark]);
  }
}
