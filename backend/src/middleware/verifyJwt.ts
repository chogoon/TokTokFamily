import { NextFunction, Request, Response } from "express";
import { createSupabaseAdminClient } from "../lib/supabaseAdmin";

export interface AuthedRequest extends Request {
  authUserId?: string;
  accessToken?: string;
}

export async function verifyJwt(
  req: AuthedRequest,
  res: Response,
  next: NextFunction
) {
  const header = req.header("authorization");
  const token = header?.startsWith("Bearer ") ? header.slice(7) : undefined;

  if (!token) {
    res.status(401).json({ error: "missing bearer token" });
    return;
  }

  const admin = createSupabaseAdminClient();
  const { data, error } = await admin.auth.getUser(token);

  if (error || !data.user) {
    res.status(401).json({ error: "invalid token" });
    return;
  }

  req.authUserId = data.user.id;
  req.accessToken = token;
  next();
}
