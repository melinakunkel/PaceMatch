import 'package:flutter/material.dart';

import '../l10n/strings.dart';

enum SportType {
  laufen,
  radfahren,
  schwimmen,
  wandern,
  tennis,
  padel,
  schwangerschaftssport,
  hundeGassi,
  kinderSpielen,
  sonstige;

  static SportType fromDb(String value) => SportType.values.firstWhere(
    (s) => s.name == value,
    orElse: () => SportType.sonstige,
  );

  String get label {
    switch (this) {
      case SportType.laufen:
        return t('sport.laufen');
      case SportType.radfahren:
        return t('sport.radfahren');
      case SportType.schwimmen:
        return t('sport.schwimmen');
      case SportType.wandern:
        return t('sport.wandern');
      case SportType.tennis:
        return t('sport.tennis');
      case SportType.padel:
        return t('sport.padel');
      case SportType.schwangerschaftssport:
        return t('sport.schwangerschaftssport');
      case SportType.hundeGassi:
        return t('sport.hundeGassi');
      case SportType.kinderSpielen:
        return t('sport.kinderSpielen');
      case SportType.sonstige:
        return t('sport.sonstige');
    }
  }

  IconData get icon {
    switch (this) {
      case SportType.laufen:
        return Icons.directions_run;
      case SportType.radfahren:
        return Icons.directions_bike;
      case SportType.schwimmen:
        return Icons.pool;
      case SportType.wandern:
        return Icons.terrain;
      case SportType.tennis:
        return Icons.sports_tennis;
      case SportType.padel:
        return Icons.sports_tennis;
      case SportType.schwangerschaftssport:
        return Icons.pregnant_woman;
      case SportType.hundeGassi:
        return Icons.pets;
      case SportType.kinderSpielen:
        return Icons.child_care;
      case SportType.sonstige:
        return Icons.more_horiz;
    }
  }

  /// 'min_per_km' for pace-based sports, 'km_per_h' for speed-based ones,
  /// 'min_per_100m' for swimming.
  String get defaultUnit {
    switch (this) {
      case SportType.radfahren:
        return 'km_per_h';
      case SportType.schwimmen:
        return 'min_per_100m';
      default:
        return 'min_per_km';
    }
  }

  /// Whether a pace/speed makes sense for this sport. False for sports where
  /// a skill level fits better than a numeric pace.
  bool get usesPace =>
      this != SportType.tennis &&
      this != SportType.padel &&
      this != SportType.wandern &&
      this != SportType.schwangerschaftssport &&
      this != SportType.hundeGassi &&
      this != SportType.kinderSpielen;

  /// Whether a distance range makes sense for this sport. False for tennis,
  /// which isn't measured in km.
  bool get usesDistance =>
      this != SportType.tennis &&
      this != SportType.padel &&
      this != SportType.schwangerschaftssport &&
      this != SportType.hundeGassi &&
      this != SportType.kinderSpielen;

  /// Whether this sport typically needs a reserved venue (a court, a
  /// booked slot), so activities should ask whether the creator already
  /// has one or is still looking for one.
  bool get usesVenueQuestion =>
      this == SportType.tennis || this == SportType.padel;

  /// Whether a bike type (Rennrad, Mountainbike, ...) makes sense to ask.
  bool get usesBikeType => this == SportType.radfahren;

  /// Whether to ask if the creator has their own dog along — only for
  /// [SportType.hundeGassi].
  bool get usesDogQuestion => this == SportType.hundeGassi;

  /// Whether to ask for the child's age/gender — only for
  /// [SportType.kinderSpielen].
  bool get usesChildInfo => this == SportType.kinderSpielen;

  /// Whether a skill level (Anfänger/Fortgeschritten/Profi) makes sense —
  /// true for every non-pace sport except Hunde spazieren/Kinder spielen,
  /// which aren't really a "skill" someone has.
  bool get usesLevel =>
      this != SportType.hundeGassi && this != SportType.kinderSpielen;

  /// Whether a run type (normal/long run/speed run) makes sense to ask.
  bool get usesRunType => this == SportType.laufen;
}

enum BikeType {
  rennrad,
  mountainbike,
  gravel,
  trekking,
  ebike;

  static BikeType? fromDb(String? value) {
    if (value == null) return null;
    for (final b in BikeType.values) {
      if (b.name == value) return b;
    }
    return null;
  }

  String get label {
    switch (this) {
      case BikeType.rennrad:
        return t('bikeType.rennrad');
      case BikeType.mountainbike:
        return t('bikeType.mountainbike');
      case BikeType.gravel:
        return t('bikeType.gravel');
      case BikeType.trekking:
        return t('bikeType.trekking');
      case BikeType.ebike:
        return t('bikeType.ebike');
    }
  }
}

enum RunType {
  normal,
  longRun,
  speedRun;

  static RunType? fromDb(String? value) {
    if (value == null) return null;
    for (final r in RunType.values) {
      if (r.name == value) return r;
    }
    return null;
  }

  String get label {
    switch (this) {
      case RunType.normal:
        return t('runType.normal');
      case RunType.longRun:
        return t('runType.longRun');
      case RunType.speedRun:
        return t('runType.speedRun');
    }
  }
}
