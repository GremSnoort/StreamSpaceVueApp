# StreamSpaceVueApp

Frontend (Vue + Vite) for StreamSpace.  
Backend is in `./backend` (Go + PostgreSQL Fat DB).

## Frontend run

Install dependencies:

```bash
npm install
```

Start dev server:

```bash
npm run dev -- --host 0.0.0.0 --port 5173
```

Frontend URL:

- `http://localhost:5173`

Backend API base for frontend is read from `.env`:

- `VITE_API_BASE=http://localhost:8080`

## Build

```bash
npm run build
```

## Backend quick start

1. Apply DB migrations (see `backend/migrations/README.md`).
2. Run backend:

```bash
cd backend
go run ./cmd/api
```

Backend health endpoint:

- `http://localhost:8080/healthz`
