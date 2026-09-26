import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/strings.dart';
import '../../models/message.dart';
import '../../services/giphy_service.dart';
import '../../theme/app_theme.dart';
import 'gif_picker_sheet.dart';

String formatMessageTime(DateTime dt) {
  final local = dt.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

/// One chat message: swipe right to reply, long press for reactions,
/// double tap for ❤️ — like WhatsApp.
class MessageRow extends StatefulWidget {
  const MessageRow({
    super.key,
    required this.message,
    required this.mine,
    required this.hasReply,
    required this.quoted,
    required this.quotedName,
    required this.reactions,
    required this.myEmoji,
    required this.onReply,
    required this.onLongPress,
    required this.onDoubleTap,
    required this.onReactionTap,
  });

  final ChatMessage message;
  final bool mine;

  /// It answers a message — [quoted] is null when that one is gone.
  final bool hasReply;
  final ChatMessage? quoted;
  final String? quotedName;
  final List<MessageReaction> reactions;
  final String? myEmoji;
  final VoidCallback onReply;
  final VoidCallback onLongPress;
  final VoidCallback onDoubleTap;
  final ValueChanged<String> onReactionTap;

  @override
  State<MessageRow> createState() => _MessageRowState();
}

class _MessageRowState extends State<MessageRow> {
  static const _replyThreshold = 60.0;
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final mine = widget.mine;
    final textColor = mine ? Colors.white : AppColors.textPrimary;

    Widget quote() {
      final q = widget.quoted;
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        decoration: BoxDecoration(
          color: mine
              ? Colors.white.withValues(alpha: 0.18)
              : AppColors.secondaryLight,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: mine ? Colors.white : AppColors.secondary,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (q != null)
              Text(
                widget.quotedName ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: textColor,
                ),
              ),
            Text(
              q == null
                  ? t('group.replyGone')
                  : (q.gifUrl != null ? 'GIF' : q.content),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: textColor.withValues(alpha: 0.85),
                fontStyle: q == null ? FontStyle.italic : null,
              ),
            ),
          ],
        ),
      );
    }

    final isGif =
        m.gifUrl != null && GiphyService.allowedUrl.hasMatch(m.gifUrl!);
    final Widget body;
    if (isGif) {
      body = Container(
        margin: const EdgeInsets.only(bottom: 2),
        constraints: const BoxConstraints(
          maxWidth: 220,
          maxHeight: 260,
          minWidth: 80,
          minHeight: 80,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: GifImage(url: m.gifUrl!),
        ),
      );
    } else {
      body = Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: mine ? AppColors.secondary : AppColors.surface,
          border: mine ? null : Border.all(color: AppColors.border),
          // The sharp corner points at the sender, like a speech bubble's
          // tail in WhatsApp/iMessage.
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.hasReply) quote(),
            // Time tucked into the bubble's corner: next to short texts,
            // on its own line under long ones.
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 8,
              children: [
                Text(m.content, style: TextStyle(color: textColor)),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    formatMessageTime(m.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: mine
                          ? Colors.white.withValues(alpha: 0.75)
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Same emoji from several people → one chip with a count.
    final counts = <String, int>{};
    for (final r in widget.reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (d) => setState(() {
        _drag = (_drag + d.delta.dx).clamp(0.0, _replyThreshold + 20);
      }),
      onHorizontalDragEnd: (_) {
        if (_drag >= _replyThreshold) {
          HapticFeedback.selectionClick();
          widget.onReply();
        }
        setState(() => _drag = 0);
      },
      onHorizontalDragCancel: () => setState(() => _drag = 0),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          if (_drag > 0)
            Opacity(
              opacity: (_drag / _replyThreshold).clamp(0.0, 1.0),
              child: Icon(Icons.reply, color: AppColors.secondary),
            ),
          Transform.translate(
            offset: Offset(_drag, 0),
            child: Align(
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: mine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onLongPress: widget.onLongPress,
                    onDoubleTap: widget.onDoubleTap,
                    child: body,
                  ),
                  if (counts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Wrap(
                        spacing: 4,
                        children: [
                          for (final e in counts.entries)
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => widget.onReactionTap(e.key),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: e.key == widget.myEmoji
                                      ? AppColors.secondaryLight
                                      : AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  e.value > 1 ? '${e.key} ${e.value}' : e.key,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  // GIFs have no bubble to hold the time.
                  if (isGif)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        formatMessageTime(m.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Antwort an Anna: …" above the input while replying.
class ReplyComposerBar extends StatelessWidget {
  const ReplyComposerBar({
    super.key,
    required this.name,
    required this.text,
    required this.onClose,
  });

  final String name;
  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: AppColors.secondary, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('group.replyTo', {'name': name}),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: t('common.close'),
            icon: const Icon(Icons.close, size: 20),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
