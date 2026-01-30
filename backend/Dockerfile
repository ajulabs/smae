FROM node:24.3.0-bookworm-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends openssl && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app

RUN npm --loglevel=error install -g npm@11.4.2

COPY package.json package-lock.json ./
RUN npm ci

COPY prisma/schema.prisma ./prisma/
RUN npx prisma generate

COPY tools/install-duckdb-extensions.js ./tools/
RUN node tools/install-duckdb-extensions.js

COPY . .

ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN npm run build

# ===== RUNTIME =====
FROM node:24.3.0-bookworm-slim AS smae_api

# Instala o graphviz (dot) para gerar EAP do tarefas do lado do server-side
RUN apt-get update && apt-get install -y --no-install-recommends graphviz

# Instala as deps do wkhtmltopdf (html para PDF), que é um pouco mais simples que o WeasyPrint,
# muito mais leve do que usar o html-pdf-chrome ou Puppeteer
# pro nosso caso, ta otimo, nosso html é gerado por nos mesmos, então é safe
RUN apt-get install -y --no-install-recommends wkhtmltopdf fontconfig

RUN mkdir -p /usr/share/fonts/truetype/roboto

COPY ./fonts/* /usr/share/fonts/truetype/roboto/

RUN fc-cache -f -v

WORKDIR /usr/src/app

# Copia apenas os artefatos necessários do builder
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY --from=builder /usr/src/app/dist ./dist
COPY --from=builder /usr/src/app/prisma ./prisma
COPY --from=builder /usr/src/app/package.json ./
COPY --from=builder /usr/src/app/run-api.sh ./

RUN mkdir /usr/src/app/logs && \
    chown -R node:node /usr/src/app/logs /usr/src/app/node_modules/.prisma /usr/src/app/node_modules/@prisma
USER node

ARG NODE_ENV=production
ENV NODE_ENV=${NODE_ENV}
ENV USE_FILE_LOG=1
ENV PORT=3001
ENV NODE_OPTIONS="--max-old-space-size=4096"

HEALTHCHECK CMD node -e "const http=require('http');const req=http.get('http://localhost:'+(process.env.PORT||3001)+'/api/ping',res=>{res.resume();res.on('end',()=>process.exit(0));});req.on('error',()=>process.exit(1));req.setTimeout(2000,()=>{req.destroy();process.exit(1);});"

CMD ["./run-api.sh"]
