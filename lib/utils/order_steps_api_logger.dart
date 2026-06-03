import 'dart:convert';

import 'package:eclapp/models/order_status_step.dart';
import 'package:eclapp/models/order_tracking_model.dart';
import 'package:flutter/foundation.dart';

/// Debug-only console logs for order timeline / status API payloads.
abstract final class OrderStepsApiLogger {
  static const _tag = '[ORDER_STEPS_API]';

  static const _stageTimestampKeys = [
    'created_at',
    'placed_at',
    'order_placed_at',
    'paid_at',
    'payment_at',
    'pending_confirmation_at',
    'confirmed_at',
    'order_confirmed_at',
    'ready_for_dispatch_at',
    'dispatch_ready_at',
    'dispatched_at',
    'shipped_at',
    'out_for_delivery_at',
    'arrived_at',
    'delivered_at',
    'completed_at',
    'picked_up_at',
    'status',
    'order_status',
    'status_history',
    'order_status_history',
  ];

  static void log(String message) {
    if (kDebugMode) debugPrint('$_tag $message');
  }

  static void logSection(String title) {
    if (kDebugMode) debugPrint('$_tag ── $title ──');
  }

  static void logJson(String label, Object? value) {
    if (!kDebugMode) return;
    debugPrint('$_tag $label:\n${_encode(value)}');
  }

  static void logSnapshotStageFields(
    String source, {
    Map<String, dynamic>? snapshot,
  }) {
    if (!kDebugMode) return;
    logSection('API snapshot ($source)');
    if (snapshot == null || snapshot.isEmpty) {
      log('(no order snapshot body)');
      return;
    }
    final subset = <String, dynamic>{};
    for (final key in _stageTimestampKeys) {
      if (snapshot.containsKey(key)) subset[key] = snapshot[key];
    }
    logJson('status / timestamps / history', subset);
  }

  static void logParsedStageTimes(Map<String, DateTime> times) {
    if (!kDebugMode) return;
    logSection('parsed stage timestamps');
    if (times.isEmpty) {
      log('(none)');
      return;
    }
    final lines = times.entries
        .map((e) => '  ${e.key}: ${e.value.toIso8601String()}')
        .join('\n');
    debugPrint('$_tag $lines');
  }

  static void logBuiltTimeline({
    required String source,
    required String rawStatus,
    required OrderTrackingStage stage,
    required List<OrderStatusStep> steps,
  }) {
    if (!kDebugMode) return;
    logSection('built timeline ($source)');
    log('raw status: "$rawStatus"');
    log('normalized stage: ${stage.name}');
    if (steps.isEmpty) {
      log('(no steps)');
      return;
    }
    for (final step in steps) {
      final flags = <String>[
        if (step.isCompleted) 'completed',
        if (step.isCurrent) 'current',
        if (!step.isCompleted && !step.isCurrent) 'pending',
      ].join(', ');
      final at = step.occurredAt?.toIso8601String() ?? '—';
      log('  • ${step.title} [${step.id}] ($flags) @ $at');
    }
  }

  static String _encode(Object? value) {
    if (value == null) return 'null';
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }
}
