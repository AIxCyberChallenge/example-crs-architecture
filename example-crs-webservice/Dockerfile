from python:3.13.2-slim

WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app

# Install Python dependencies
RUN pip install -e .

WORKDIR /app/my_crs/task_server

CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "1324", "--log-config=../../log-conf.yaml"]