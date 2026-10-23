# syntax=docker/dockerfile:1.7
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim AS builder

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=0

RUN uv venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt /build/requirements.txt
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install -r /build/requirements.txt

FROM python:3.12-slim-bookworm AS runtime

RUN groupadd --gid 1000 app \
 && useradd --uid 1000 --gid app --create-home --home-dir /home/app app

COPY --from=builder /opt/venv /opt/venv
COPY --chown=1000:1000 app.py /app/app.py

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONPATH=/app \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    HOME=/home/app

WORKDIR /app
USER 1000:1000
EXPOSE 3000

ENTRYPOINT ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "3000"]
