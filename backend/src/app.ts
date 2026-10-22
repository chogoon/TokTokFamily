import cors from "cors";
import express from "express";
import familiesRouter from "./routes/families";
import healthRouter from "./routes/health";
import pushWebhookRouter from "./routes/pushWebhook";
import qrAuthRouter from "./routes/qrAuth";

export function createApp() {
  const app = express();
  // Expo 웹 개발 서버(localhost:8081 등)에서 호출하므로 CORS가 필요하다. 네이티브
  // 앱(iOS/Android)은 브라우저가 아니라 CORS 제약을 받지 않는다. 운영 배포 시
  // CORS_ORIGIN을 실제 웹 배포 도메인으로 좁힐 것 — 비워두면 전체 허용(dev 기본값).
  app.use(cors({ origin: process.env.CORS_ORIGIN?.split(",") ?? true }));
  app.use(express.json());
  app.use("/health", healthRouter);
  app.use("/families", familiesRouter);
  // qrAuthRouter가 /qr/*(QR 스캔)과 /code/*(숫자 코드 입력) 양쪽을 다루므로
  // "/auth"에 마운트한다 — 각 라우트가 전체 경로(/qr/issue 등)를 직접 정의한다.
  app.use("/auth", qrAuthRouter);
  app.use("/webhooks/push", pushWebhookRouter);
  return app;
}
