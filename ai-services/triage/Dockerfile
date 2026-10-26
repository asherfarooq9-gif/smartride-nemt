FROM python:3.11.17-slim-trixie

WORKDIR /app

# No .pyc writes: production runs with a read-only root filesystem.
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1

RUN useradd --create-home --uid 10001 app

COPY requirements.txt .
# setuptools and wheel are build tools the app does not need at run time; removing
# them drops their known-vulnerable bundled code from the image.
RUN pip install --no-cache-dir -r requirements.txt \
    && pip uninstall -y setuptools wheel

COPY --chown=app:app main.py keywords.py ./

USER app

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8001/health', timeout=4)"

# Beyond 100 requests in flight uvicorn answers 503 at once; the backend then uses its
# own copy of the rules rather than queueing behind a saturated service.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001", "--limit-concurrency", "100"]
