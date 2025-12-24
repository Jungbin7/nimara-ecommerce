# Frontend Dockerfile for nimara-ecommerce (Next.js 15)
# Multi-stage build for optimized image size

# Stage 1: Dependencies installation
FROM node:22-alpine AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Install pnpm
RUN corepack enable && corepack prepare pnpm@9.15.9 --activate

# Copy root package files
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml turbo.json ./

# Copy package.json files for workspace dependencies
COPY packages/codegen/package.json ./packages/codegen/
COPY packages/config/package.json ./packages/config/
COPY packages/domain/package.json ./packages/domain/
COPY packages/eslint-config-custom/package.json ./packages/eslint-config-custom/
COPY packages/infrastructure/package.json ./packages/infrastructure/
COPY packages/tsconfig/package.json ./packages/tsconfig/
COPY packages/ui/package.json ./packages/ui/
COPY apps/storefront/package.json ./apps/storefront/

# Install dependencies
RUN pnpm install --frozen-lockfile

# Stage 2: Build application
FROM node:22-alpine AS builder
WORKDIR /app

# Install pnpm
RUN corepack enable && corepack prepare pnpm@9.15.9 --activate

# Copy dependencies from deps stage
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/packages ./packages
COPY --from=deps /app/apps/storefront/node_modules ./apps/storefront/node_modules

# Build arguments for environment variables
# Note: Using public Saleor demo API for codegen during build
# Actual API URL will be set via environment variables at runtime
ARG NEXT_PUBLIC_SALEOR_API_URL=https://demo.saleor.io/graphql/
ARG NEXT_PUBLIC_DEFAULT_CHANNEL=default-channel

# Set environment variables before copying files
# Core Saleor configuration
ENV NEXT_PUBLIC_SALEOR_API_URL=${NEXT_PUBLIC_SALEOR_API_URL}
ENV NEXT_PUBLIC_DEFAULT_CHANNEL=${NEXT_PUBLIC_DEFAULT_CHANNEL}
ENV SKIP_CODEGEN=true
ENV NODE_ENV=production

# Payment/Stripe configuration (빌드용 더미 값)
ENV PAYMENT_APP_ID=dummy-payment-app-id
ENV STRIPE_PUBLIC_KEY=pk_test_dummy_build_key
ENV NEXT_PUBLIC_PAYMENT_APP_ID=dummy-payment-app-id
ENV NEXT_PUBLIC_STRIPE_PUBLIC_KEY=pk_test_dummy_build_key
ENV STRIPE_SECRET_KEY=sk_test_dummy_build_key

# Server-side env vars (빌드용 더미 값, 런타임에 실제 값으로 교체)
ENV SALEOR_APP_TOKEN=dummy-saleor-token-for-build

# Storefront configuration
ENV NEXT_PUBLIC_STOREFRONT_URL=http://localhost:3000
ENV NEXT_PUBLIC_CMS_SERVICE=SALEOR
ENV NEXT_PUBLIC_SEARCH_SERVICE=SALEOR
ENV NEXT_PUBLIC_ENVIRONMENT=PRODUCTION
ENV NEXT_PUBLIC_DEFAULT_EMAIL=contact@mirumee.com
ENV NEXT_PUBLIC_DEFAULT_PAGE_TITLE="Nimara Storefront"

# Algolia search (빌드용 더미 값, 사용하지 않으면 무시됨)
ENV NEXT_PUBLIC_ALGOLIA_APP_ID=YOUR_APP_ID
ENV NEXT_PUBLIC_ALGOLIA_API_KEY=YOUR_API_KEY

# Optional CMS (빌드용, 사용하지 않으면 무시됨)
ENV NEXT_PUBLIC_BUTTER_CMS_API_KEY=

# Telemetry
ENV NEXT_TELEMETRY_DISABLED=1

# Copy all source files
COPY . .

# Debug: Verify environment variable (빌드 디버깅용, 나중에 제거 가능)
RUN echo "DEBUG: SKIP_CODEGEN is set to: $SKIP_CODEGEN" || true

# Build the storefront (skip codegen as it requires backend API)
# Codegen will be skipped via SKIP_CODEGEN=true environment variable
# Existing generated types from source code will be used
RUN pnpm run build:storefront

# Stage 3: Production image
FROM node:22-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Create non-root user
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy built application from builder
COPY --from=builder --chown=nextjs:nodejs /app/apps/storefront/.next ./apps/storefront/.next
COPY --from=builder --chown=nextjs:nodejs /app/apps/storefront/public ./apps/storefront/public
COPY --from=builder --chown=nextjs:nodejs /app/apps/storefront/package.json ./apps/storefront/
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nextjs:nodejs /app/packages ./packages

USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# Start the application
WORKDIR /app/apps/storefront
CMD ["pnpm", "start"]

