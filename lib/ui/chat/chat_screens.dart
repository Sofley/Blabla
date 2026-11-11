import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/contract_stage.dart';
import '../../data/models/deal.dart';
import '../../state/chat_controller.dart';
import '../../state/deals_controller.dart';
import '../../state/settings_controller.dart';
import '../assistant/assistant_screen.dart';
import '../common/widgets.dart';

/// Human text of a message (system messages are stored as codes).
String chatText(AppStrings s, ChatMessage m) {
  if (!m.isSystem) return m.text;
  if (m.text == 'created') return s.chatDealCreated;
  if (m.text.startsWith('stage:')) {
    final stage = ContractStage.fromName(m.text.substring(6));
    return s.chatStageChanged(s.stage(stage));
  }
  return m.text;
}

/// "Чат / Observer" tab: one conversation per deal.
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key, this.actions = const []});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final deals = context.watch<DealsController>().deals;
    final chat = context.watch<ChatController>();
    final observer = context.watch<SettingsController>().observerMode;

    final sorted = [...deals]
      ..sort((a, b) {
        final la = chat.last(a.id)?.createdAt ?? a.updatedAt;
        final lb = chat.last(b.id)?.createdAt ?? b.updatedAt;
        return lb.compareTo(la);
      });

    return Scaffold(
      appBar: AppBar(title: Text(s.chatTitle), actions: actions),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: .15,
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: theme.colorScheme.primary,
                ),
              ),
              title: Text(s.assistantTitle),
              subtitle: Text('🟠 ${s.assistantSubtitle}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => AssistantScreen.open(context),
            ),
          ),
          const SizedBox(height: 10),
          _ObserverInfo(active: observer),
          const SizedBox(height: 12),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                s.chatNoDeals,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final d in sorted) ...[
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                leading: CircleAvatar(
                  backgroundColor: StageBadge.colorFor(
                    context,
                    d.stage,
                  ).withValues(alpha: .15),
                  child: Icon(
                    StageBadge.iconFor(d.stage),
                    color: StageBadge.colorFor(context, d.stage),
                    size: 20,
                  ),
                ),
                title: Text(
                  d.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  chat.last(d.id) == null
                      ? s.chatEmpty
                      : chatText(s, chat.last(d.id)!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      chat.last(d.id) == null
                          ? ''
                          : fmt.timeOrDate(chat.last(d.id)!.createdAt),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${chat.messages(d.id).length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                onTap: () => ChatScreen.open(context, d.id),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ObserverInfo extends StatelessWidget {
  const _ObserverInfo({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final color = active
        ? const Color(0xFFE0A000)
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.visibility : Icons.visibility_outlined,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              active ? s.observerActiveInfo : s.observerOffInfo,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Conversation of one deal.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.dealId});

  final String dealId;

  static Future<void> open(BuildContext context, String dealId) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => ChatScreen(dealId: dealId)));

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  ChatAuthor _author = ChatAuthor.me;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    await context.read<ChatController>().post(widget.dealId, _author, text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _share(Deal deal, List<ChatMessage> messages) async {
    final s = context.s;
    final fmt = Fmt.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final text = StringBuffer('${s.chatTitle}: ${deal.displayTitle}\n\n');
    for (final m in messages) {
      text.writeln(
        '[${fmt.dateTime(m.createdAt)}] ${s.chatAuthor(m.author)}: ${chatText(s, m)}',
      );
    }
    await SharePlus.instance.share(
      ShareParams(
        text: text.toString(),
        subject: '${s.chatTitle}: ${deal.displayTitle}',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final deal = context.watch<DealsController>().byId(widget.dealId);
    final messages = context.watch<ChatController>().messages(widget.dealId);
    final observer = context.watch<SettingsController>().observerMode;
    if (deal == null) return Scaffold(appBar: AppBar());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(deal.displayTitle, style: theme.textTheme.titleMedium),
            Text(
              s.stage(deal.stage),
              style: theme.textTheme.bodySmall?.copyWith(
                color: StageBadge.colorFor(context, deal.stage),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: s.shareAction,
            icon: const Icon(Icons.ios_share),
            onPressed: messages.isEmpty ? null : () => _share(deal, messages),
          ),
        ],
      ),
      body: Column(
        children: [
          if (observer)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFE0A000).withValues(alpha: .15),
              child: Row(
                children: [
                  const Icon(
                    Icons.visibility,
                    size: 18,
                    color: Color(0xFFE0A000),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.observerReadOnly,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        s.chatEmptyHint,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: messages.length,
                    itemBuilder: (_, i) => _Bubble(
                      message: messages[i],
                      onLongPress: observer || messages[i].isSystem
                          ? null
                          : () => context.read<ChatController>().deleteMessage(
                              messages[i],
                            ),
                    ),
                  ),
          ),
          if (!observer)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final a in ChatAuthor.values.where(
                            (a) => a != ChatAuthor.system,
                          )) ...[
                            ChoiceChip(
                              label: Text(s.chatAuthor(a)),
                              selected: _author == a,
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) => setState(() => _author = a),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(hintText: s.chatHint),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filled(
                          onPressed: _send,
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.onLongPress});

  final ChatMessage message;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final m = message;

    if (m.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${chatText(s, m)} · ${fmt.timeOrDate(m.createdAt)}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
      );
    }

    final mine = m.isMine;
    final bg = mine ? theme.colorScheme.primary : theme.colorScheme.surface;
    final fg = mine ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * .78,
          ),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mine ? 14 : 4),
              bottomRight: Radius.circular(mine ? 4 : 14),
            ),
            border: mine
                ? null
                : Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine)
                Text(
                  s.chatAuthor(m.author),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    letterSpacing: 0,
                  ),
                ),
              Text(
                m.text,
                style: theme.textTheme.bodyMedium?.copyWith(color: fg),
              ),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  fmt.timeOrDate(m.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: fg.withValues(alpha: .7),
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
