import 'package:flutter/material.dart';

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
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(label, textAlign: TextAlign.center),
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
        child: Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(offline ? Icons.wifi_off : Icons.error_outline),
                const SizedBox(height: 8),
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(message),
                if (reference != null) SelectableText(reference!),
                Wrap(spacing: 8, children: [
                  if (onRetry != null)
                    TextButton(onPressed: onRetry, child: Text(retryLabel)),
                  if (onDismiss != null && dismissLabel != null)
                    TextButton(
                        onPressed: onDismiss, child: Text(dismissLabel!)),
                ]),
              ],
            ),
          ),
        ),
      );
}
