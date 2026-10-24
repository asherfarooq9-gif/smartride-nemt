FROM python:3.11.17-slim-trixie

WORKDIR /app

# No .pyc writes: production runs with a read-only root filesystem.
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1

# Run as an unprivileged user: a bug in the app must not be root in the container.
RUN useradd --create-home --uid 10001 app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY --chown=app:app . .

RUN chmod +x entrypoint.sh

USER app

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=4)"

CMD ["./entrypoint.sh"]
