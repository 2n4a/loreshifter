FROM python:3.14

WORKDIR /code

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

COPY ./backend/pyproject.toml /code/

RUN pip install --no-cache-dir --upgrade .

COPY ./backend /code/

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
   CMD curl -f http://localhost:8000/api/v0/liveness || exit 1

CMD ["fastapi", "run", "main.py", "--port", "8000", "--proxy-headers"]
