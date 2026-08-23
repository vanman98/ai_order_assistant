# AI Order Assistant API

NestJS modular monolith dùng Prisma và PostgreSQL.

## Chạy local

```bash
docker compose up -d
npm install
npx prisma migrate dev --name init_products
npm run start:dev
```

Kiểm tra:

```bash
curl http://localhost:3000/api/health
curl http://localhost:3000/api/products
```

PostgreSQL dùng port `5434` để tránh xung đột với database của project khác.

## Request flow

```text
HTTP Request
  -> ValidationPipe/DTO
  -> Controller
  -> Service
  -> Prisma
  -> PostgreSQL
```

Controller chỉ nhận request. Business rule nằm trong Service.
