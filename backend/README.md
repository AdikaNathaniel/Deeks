# Deeks Backend — Microservices

Five independent NestJS services behind an nginx API gateway.

## Services

| Service           | Port | Database        | Auth            |
|-------------------|------|-----------------|-----------------|
| auth-service      | 3000 | `auth_db`       | public          |
| meetings-service  | 3001 | `meetings_db`   | JWT required    |
| links-service     | 3002 | `links_db`      | JWT required    |
| passwords-service | 3003 | `passwords_db`  | JWT required, E2E ciphertext only |
| notes-service     | 3004 | `notes_db`      | JWT required    |
| gateway (nginx)   | 80   | —               | —               |

## Routes (via gateway)

- `POST   /api/auth/register`        — create account, returns JWT
- `POST   /api/auth/login`           — returns JWT
- `GET    /api/meetings`             — list
- `POST   /api/meetings`             — create
- `GET    /api/meetings/:id`         — one
- `PATCH  /api/meetings/:id`         — update
- `DELETE /api/meetings/:id`         — delete
- `GET/POST/GET :id/PATCH :id/DELETE :id` — same shape for `/api/links`, `/api/passwords`, `/api/notes`

## Local dev

```bash
cp .env.example .env          # set JWT_SECRET
docker compose up --build
```

Gateway is at `http://localhost`. Health check: `curl http://localhost/health`.

## Production (AWS Free Tier)

One EC2 `t2.micro` running docker-compose with the prod override and MongoDB Atlas M0 (free):

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

Set `MONGO_URI_*` env vars to Atlas connection strings (one logical DB per service).

## E2E encryption note

`passwords-service` stores only ciphertext + IV. Encryption/decryption happens on the
mobile device using a key derived from the user's master PIN. Even full DB read access
cannot reveal stored passwords.
