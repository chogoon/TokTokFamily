# syntax=docker/dockerfile:1
#
# Family TokTok backend (Express + TypeScript) — 멀티스테이지 Dockerfile.
#
# 이 저장소는 npm workspaces 모노레포(frontend/, backend/)라서, backend만
# 빌드/실행하더라도 루트 package.json(workspaces 선언)과 package-lock.json이
# 함께 있어야 `npm ci`가 workspace 의존성 트리를 올바르게 구성한다.
#
# 그래서 빌드 컨텍스트는 "backend/" 단독이 아니라 저장소 루트여야 한다.
# 반드시 아래처럼 루트에서, -f로 이 Dockerfile을 지정해서 빌드할 것:
#
#   docker build -f backend/Dockerfile -t family-toktok-backend .
#
# 루트의 .dockerignore가 frontend/, flutter/, node_modules/ 등을 빌드
# 컨텍스트에서 제외하므로, 컨텍스트가 루트여도 전송되는 내용은 backend
# 빌드에 필요한 최소 파일(루트 package*.json + backend/)로 제한된다.

# node:22 사용 이유: @supabase/supabase-js(및 하위 @supabase/* 패키지)가 Node 22+를
# 요구하며, Node 20에서는 "Node.js 20 and below are deprecated" 런타임 경고가 뜬다.
# 루트 package.json의 engines(">=20")는 로컬 개발 환경의 하한선이고, 이미지는
# 그보다 최신인 22를 쓴다.

# ---- deps stage: workspace 의존성 설치 (devDependencies 포함, tsc 빌드에 필요) ----
FROM node:22-slim AS deps
WORKDIR /app
COPY package.json package-lock.json ./
COPY backend/package.json backend/package.json
# 루트에서 설치해야 workspaces(frontend/backend) 선언에 따라 backend 의존성이
# backend/node_modules(또는 루트 node_modules의 workspace 심링크)에 제대로
# 배치된다. frontend/ 디렉토리 자체는 컨텍스트에 없지만(.dockerignore로 제외),
# npm은 package.json의 workspaces 목록에 없는 디렉토리가 없어도 --workspace로
# 특정 workspace만 설치할 수 있다.
RUN npm ci --workspace=backend

# ---- build stage: TypeScript 컴파일 ----
FROM deps AS build
WORKDIR /app
COPY backend/ backend/
# backend/.env가 로컬에 있더라도 .dockerignore로 제외되어 이미지에 들어가지
# 않는다 — 운영 환경변수는 호스팅 플랫폼(Railway/Render)이 런타임에 주입한다.
RUN npm run build --workspace=backend

# ---- deps-prod stage: production 의존성만 별도로 설치 ----
FROM node:22-slim AS deps-prod
WORKDIR /app
COPY package.json package-lock.json ./
COPY backend/package.json backend/package.json
RUN npm ci --workspace=backend --omit=dev

# ---- runtime stage: 컴파일된 dist/ + production 의존성만 포함 ----
FROM node:22-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY --from=deps-prod /app/node_modules ./node_modules
COPY --from=build /app/backend/dist ./backend/dist
COPY backend/package.json ./backend/package.json

WORKDIR /app/backend
EXPOSE 4000
# start 스크립트(`node --env-file=.env dist/index.js`)는 로컬 개발용으로
# backend/.env 파일 존재를 가정한다. 운영 이미지에는 .env 파일이 없고
# 환경변수는 호스팅 플랫폼이 프로세스 환경으로 직접 주입하므로, --env-file
# 없이 dist/index.js를 바로 실행한다.
CMD ["node", "dist/index.js"]
