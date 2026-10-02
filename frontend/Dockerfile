FROM node:22-alpine

WORKDIR /app
RUN npm install -g pnpm@9.5.0
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY . .

CMD ["pnpm", "dev"]
