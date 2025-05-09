FROM docker.io/library/python:3.12.10

WORKDIR /app

COPY . /app

RUN pip install --no-cache-dir -r requirements.txt

ENTRYPOINT [ "python","./main.py"]
