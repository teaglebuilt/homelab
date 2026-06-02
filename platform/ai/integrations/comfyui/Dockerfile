FROM nvidia/cuda:12.1.1-runtime-ubuntu22.04

# Install system dependencies
RUN apt-get update && \
    apt-get install -y python3 python3-pip python3-venv git wget && \
    rm -rf /var/lib/apt/lists/*

# Create working directory
WORKDIR /app

# Clone ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /app

# Install Python dependencies
RUN pip3 install --no-cache-dir torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu121
RUN pip3 install GitPython

RUN pip3 install --no-cache-dir -r requirements.txt

# Expose the default ComfyUI port
EXPOSE 8188

# Start ComfyUI listening on all interfaces
CMD ["python3", "main.py", "--listen", "0.0.0.0"]
