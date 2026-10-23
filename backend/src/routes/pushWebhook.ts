import { Router } from "express";
import { z } from "zod";
import { dispatchPushNotifications } from "../lib/pushDispatch";
import { recipientsForMessage, recipientsForPraise } from "../lib/pushRecipients";
import { createSupabaseAdminClient } from "../lib/supabaseAdmin";
import { verifyWebhookSecret } from "../middleware/verifyWebhookSecret";

const router = Router();

// Supabase Database Webhook 페이로드 형태: { type, table, record, old_record, schema }
const webhookPayloadSchema = z.object({
  type: z.enum(["INSERT", "UPDATE", "DELETE"]),
  table: z.string(),
  record: z.record(z.unknown()),
});

router.post("/", verifyWebhookSecret, async (req, res) => {
  const parsed = webhookPayloadSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid webhook payload" });
    return;
  }

  if (parsed.data.type !== "INSERT") {
    res.status(200).json({ skipped: true });
    return;
  }

  const admin = createSupabaseAdminClient();
  const { table, record } = parsed.data;

  if (table === "messages") {
    const roomId = record.room_id as string;
    const senderId = record.sender_id as string;
    const isUrgent = Boolean(record.is_urgent);
    const body = record.body as string | null;

    const targets = await recipientsForMessage(admin, roomId, senderId);
    await dispatchPushNotifications(targets, {
      title: isUrgent ? "🚨 긴급 메시지" : "새 메시지",
      body: body ?? "새 소식이 도착했어요",
    });
  } else if (table === "praises") {
    const boardId = record.board_id as string;
    const text = record.text as string | null;

    const targets = await recipientsForPraise(admin, boardId);
    await dispatchPushNotifications(targets, {
      title: "⭐ 칭찬 도착!",
      body: text ?? "칭찬 스티커를 받았어요",
    });
  }

  res.status(200).json({ ok: true });
});

export default router;
