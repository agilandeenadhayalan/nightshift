part of '../screens.dart';

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: children),
      ));
}

class StatusCard extends StatelessWidget {
  const StatusCard(
      {super.key,
      required this.title,
      required this.message,
      this.icon = Icons.info_outline,
      this.action});
  final String title, message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => NightshiftMessagePanel(
      title: title, message: message, icon: icon, action: action);
}

class ErrorNotice extends ConsumerWidget {
  const ErrorNotice({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    if (state.error == null) return const SizedBox.shrink();
    return FailureNotice(
      offline: state.offline,
      title: state.offline
          ? state.text('Connection unavailable', 'இணைப்பு கிடைக்கவில்லை')
          : state.text('Please try again', 'மீண்டும் முயற்சிக்கவும்'),
      message: state.user == null
          ? '${errorMessage(state.errorCode, state.locale)} ${state.text('When ready, press Continue to NightShift.', 'தயாரானதும் NightShift தொடரவும் பொத்தானை அழுத்தவும்.')}'
          : errorMessage(state.errorCode, state.locale),
      reference: state.diagnosticId == null
          ? null
          : state.text('Reference: ${state.diagnosticId}',
              'குறிப்பு: ${state.diagnosticId}'),
      retryLabel: state.text('Refresh status', 'நிலையை புதுப்பி'),
      // Refresh never replays a side effect. Sign-in has its own submit button.
      onRetry: state.user == null || state.busy
          ? null
          : () {
              state.clearError();
              unawaited(state.refresh());
            },
      dismissLabel: state.text('Dismiss', 'மூடு'),
      onDismiss: state.clearError,
    );
  }
}
