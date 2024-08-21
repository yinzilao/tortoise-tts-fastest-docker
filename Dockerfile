# syntax=docker/dockerfile:1

# Comments are provided throughout this file to help you get started.
# If you need more help, visit the Dockerfile reference guide at
# https://docs.docker.com/go/dockerfile-reference/

# Want to help us make this template better? Share your feedback here: https://forms.gle/ybq9Krt8jtBL3iCk7

# Build stage: This stage installs all necessary dependencies and builds the application
FROM pytorch/pytorch:2.0.1-cuda11.7-cudnn8-runtime AS builder

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy the current directory contents into the container at /app
COPY . /app

# Install Python dependencies
RUN pip3 install --no-cache-dir torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu117 \
    && pip3 install --no-cache-dir -r requirements.txt \
    && pip3 install --no-cache-dir git+https://github.com/152334H/BigVGAN.git \
    && pip3 install --no-cache-dir fastapi uvicorn

# Runtime stage: Create a smaller, optimized image with only the necessary files
FROM pytorch/pytorch:2.0.1-cuda11.7-cudnn8-runtime

WORKDIR /app

# Copy only necessary files from builder stage
COPY --from=builder /app /app
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Create a non-privileged user for security
ARG UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    appuser

# Set proper permissions
RUN chown -R appuser:appuser /app

# Switch to the non-privileged user
USER appuser

# Expose the port Streamlit is running on
EXPOSE 8000

# Command to run the FastAPI server
CMD ["uvicorn", "fastapi_app:app", "--host", "0.0.0.0", "--port", "8000"]