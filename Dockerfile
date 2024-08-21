# syntax=docker/dockerfile:1

# Comments are provided throughout this file to help you get started.
# If you need more help, visit the Dockerfile reference guide at
# https://docs.docker.com/go/dockerfile-reference/

# Want to help us make this template better? Share your feedback here: https://forms.gle/ybq9Krt8jtBL3iCk7

# Build stage: This stage installs all necessary dependencies and builds the application
FROM pytorch/pytorch:2.0.1-cuda11.7-cudnn8-runtime AS builder

WORKDIR /app

# Set environment variable to prevent interactive prompts (tzdata select default geo)
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    python3-dev \
    libsndfile1 \
    cmake \
    && rm -rf /var/lib/apt/lists/*

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

# Create and activate a virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

## Upgrade pip and setuptools
#RUN pip install --upgrade pip setuptools

# Set ownership of the virtual environment to the non-root user
RUN chown -R appuser:appuser /opt/venv

# Copy application files and set correct ownership
COPY --chown=appuser:appuser . /app

# Switch to non-root user for subsequent commands
USER appuser

# Upgrade pip and install Python dependencies
RUN pip3 install --upgrade pip setuptools
RUN pip3 install --no-cache-dir torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu118
RUN pip3 install --no-cache-dir lit
RUN pip3 install --no-cache-dir -r requirements.txt
RUN pip3 install --no-cache-dir git+https://github.com/152334H/BigVGAN.git
RUN pip3 install --no-cache-dir fastapi uvicorn

# Runtime stage: Create a smaller, optimized image with only the necessary files
FROM pytorch/pytorch:2.0.1-cuda11.7-cudnn8-runtime

WORKDIR /app

# Install runtime system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

# Create the same non-root user as in the builder stage
ARG UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    appuser

# Copy application files and virtual environment from builder stage
COPY --from=builder --chown=appuser:appuser /app /app
COPY --from=builder --chown=appuser:appuser /opt/venv /opt/venv

# Set up environment to use venv
ENV PATH="/opt/venv/bin:$PATH"

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Switch to the non-privileged user
USER appuser

# Expose the port Streamlit is running on
EXPOSE 8000

# Command to run the FastAPI server
CMD ["uvicorn", "fastapi_app:app", "--host", "0.0.0.0", "--port", "8000"]