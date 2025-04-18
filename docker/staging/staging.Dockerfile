# ----------------------------------------
# Estágio 1: Builder (Desenvolvimento/Compilação)
# ----------------------------------------
  FROM node:18-alpine AS builder

  WORKDIR /app
  
  # 1. Copiar e instalar todas as dependências
  COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* .npmrc* ./
  # Omit --production flag for TypeScript devDependencies
  RUN \
    if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
    elif [ -f package-lock.json ]; then npm ci; \
    elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm i; \
    # Allow install without lockfile, so example works even without Node.js installed locally
    else echo "Warning: Lockfile not found. It is recommended to commit lockfiles to version control." && yarn install; \
    fi
  
  # 2. Copiar arquivos do projeto
  COPY src ./src
  COPY public ./public
  COPY next.config.js .
  COPY tsconfig.json .
  
  # Environment variables must be present at build time
  # https://github.com/vercel/next.js/discussions/14030
  # ARG ENV_VARIABLE
  # ENV ENV_VARIABLE=${ENV_VARIABLE}
  # ARG NEXT_PUBLIC_ENV_VARIABLE
  # ENV NEXT_PUBLIC_ENV_VARIABLE=${NEXT_PUBLIC_ENV_VARIABLE}
  
  # Next.js collects completely anonymous telemetry data about general usage. Learn more here: https://nextjs.org/telemetry
  # Uncomment the following line to disable telemetry at build time
  # ENV NEXT_TELEMETRY_DISABLED 1
  
  # 4. Build da aplicação Next.js
  RUN \
    if [ -f yarn.lock ]; then yarn build; \
    elif [ -f package-lock.json ]; then npm run build; \
    elif [ -f pnpm-lock.yaml ]; then pnpm build; \
    else npm run build; \
    fi
  
  # Note: It is not necessary to add an intermediate step that does a full copy of `node_modules` here
  
  # ----------------------------------------
  # Estágio 2: Runner (Produção Otimizada)
  # ----------------------------------------
  FROM base AS runner
  
  WORKDIR /app
  
  ENV NODE_ENV production
  
  # Configura usuário não-root
  RUN addgroup --system --gid 1001 nodejs
  RUN adduser --system --uid 1001 nextjs
  USER nextjs
  
  COPY --from=builder /app/public ./public
  
  # Automatically leverage output traces to reduce image size
  # https://nextjs.org/docs/advanced-features/output-file-tracing
  COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
  COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
  
  
  # Instala APENAS dependências de produção
  RUN npm ci --omit=dev
  
  # Environment variables must be redefined at run time
  # ARG ENV_VARIABLE
  # ENV ENV_VARIABLE=${ENV_VARIABLE}
  # ARG NEXT_PUBLIC_ENV_VARIABLE
  # ENV NEXT_PUBLIC_ENV_VARIABLE=${NEXT_PUBLIC_ENV_VARIABLE}
  
  # Uncomment the following line to disable telemetry at run time
  # ENV NEXT_TELEMETRY_DISABLED 1
  
  # Note: Don't expose ports here, Compose will handle that for us
  
  EXPOSE 3000
  
  CMD ["node", "server.js"]
  # CMD ["npm", "start"]