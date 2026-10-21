import express from "express";
import familiesRouter from "./routes/families";
import healthRouter from "./routes/health";
import pushWebhookRouter from "./routes/pushWebhook";
import qrAuthRouter from "./routes/qrAuth";

export function createApp() {
  const app = express();
  app.use(express.json());
  app.use("/health", healthRouter);
  app.use("/families", familiesRouter);
  app.use("/auth/qr", qrAuthRouter);
  app.use("/webhooks/push", pushWebhookRouter);
  return app;
}
