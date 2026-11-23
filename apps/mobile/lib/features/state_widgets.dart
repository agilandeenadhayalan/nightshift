import 'package:flutter/material.dart';
import 'redesign/design_system.dart';

/// Shared progress state with the same visible and screen-reader description.
class LoadingNotice extends StatelessWidget {
  const LoadingNotice({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        label: label,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: NsColors.violet.withAlpha(20),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: NsColors.violet.withAlpha(45)),
                ),
                child: const CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: 16),
              Text(label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
            ]),
          ),
        ),
      );
}

/// Feature-specific failure presentation; the caller owns the retry operation.
class FailureNotice extends StatelessWidget {
  const FailureNotice({
    super.key,
    required this.title,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    this.reference,
    this.dismissLabel,
    this.onDismiss,
    this.offline = false,
  });
  final String title, message, retryLabel;
  final String? reference, dismissLabel;
  final VoidCallback? onRetry, onDismiss;
  final bool offline;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: NightshiftMessagePanel(
          title: title,
          message: message,
          icon: offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
          accent: Theme.of(context).colorScheme.error,
          details: reference == null
              ? null
              : SelectableText(reference!,
                  style: Theme.of(context).textTheme.bodySmall),
          action: onRetry == null && onDismiss == null
              ? null
              : Wrap(spacing: 8, runSpacing: 6, children: [
                  if (onRetry != null)
                    TextButton(onPressed: onRetry, child: Text(retryLabel)),
                  if (onDismiss != null && dismissLabel != null)
                    TextButton(
                        onPressed: onDismiss, child: Text(dismissLabel!)),
                ]),
        ),
      );
}
