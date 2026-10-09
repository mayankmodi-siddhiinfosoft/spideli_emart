/// Which `tax.country` values to look for (BUG-REPORT-01-APP §5 item 17,
/// Doc 61).
///
/// The admin panel saves a tax with the ENGLISH country name from its
/// `countriesdata.json` ("Cameroon"), but the device geocodes the customer's
/// position in the DEVICE language: a French phone in Yaoundé reports
/// `country: "Cameroun"`, `isoCountryCode: "CM"`, and
/// `tax where country == "Cameroun"` found none of the four Cameroon taxes.
///
/// So the country is normalised by its ISO code to the English name, and the
/// query asks for every candidate at once (`whereIn`, de-duplicated by tax doc
/// id): the name the device reported, the English name and its known English
/// aliases. Whatever language the phone is in, the admin's name is in the set,
/// and a tax saved under a native name keeps matching as it did before.
class TaxCountry {
  TaxCountry._();

  /// Firestore allows at most 30 values in a `whereIn`.
  static const int maxQueryValues = 30;

  /// Primary English name for [isoCode] ("CM" -> "Cameroon"), or null when the
  /// code is empty / unknown. When there is no code, a few non-English names
  /// seen in the field ("Cameroun") are recognised from [detectedName].
  static String? englishName(String? isoCode, {String? detectedName}) {
    final String? iso = isoFor(isoCode: isoCode, detectedName: detectedName);
    if (iso == null) return null;
    final List<String>? names = isoEnglishNames[iso];
    return (names == null || names.isEmpty) ? null : names.first;
  }

  /// Upper-case ISO 3166-1 alpha-2 code from [isoCode], or - when it is
  /// missing - from a known local-language [detectedName].
  static String? isoFor({String? isoCode, String? detectedName}) {
    final String code = (isoCode ?? '').trim().toUpperCase();
    if (code.length == 2 && isoEnglishNames.containsKey(code)) return code;
    final String name = _fold(detectedName);
    if (name.isEmpty) return null;
    final String? local = localNameIso[name];
    if (local != null) return local;
    // Already an English name ("Cameroon")?
    for (final MapEntry<String, List<String>> e in isoEnglishNames.entries) {
      if (e.value.any((n) => _fold(n) == name)) return e.key;
    }
    return null;
  }

  /// Every `tax.country` value worth asking for: [detectedName] as the device
  /// reported it, then the English name and its aliases. Trimmed, non-empty,
  /// de-duplicated (case-sensitive - Firestore is), at most [maxQueryValues].
  static List<String> queryNames({String? detectedName, String? isoCode}) {
    final List<String> out = [];
    void add(String? v) {
      final String s = (v ?? '').trim();
      if (s.isNotEmpty && !out.contains(s) && out.length < maxQueryValues) out.add(s);
    }

    add(detectedName);
    final String? iso = isoFor(isoCode: isoCode, detectedName: detectedName);
    if (iso != null) {
      for (final String n in isoEnglishNames[iso] ?? const <String>[]) {
        add(n);
      }
    }
    return out;
  }

  static String _fold(String? s) {
    String v = (s ?? '').trim().toLowerCase();
    const Map<String, String> accents = {'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ô': 'o', 'î': 'i', 'ï': 'i', 'â': 'a', 'à': 'a', 'ç': 'c', 'ü': 'u', 'û': 'u', '’': "'"};
    accents.forEach((k, r) => v = v.replaceAll(k, r));
    return v;
  }

  /// Local-language names (folded: lower case, no accents) for when the
  /// geocoder gives no ISO code. Central / West Africa first - the platform's
  /// markets - in French.
  static const Map<String, String> localNameIso = {
    'cameroun': 'CM',
    'kamerun': 'CM',
    'tchad': 'TD',
    'republique centrafricaine': 'CF',
    'guinee equatoriale': 'GQ',
    'republique du congo': 'CG',
    'republique democratique du congo': 'CD',
    "cote d'ivoire": 'CI',
    'senegal': 'SN',
    'benin': 'BJ',
    'nigeria': 'NG',
    'allemagne': 'DE',
    'etats-unis': 'US',
    'royaume-uni': 'GB',
    'belgique': 'BE',
    'suisse': 'CH',
    'espagne': 'ES',
    'italie': 'IT',
    'maroc': 'MA',
    'algerie': 'DZ',
    'tunisie': 'TN',
    'egypte': 'EG',
    'inde': 'IN',
    'chine': 'CN',
  };

  /// ISO 3166-1 alpha-2 -> English names; the FIRST is the primary name, the
  /// rest are English aliases also queried. Generated from the English list
  /// of the bundled `country_code_picker` package, with the formal UN-style
  /// names given their common form first ("Iran" before "Iran, Islamic
  /// Republic of").
  static const Map<String, List<String>> isoEnglishNames = {
  'AD': ['Andorra'],
  'AE': ['United Arab Emirates'],
  'AF': ['Afghanistan'],
  'AG': ['Antigua and Barbuda'],
  'AI': ['Anguilla'],
  'AL': ['Albania'],
  'AM': ['Armenia'],
  'AO': ['Angola'],
  'AQ': ['Antarctica'],
  'AR': ['Argentina'],
  'AS': ['American Samoa'],
  'AT': ['Austria'],
  'AU': ['Australia'],
  'AW': ['Aruba'],
  'AX': ['Åland Islands'],
  'AZ': ['Azerbaijan'],
  'BA': ['Bosnia and Herzegovina'],
  'BB': ['Barbados'],
  'BD': ['Bangladesh'],
  'BE': ['Belgium'],
  'BF': ['Burkina Faso'],
  'BG': ['Bulgaria'],
  'BH': ['Bahrain'],
  'BI': ['Burundi'],
  'BJ': ['Benin'],
  'BL': ['Saint Barthélemy'],
  'BM': ['Bermuda'],
  'BN': ['Brunei Darussalam'],
  'BO': ['Bolivia', 'Bolivia, Plurinational State of'],
  'BQ': ['Bonaire, Sint Eustatius and Saba'],
  'BR': ['Brazil'],
  'BS': ['Bahamas'],
  'BT': ['Bhutan'],
  'BV': ['Bouvet Island'],
  'BW': ['Botswana'],
  'BY': ['Belarus'],
  'BZ': ['Belize'],
  'CA': ['Canada'],
  'CC': ['Cocos (Keeling) Islands'],
  'CD': ['Democratic Republic of the Congo', 'Congo, the Democratic Republic of the', 'DR Congo'],
  'CF': ['Central African Republic'],
  'CG': ['Congo', 'Republic of the Congo'],
  'CH': ['Switzerland'],
  'CI': ['Cote D\'Ivoire', 'Côte d\'Ivoire', 'Ivory Coast'],
  'CK': ['Cook Islands'],
  'CL': ['Chile'],
  'CM': ['Cameroon'],
  'CN': ['China\'s Mainland'],
  'CO': ['Colombia'],
  'CR': ['Costa Rica'],
  'CU': ['Cuba'],
  'CV': ['Cape Verde'],
  'CW': ['Curaçao'],
  'CX': ['Christmas Island'],
  'CY': ['Cyprus'],
  'CZ': ['Czech Republic', 'Czechia'],
  'DE': ['Germany'],
  'DJ': ['Djibouti'],
  'DK': ['Denmark'],
  'DM': ['Dominica'],
  'DO': ['Dominican Republic'],
  'DZ': ['Algeria'],
  'EC': ['Ecuador'],
  'EE': ['Estonia'],
  'EG': ['Egypt'],
  'EH': ['Western Sahara'],
  'ER': ['Eritrea'],
  'ES': ['Spain'],
  'ET': ['Ethiopia'],
  'FI': ['Finland'],
  'FJ': ['Fiji'],
  'FK': ['Falkland Islands (Malvinas)'],
  'FM': ['Micronesia', 'Micronesia, Federated States of'],
  'FO': ['Faroe Islands'],
  'FR': ['France'],
  'GA': ['Gabon'],
  'GB': ['United Kingdom', 'UK', 'Great Britain'],
  'GD': ['Grenada'],
  'GE': ['Georgia'],
  'GF': ['French Guiana'],
  'GG': ['Guernsey'],
  'GH': ['Ghana'],
  'GI': ['Gibraltar'],
  'GL': ['Greenland'],
  'GM': ['Gambia'],
  'GN': ['Guinea'],
  'GP': ['Guadeloupe'],
  'GQ': ['Equatorial Guinea'],
  'GR': ['Greece'],
  'GS': ['South Georgia and the South Sandwich Islands'],
  'GT': ['Guatemala'],
  'GU': ['Guam'],
  'GW': ['Guinea-Bissau'],
  'GY': ['Guyana'],
  'HK': ['Hong Kong China'],
  'HM': ['Heard Island and McDonald Islands'],
  'HN': ['Honduras'],
  'HR': ['Croatia'],
  'HT': ['Haiti'],
  'HU': ['Hungary'],
  'ID': ['Indonesia'],
  'IE': ['Ireland'],
  'IL': ['Israel'],
  'IM': ['Isle of Man'],
  'IN': ['India'],
  'IO': ['British Indian Ocean Territory'],
  'IQ': ['Iraq'],
  'IR': ['Iran', 'Iran, Islamic Republic of'],
  'IS': ['Iceland'],
  'IT': ['Italy'],
  'JE': ['Jersey'],
  'JM': ['Jamaica'],
  'JO': ['Jordan'],
  'JP': ['Japan'],
  'KE': ['Kenya'],
  'KG': ['Kyrgyzstan'],
  'KH': ['Cambodia'],
  'KI': ['Kiribati'],
  'KM': ['Comoros'],
  'KN': ['Saint Kitts and Nevis'],
  'KP': ['North Korea'],
  'KR': ['South Korea'],
  'KW': ['Kuwait'],
  'KY': ['Cayman Islands'],
  'KZ': ['Kazakhstan'],
  'LA': ['Laos', 'Lao People\'s Democratic Republic'],
  'LB': ['Lebanon'],
  'LC': ['Saint Lucia'],
  'LI': ['Liechtenstein'],
  'LK': ['Sri Lanka'],
  'LR': ['Liberia'],
  'LS': ['Lesotho'],
  'LT': ['Lithuania'],
  'LU': ['Luxembourg'],
  'LV': ['Latvia'],
  'LY': ['Libya'],
  'MA': ['Morocco'],
  'MC': ['Monaco'],
  'MD': ['Moldova', 'Moldova, Republic of'],
  'ME': ['Montenegro'],
  'MF': ['Saint Martin (French part)'],
  'MG': ['Madagascar'],
  'MH': ['Marshall Islands'],
  'MK': ['North Macedonia', 'North Macedonia, Republic of'],
  'ML': ['Mali'],
  'MM': ['Myanmar'],
  'MN': ['Mongolia'],
  'MO': ['Macao China'],
  'MP': ['Northern Mariana Islands'],
  'MQ': ['Martinique'],
  'MR': ['Mauritania'],
  'MS': ['Montserrat'],
  'MT': ['Malta'],
  'MU': ['Mauritius'],
  'MV': ['Maldives'],
  'MW': ['Malawi'],
  'MX': ['Mexico'],
  'MY': ['Malaysia'],
  'MZ': ['Mozambique'],
  'NA': ['Namibia'],
  'NC': ['New Caledonia'],
  'NE': ['Niger'],
  'NF': ['Norfolk Island'],
  'NG': ['Nigeria'],
  'NI': ['Nicaragua'],
  'NL': ['Netherlands'],
  'NO': ['Norway'],
  'NP': ['Nepal'],
  'NR': ['Nauru'],
  'NU': ['Niue'],
  'NZ': ['New Zealand'],
  'OM': ['Oman'],
  'PA': ['Panama'],
  'PE': ['Peru'],
  'PF': ['French Polynesia'],
  'PG': ['Papua New Guinea'],
  'PH': ['Philippines'],
  'PK': ['Pakistan'],
  'PL': ['Poland'],
  'PM': ['Saint Pierre and Miquelon'],
  'PN': ['Pitcairn'],
  'PR': ['Puerto Rico'],
  'PS': ['State of Palestine', 'Palestine'],
  'PT': ['Portugal'],
  'PW': ['Palau'],
  'PY': ['Paraguay'],
  'QA': ['Qatar'],
  'RE': ['Reunion'],
  'RO': ['Romania'],
  'RS': ['Serbia'],
  'RU': ['Russian Federation', 'Russia'],
  'RW': ['Rwanda'],
  'SA': ['Saudi Arabia'],
  'SB': ['Solomon Islands'],
  'SC': ['Seychelles'],
  'SD': ['Sudan'],
  'SE': ['Sweden'],
  'SG': ['Singapore'],
  'SH': ['Saint Helena'],
  'SI': ['Slovenia'],
  'SJ': ['Svalbard and Jan Mayen'],
  'SK': ['Slovakia'],
  'SL': ['Sierra Leone'],
  'SM': ['San Marino'],
  'SN': ['Senegal'],
  'SO': ['Somalia'],
  'SR': ['Suriname'],
  'SS': ['South Sudan'],
  'ST': ['Sao Tome and Principe'],
  'SV': ['El Salvador'],
  'SX': ['Sint Maarten (Dutch part)'],
  'SY': ['Syria', 'Syrian Arab Republic'],
  'SZ': ['Eswatini'],
  'TC': ['Turks and Caicos Islands'],
  'TD': ['Chad'],
  'TF': ['French Southern Territories'],
  'TG': ['Togo'],
  'TH': ['Thailand'],
  'TJ': ['Tajikistan'],
  'TK': ['Tokelau'],
  'TL': ['Timor-Leste'],
  'TM': ['Turkmenistan'],
  'TN': ['Tunisia'],
  'TO': ['Tonga'],
  'TR': ['Turkey'],
  'TT': ['Trinidad and Tobago'],
  'TV': ['Tuvalu'],
  'TW': ['Taiwan'],
  'TZ': ['Tanzania', 'Tanzania, United Republic of'],
  'UA': ['Ukraine'],
  'UG': ['Uganda'],
  'UM': ['United States Minor Outlying Islands'],
  'US': ['United States', 'United States of America', 'USA'],
  'UY': ['Uruguay'],
  'UZ': ['Uzbekistan'],
  'VA': ['Vatican City', 'Holy See (Vatican City State)'],
  'VC': ['Saint Vincent and the Grenadines'],
  'VE': ['Venezuela', 'Venezuela, Bolivarian Republic of'],
  'VG': ['Virgin Islands, British'],
  'VI': ['Virgin Islands, U.S.'],
  'VN': ['Vietnam', 'Viet Nam'],
  'VU': ['Vanuatu'],
  'WF': ['Wallis and Futuna'],
  'WS': ['Samoa'],
  'XK': ['Kosovo'],
  'YE': ['Yemen'],
  'YT': ['Mayotte'],
  'ZA': ['South Africa'],
  'ZM': ['Zambia'],
  'ZW': ['Zimbabwe'],
  };
}
