import { NextFunction, Request, Response } from "express";

export function verifyWebhookSecret(
  req: Request,
  res: Response,
  next: NextFunction
) {
  const expected = process.env.PUSH_WEBHOOK_SECRET;
  const provided = req.header("x-webhook-secret");

  if (!expected || !provided || provided !== expected) {
    res.status(401).json({ error: "invalid webhook secret" });
    return;
  }

  next();
}
