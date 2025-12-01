cd ~
mkdir -p den-infra
cd den-infra

cat > install.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

AI_STACK_DIR="${REPO_ROOT}/ai-stack"
RESEARCH_STACK_DIR="${REPO_ROOT}/research-stack"
COMFY_DIR="${REPO_ROOT}/comfyui"

THINKTANK="/mnt/thinktank"
CURRENT_USER="${SUDO_USER:-$USER}"

echo "[*] Ensuring base directories exist on ${THINKTANK}..."
sudo mkdir -p \
  "${THINKTANK}/models" \
  "${THINKTANK}/openwebui-data" \
  "${THINKTANK}/research-stack/litellm-config" \
  "${THINKTANK}/research-stack/zotero-pdfs" \
  "${THINKTANK}/research-stack/vector-store" \
  "${THINKTANK}/research-stack/db-postgres-r" \
  "${THINKTANK}/research-stack/db-postgres-py" \
  "${THINKTANK}/research-stack/pgadmin" \
  "${THINKTANK}/research-stack/notebooks" \
  "${THINKTANK}/research-stack/shared" \
  "${THINKTANK}/research-stack/research-files" \
  "${THINKTANK}/research-stack/rstudio-home" \
  "${THINKTANK}/research-stack/jupyter-home" \
  "${THINKTANK}/comfyui/checkpoints" \
  "${THINKTANK}/comfyui/loras" \
  "${THINKTANK}/comfyui/vae"

if [ -d "${RESEARCH_STACK_DIR}/litellm-config" ]; then
  echo "[*] Syncing LiteLLM config to thinktank..."
  sudo cp -n "${RESEARCH_STACK_DIR}/litellm-config/"* \
    "${THINKTANK}/research-stack/litellm-config/" || true
fi

# Generate .env for research stack if missing
ENV_FILE="${RESEARCH_STACK_DIR}/.env"
if [ ! -f "${ENV_FILE}" ]; then
  echo "[*] Generating research-stack/.env with random secrets..."
  POSTGRESPASSWORD=$(openssl rand -base64 32)
  PYTHONPOSTGRESPASSWORD=$(openssl rand -base64 32)
  RSTUDIOPASSWORD=$(openssl rand -base64 32)
  JUPYTERTOKEN=$(openssl rand -base64 24)
  PGADMINEMAIL="admin@example.com"
  PGADMINPASSWORD=$(openssl rand -base64 32)
  LITELLMMASTERKEY=$(openssl rand -base64 48)

  cat > "${ENV_FILE}" <<EOF_ENV
POSTGRESPASSWORD=${POSTGRESPASSWORD}
PYTHONPOSTGRESPASSWORD=${PYTHONPOSTGRESPASSWORD}
RSTUDIOPASSWORD=${RSTUDIOPASSWORD}
JUPYTERTOKEN=${JUPYTERTOKEN}
PGADMINEMAIL=${PGADMINEMAIL}
PGADMINPASSWORD=${PGADMINPASSWORD}
LITELLMMASTERKEY=${LITELLMMASTERKEY}
EOF_ENV

  echo "[*] Created ${ENV_FILE}"
else
  echo "[*] Using existing ${ENV_FILE}"
fi

echo "[*] Installing ComfyUI setup script..."
sudo install -Dm755 "${COMFY_DIR}/setup-comfyui.sh" /usr/local/sbin/setup-comfyui.sh

echo "[*] Rendering comfyui.service for current user (${CURRENT_USER})..."
TMP_SERVICE="/tmp/comfyui.service.$$"
sed "s/YOUR_BAZZITE_USER/${CURRENT_USER}/" "${COMFY_DIR}/comfyui.service" > "${TMP_SERVICE}"

echo "[*] Installing comfyui.service..."
sudo install -Dm644 "${TMP_SERVICE}" /etc/systemd/system/comfyui.service
rm -f "${TMP_SERVICE}"

echo "[*] Running ComfyUI setup script (may take a while on first run)..."
sudo /usr/local/sbin/setup-comfyui.sh

echo "[*] Enabling ComfyUI service..."
sudo systemctl daemon-reload
sudo systemctl enable --now comfyui.service

echo "[*] Ensuring Podman network 'ai_net' exists..."
if ! podman network inspect ai_net >/dev/null 2>&1; then
  podman network create ai_net
fi

echo "[*] Bringing up AI stack via podman compose..."
cd "${AI_STACK_DIR}"
podman compose -f podman-compose.ai.yml up -d

echo "[*] Bringing up research stack via podman compose..."
cd "${RESEARCH_STACK_DIR}"
podman compose -f podman-compose.research.yml --env-file .env up -d

echo
echo "[*] Installation complete."
echo "    - ComfyUI: http://den-baz:8188"
echo "    - Open WebUI: http://den-baz:3000"
echo "    - LiteLLM proxy: http://den-baz:4000"
echo "    - PaperQA2: http://den-baz:4100 (placeholder)"
echo "    - RStudio: http://den-baz:8787"
echo "    - JupyterLab: http://den-baz:8888"
echo "    - pgAdmin: http://den-baz:5050"
EOF

mkdir -p ai-stack
cat > ai-stack/podman-compose.ai.yml << 'EOF'
version: "3.9"

services:
  localai-cpu:
    image: localai/localai:latest
    container_name: localai-cpu
    restart: unless-stopped
    environment:
      - LOCALAI_MODELS_PATH=/models
      - LOCALAI_OPENAI_COMPATIBLE=true
      - LOCALAI_HOST=0.0.0.0
      - LOCALAI_PORT=8081
      - LOCALAI_FORCE_META_BACKEND_CAPABILITY=default
    volumes:
      - /mnt/thinktank/models:/models:z
    ports:
      - "8081:8081"
    networks:
      - ai_net

  localai-vulkan:
    image: localai/localai:latest-gpu-vulkan
    container_name: localai-vulkan
    restart: unless-stopped
    environment:
      - LOCALAI_MODELS_PATH=/models
      - LOCALAI_OPENAI_COMPATIBLE=true
      - LOCALAI_HOST=0.0.0.0
      - LOCALAI_PORT=8080
    volumes:
      - /mnt/thinktank/models:/models:z
    devices:
      - /dev/dri:/dev/dri
    ports:
      - "8080:8080"
    networks:
      - ai_net

  litellm:
    image: ghcr.io/berriai/litellm-proxy:latest
    container_name: litellm
    restart: unless-stopped
    environment:
      - LITELLM_CONFIG=/config/config.yaml
    volumes:
      - /mnt/thinktank/research-stack/litellm-config:/config:ro,z
    ports:
      - "4000:4000"
    networks:
      - ai_net

  openwebui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: openwebui
    restart: unless-stopped
    environment:
      - OPENAI_API_BASE=http://litellm:4000/v1
      - OPENAI_API_KEY=dummy-key
    volumes:
      - /mnt/thinktank/openwebui-/app/backend/z
    ports:
      - "3000:8080"
    depends_on:
      - litellm
    networks:
      - ai_net

networks:
  ai_net:
    driver: bridge
EOF

mkdir -p research-stack/litellm-config
cat > research-stack/litellm-config/config.yaml << 'EOF'
model_list:
  - model_name: qwen2.5-coder-gpu
    litellm_params:
      model: openai/gpt-4.1-mini
      api_base: http://localai-vulkan:8080/v1
      api_key: dummy
      api_type: openai_compatible

  - model_name: qwen2.5-coder-cpu
    litellm_params:
      model: openai/gpt-4.1-mini-cpu
      api_base: http://localai-cpu:8081/v1
      api_key: dummy
      api_type: openai_compatible

litellm_settings:
  host: 0.0.0.0
  port: 4000
EOF

cat > research-stack/podman-compose.research.yml << 'EOF'
version: "3.9"

services:
  postgres-research:
    image: postgres:16
    container_name: postgres-research
    restart: unless-stopped
    environment:
      POSTGRES_DB: research
      POSTGRES_USER: researcher
      POSTGRES_PASSWORD: ${POSTGRESPASSWORD}
    volumes:
      - /mnt/thinktank/research-stack/db-postgres-r:/var/lib/postgresql/z
    networks:
      - research_net
    healthcheck:
      test:
        - CMD-SHELL
        - pg_isready -U researcher
      interval: 10s
      timeout: 5s
      retries: 5

  postgres-python:
    image: postgres:16
    container_name: postgres-python
    restart: unless-stopped
    environment:
      POSTGRES_DB: python
      POSTGRES_USER: pyuser
      POSTGRES_PASSWORD: ${PYTHONPOSTGRESPASSWORD}
    volumes:
      - /mnt/thinktank/research-stack/db-postgres-py:/var/lib/postgresql/z
    networks:
      - research_net
    healthcheck:
      test:
        - CMD-SHELL
        - pg_isready -U pyuser
      interval: 10s
      timeout: 5s
      retries: 5

  rstudio:
    image: rocker/tidyverse:latest
    container_name: rstudio
    restart: unless-stopped
    environment:
      - PASSWORD=${RSTUDIOPASSWORD}
      - ROOT=true
      - ADD=shiny
      - POSTGRESHOST=postgres-research
      - POSTGRESDB=research
      - POSTGRESUSER=researcher
      - POSTGRESPASSWORD=${POSTGRESPASSWORD}
      - LITELLMAPIBASE=http://litellm:4000
      - LITELLMAPIKEY=${LITELLMMASTERKEY}
      - USERID=1000
      - GROUPID=1000
    ports:
      - "8787:8787"
    volumes:
      - /mnt/thinktank/research-stack/rstudio-home:/mnt/rstudio:z
      - /mnt/thinktank/research-stack/shared:/mnt/shared:z
      - /mnt/thinktank/research-stack/notebooks:/mnt/notebooks:z
      - /mnt/thinktank/research-stack/research-files:/mnt/research-files:z
    networks:
      - research_net
    depends_on:
      postgres-research:
        condition: service_healthy

  jupyterlab:
    image: jupyter/datascience-notebook:latest
    container_name: jupyterlab
    restart: unless-stopped
    environment:
      JUPYTER_TOKEN: ${JUPYTERTOKEN}
      POSTGRESHOST: postgres-python
      POSTGRESDB: python
      POSTGRESUSER: pyuser
      POSTGRESPASSWORD: ${PYTHONPOSTGRESPASSWORD}
      LITELLMAPIBASE: http://litellm:4000
      LITELLMAPIKEY: ${LITELLMMASTERKEY}
    ports:
      - "8888:8888"
    user: root
    volumes:
      - /mnt/thinktank/research-stack/jupyter-home:/home/jovyan:z
      - /mnt/thinktank/research-stack/shared:/mnt/shared:z
      - /mnt/thinktank/research-stack/notebooks:/mnt/notebooks:z
      - /mnt/thinktank/research-stack/research-files:/mnt/research-files:z
    networks:
      - research_net
    depends_on:
      postgres-python:
        condition: service_healthy

  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: pgadmin
    restart: unless-stopped
    ports:
      - "5050:80"
    environment:
      PGADMIN_DEFAULT_EMAIL: ${PGADMINEMAIL}
      PGADMIN_DEFAULT_PASSWORD: ${PGADMINPASSWORD}
    volumes:
      - /mnt/thinktank/research-stack/pgadmin:/var/lib/pgadmin:z
    networks:
      - research_net

  paperqa:
    image: python:3.12-slim
    container_name: paperqa2
    restart: unless-stopped
    working_dir: /app
    command: >
      sh -c "
      pip install --no-cache-dir 'paper-qa[all]' &&
      python -m paperqa.server
      "
    environment:
      - PQA_LLM_API_BASE=http://litellm:4000/v1
      - PQA_LLM_API_KEY=${LITELLMMASTERKEY}
      - PQA_VECTOR_DIR=/vector-store
      - PQA_PDF_DIR=/zotero-pdfs
    volumes:
      - /mnt/thinktank/research-stack/zotero-pdfs:/zotero-pdfs:ro,z
      - /mnt/thinktank/research-stack/vector-store:/vector-store:z
    ports:
      - "4100:4100"
    networks:
      - research_net
      - ai_net

networks:
  research_net:
    driver: bridge

  ai_net:
    external: true
EOF

mkdir -p comfyui
cat > comfyui/setup-comfyui.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

COMFY_USER="${SUDO_USER:-$USER}"
COMFY_ROOT="/home/${COMFY_USER}/opt/comfyui"
COMFY_VENV="${COMFY_ROOT}/venv"

CHECKPOINT_DIR="/mnt/thinktank/comfyui/checkpoints"
LORA_DIR="/mnt/thinktank/comfyui/loras"
VAE_DIR="/mnt/thinktank/comfyui/vae"

echo "[*] Installing base dependencies (Fedora/Bazzite)..."
if command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y git python3 python3-venv python3-pip \
      mesa-vulkan-drivers vulkan-tools \
      rocm-smi rocminfo
fi

echo "[*] Creating model directories on /mnt/thinktank..."
sudo -u "$COMFY_USER" mkdir -p "$CHECKPOINT_DIR" "$LORA_DIR" "$VAE_DIR"

echo "[*] Cloning or updating ComfyUI in ${COMFY_ROOT}..."
if [ ! -d "$COMFY_ROOT" ]; then
  sudo -u "$COMFY_USER" mkdir -p "$(dirname "$COMFY_ROOT")"
  sudo -u "$COMFY_USER" git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY_ROOT"
else
  sudo -u "$COMFY_USER" git -C "$COMFY_ROOT" pull --ff-only
fi

echo "[*] Creating Python venv (if needed)..."
if [ ! -d "$COMFY_VENV" ]; then
  sudo -u "$COMFY_USER" python3 -m venv "$COMFY_VENV"
fi

echo "[*] Installing PyTorch ROCm wheels + ComfyUI requirements..."
sudo -u "$COMFY_USER" bash -lc "
  source \"$COMFY_VENV/bin/activate\"
  pip install --upgrade pip
  pip install --index-url https://download.pytorch.org/whl/rocm6.1 \
      torch torchvision
  pip install -r \"$COMFY_ROOT/requirements.txt\"
"

echo "[*] Linking model directories into ComfyUI tree..."
sudo -u "$COMFY_USER" mkdir -p \
  \"$COMFY_ROOT/models/checkpoints\" \
  \"$COMFY_ROOT/models/loras\" \
  \"$COMFY_ROOT/models/vae\"

for d in checkpoints loras vae; do
  TARGET=\"$COMFY_ROOT/models/$d\"
  SRC=\"/mnt/thinktank/comfyui/$d\"
  if [ -d \"\$TARGET\" ] && [ ! -L \"\$TARGET\" ]; then
    sudo -u \"$COMFY_USER\" rm -rf \"\$TARGET\"
  fi
  if [ ! -L \"\$TARGET\" ]; then
    sudo -u \"$COMFY_USER\" ln -s \"\$SRC\" \"\$TARGET\"
  fi
done

echo
echo "[*] Done. ComfyUI is at $COMFY_ROOT, venv at $COMFY_VENV."
EOF

cat > comfyui/comfyui.service << 'EOF'
[Unit]
Description=ComfyUI (PyTorch ROCm wheels) Service
After=network.target

[Service]
Type=simple
User=YOUR_BAZZITE_USER
WorkingDirectory=/home/YOUR_BAZZITE_USER/opt/comfyui
Environment="PYTHONUNBUFFERED=1"
ExecStart=/home/YOUR_BAZZITE_USER/opt/comfyui/venv/bin/python main.py --listen 0.0.0.0 --port 8188
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

chmod +x install.sh
chmod +x comfyui/setup-comfyui.sh
