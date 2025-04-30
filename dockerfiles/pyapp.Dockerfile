FROM docker.io/library/python:3.12.10 AS compiler
ENV PYTHONUNBUFFERED 1

WORKDIR /app/

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY . .
RUN pip install flask

ENTRYPOINT [ "python3", "-m", "flask", "run"]
