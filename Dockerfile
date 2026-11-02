# --- Stage 1: build the React SPA ---
FROM node:22-slim AS frontend
RUN corepack enable
WORKDIR /frontend
COPY frontend/package.json frontend/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY frontend/ ./
RUN pnpm build   # -> /frontend/dist

# --- Stage 2: Python runtime ---
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim

# ffmpeg + spotDL power the optional local download mirror.
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

# spotDL as an isolated tool so its old pins never constrain the app's web stack
# (see downloads._spotdl_cmd, which finds it on PATH). It lives outside /root so
# it still runs when PUID/PGID drop the app to a regular user.
ENV UV_TOOL_DIR=/opt/uv-tools UV_TOOL_BIN_DIR=/usr/local/bin
RUN uv tool install spotdl

COPY main.py ./
COPY songmirror ./songmirror
COPY --from=frontend /frontend/dist ./frontend/dist

# SONGMIRROR_ENV_FILE points the engine at SettingsStore's managed env so wizard-saved
# credentials win over any stale .env.
ENV PYTHONUNBUFFERED=1 SONGMIRROR_DATA_DIR=/data SONGMIRROR_ENV_FILE=/data/app.env
EXPOSE 8080
# Runs the app as PUID:PGID when they are set (see docker-entrypoint.sh).
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/docker-entrypoint.sh && chmod 755 /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["uv", "run", "--no-sync", "uvicorn", "songmirror.web:app", "--host", "0.0.0.0", "--port", "8080"]
