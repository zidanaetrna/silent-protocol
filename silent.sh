#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    local level=$1
    local message=$2
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local border="-----------------------------------------------------"
    
    echo -e "${border}"
    case $level in
        "INFO") echo -e "${CYAN}[INFO] ${timestamp} - ${message}${NC}" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS] ${timestamp} - ${message}${NC}" ;;
        "ERROR") echo -e "${RED}[ERROR] ${timestamp} - ${message}${NC}" ;;
        *) echo -e "${YELLOW}[UNKNOWN] ${timestamp} - ${message}${NC}" ;;
    esac
    echo -e "${border}\n"
}

log "INFO" "1. Update sistem dan instal paket dasar"
sudo apt update -q && sudo apt upgrade -yq
sudo apt install -yq python3 python3-pip python3-venv screen curl wget

log "INFO" "2. Membuat Virtual Environment"
cd ~
python3 -m venv myenv
source myenv/bin/activate
log "SUCCESS" "Virtual Environment 'myenv' aktif"

log "INFO" "3. Meng-upgrade pip dan menginstal dependensi di virtual environment"
python3 -m pip install --upgrade pip
python3 -m pip install requests --quiet

log "INFO" "4. Menyiapkan folder kerja Silent-Protocol"
mkdir -p ~/Silent-Protocol && cd ~/Silent-Protocol
touch tokens.txt

log "INFO" "5. Membuat skrip Python automation.py"
cat > automation.py <<EOF
import requests
import time
import threading

position_url = "https://ceremony-backend.silentprotocol.org/ceremony/position"
ping_url = "https://ceremony-backend.silentprotocol.org/ceremony/ping"
token_file = "tokens.txt"

def load_tokens():
    try:
        with open(token_file, "r") as file:
            tokens = [line.strip() for line in file if line.strip()]
            print(f"{len(tokens)} tokens loaded.")
            return tokens
    except Exception as e:
        print(f"Error loading tokens: {e}")
        return []

def get_headers(token):
    return {
        "Authorization": f"Bearer {token}",
        "Accept": "*/*",
        "User-Agent": "Mozilla/5.0"
    }

def get_position(token):
    try:
        response = requests.get(position_url, headers=get_headers(token))
        if response.status_code == 200:
            data = response.json()
            print(f"[Token {token[:6]}...] Position: Behind {data['behind']}, Time Remaining: {data['timeRemaining']}")
            return data
        print(f"[Token {token[:6]}...] Failed to fetch position. Status: {response.status_code}")
    except Exception as e:
        print(f"[Token {token[:6]}...] Error fetching position: {e}")

def ping_server(token):
    try:
        response = requests.get(ping_url, headers=get_headers(token))
        if response.status_code == 200:
            data = response.json()
            print(f"[Token {token[:6]}...] Ping Status: {data}")
            return data
        print(f"[Token {token[:6]}...] Failed to ping. Status: {response.status_code}")
    except Exception as e:
        print(f"[Token {token[:6]}...] Error pinging: {e}")

def run_automation(token):
    while True:
        get_position(token)
        ping_server(token)
        time.sleep(10)

def main():
    tokens = load_tokens()
    if not tokens:
        print("No tokens available. Exiting.")
        return
    
    threads = []
    for token in tokens:
        thread = threading.Thread(target=run_automation, args=(token,))
        thread.start()
        threads.append(thread)
    
    for thread in threads:
        thread.join()

if __name__ == "__main__":
    main()
EOF

log "INFO" "6. Mengatur izin eksekusi pada automation.py"
chmod +x automation.py

log "INFO" "7. Menjalankan automation.py dalam screen"
log "INFO" "8. Buat Screen: screen -S Silent-Protocol"
log "INFO" "9. Tambahkan token: nano ~/Silent-Protocol/tokens.txt"
log "INFO" "10. Jalankan script: source ~/myenv/bin/activate && cd ~/Silent-Protocol && python3 automation.py"

log "SUCCESS" "Instalasi selesai! Masukkan token di tokens.txt lalu jalankan: screen -r Silent-Protocol"
