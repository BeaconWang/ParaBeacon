import 'dart:convert';

import '../data/flight_data.dart';
import 'announcement_template.dart';

enum AnnouncementMetric {
  altitude,
  verticalSpeed,
  groundSpeed,
  windSpeed,
  temperature,
  pressure,
  battery,
  heartRate,
  heading;

  double valueFor(FlightData data) => switch (this) {
    altitude =>
      (data.hasFix || data.baroAltitude != null) ? data.altitude : double.nan,
    verticalSpeed => data.verticalSpeed,
    groundSpeed => data.hasGroundSpeed ? data.groundSpeed : double.nan,
    windSpeed => data.windSpeed,
    temperature => data.temperature?.toDouble() ?? double.nan,
    pressure => data.pressure ?? double.nan,
    battery => data.battery?.toDouble() ?? double.nan,
    heartRate => data.heartRate?.toDouble() ?? double.nan,
    heading => data.hasHeading ? data.heading : double.nan,
  };
}

enum AnnouncementCondition { greaterThan, lessThan, withinRange }

/// One user-configured live-data condition and its spoken content.
class CustomAnnouncementRule {
  const CustomAnnouncementRule({
    required this.id,
    required this.metric,
    required this.condition,
    required this.threshold,
    required this.upperThreshold,
    required this.repeatSeconds,
    required this.enabled,
    required this.content,
  });

  static const maxRules = 20;
  static const minRepeatSeconds = 1.0;
  static const maxRepeatSeconds = 60.0;

  final int id;
  final AnnouncementMetric metric;
  final AnnouncementCondition condition;
  final double threshold;
  final double upperThreshold;
  final double? repeatSeconds;
  final bool enabled;
  final String content;

  Duration? get repeatEvery => repeatSeconds == null
      ? null
      : Duration(milliseconds: (repeatSeconds! * 1000).round());

  bool matches(FlightData data) {
    final value = metric.valueFor(data);
    if (!value.isFinite) return false;
    return switch (condition) {
      AnnouncementCondition.greaterThan => value > threshold,
      AnnouncementCondition.lessThan => value < threshold,
      AnnouncementCondition.withinRange =>
        value >= threshold && value <= upperThreshold,
    };
  }

  CustomAnnouncementRule copyWith({
    AnnouncementMetric? metric,
    AnnouncementCondition? condition,
    double? threshold,
    double? upperThreshold,
    double? repeatSeconds,
    bool clearRepeat = false,
    bool? enabled,
    String? content,
  }) => CustomAnnouncementRule(
    id: id,
    metric: metric ?? this.metric,
    condition: condition ?? this.condition,
    threshold: threshold ?? this.threshold,
    upperThreshold: upperThreshold ?? this.upperThreshold,
    repeatSeconds: clearRepeat ? null : (repeatSeconds ?? this.repeatSeconds),
    enabled: enabled ?? this.enabled,
    content: AnnouncementTemplate.sanitize(content) ?? '',
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'metric': metric.name,
    'condition': condition.name,
    'threshold': threshold,
    'upperThreshold': upperThreshold,
    'repeatSeconds': repeatSeconds,
    'enabled': enabled,
    'content': AnnouncementTemplate.sanitize(content) ?? '',
  };

  static CustomAnnouncementRule? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['id'];
    final metricName = value['metric'];
    final conditionName = value['condition'];
    final threshold = value['threshold'];
    final upperThreshold = value['upperThreshold'];
    final content = value['content'];
    if (id is! int ||
        id < 0 ||
        metricName is! String ||
        conditionName is! String ||
        threshold is! num ||
        upperThreshold is! num ||
        content is! String) {
      return null;
    }
    final lowerValue = threshold.toDouble();
    final upperValue = upperThreshold.toDouble();
    if (!lowerValue.isFinite || !upperValue.isFinite) return null;
    final metric = AnnouncementMetric.values.where(
      (item) => item.name == metricName,
    );
    final condition = AnnouncementCondition.values.where(
      (item) => item.name == conditionName,
    );
    if (metric.isEmpty || condition.isEmpty) return null;
    final repeat = value['repeatSeconds'];
    final repeatValue = repeat is num ? repeat.toDouble() : null;
    if (repeatValue != null && !repeatValue.isFinite) return null;
    if (condition.first == AnnouncementCondition.withinRange &&
        upperValue < lowerValue) {
      return null;
    }
    return CustomAnnouncementRule(
      id: id,
      metric: metric.first,
      condition: condition.first,
      threshold: lowerValue,
      upperThreshold: upperValue,
      repeatSeconds: repeatValue
          ?.clamp(minRepeatSeconds, maxRepeatSeconds)
          .toDouble(),
      enabled: value['enabled'] is bool ? value['enabled'] as bool : true,
      content: AnnouncementTemplate.sanitize(content) ?? '',
    );
  }

  static String encodeList(List<CustomAnnouncementRule> rules) =>
      jsonEncode(rules.take(maxRules).map((rule) => rule.toJson()).toList());

  static List<CustomAnnouncementRule> decodeList(String? encoded) {
    if (encoded == null || encoded.length > 32768) return const [];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return const [];
      final rules = <CustomAnnouncementRule>[];
      final ids = <int>{};
      for (final item in decoded.take(maxRules)) {
        final rule = fromJson(item);
        if (rule != null && ids.add(rule.id)) rules.add(rule);
      }
      return rules;
    } on FormatException {
      return const [];
    }
  }
}
