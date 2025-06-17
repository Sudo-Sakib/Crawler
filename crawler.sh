#!/bin/bash

# Colors
GREEN="\e[0;32m"
RED="\e[0;31m"
NC="\e[0m"

# Required tools
REQUIRED_TOOLS=(gau gauplus katana cariddi uro)

# Check and install Go if missing
check_go() {
    if ! command -v go &>/dev/null; then
        echo -e "${RED}[!] Golang is not installed. Please install Go first from https://go.dev/dl/${NC}"
        exit 1
    fi
}

# Install dependencies
check_dependencies() {
    check_go
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            echo -e "${RED}[!] $tool is not installed.${NC}"
            echo -e "${GREEN}[+] Installing $tool...${NC}"
            case "$tool" in
                gau)
                    go install github.com/lc/gau@latest
                    ;;
                gauplus)
                    go install github.com/bp0lr/gauplus@latest
                    ;;
                katana)
                    go install github.com/projectdiscovery/katana/cmd/katana@latest
                    ;;
                cariddi)
                    go install github.com/edoardottt/cariddi/cmd/cariddi@latest
                    ;;
                uro)
                    pip3 install uro >/dev/null 2>&1 || { echo -e "${RED}[-] Failed to install uro. Please install manually.${NC}"; exit 1; }
                    continue
                    ;;
                *)
                    echo -e "${RED}[-] Unknown tool: $tool. Please install manually.${NC}"
                    exit 1
                    ;;
            esac
            BIN_PATH="$(go env GOPATH)/bin/$tool"
            if [ -f "$BIN_PATH" ]; then
                echo -e "${GREEN}[+] Moving $tool to /usr/local/bin...${NC}"
                sudo cp "$BIN_PATH" /usr/local/bin/
                sudo chmod +x /usr/local/bin/$tool
            fi
            if ! command -v "$tool" &>/dev/null; then
                echo -e "${RED}[-] Failed to install $tool. Please install manually.${NC}"
                exit 1
            else
                echo -e "${GREEN}[+] Successfully installed $tool.${NC}"
            fi
        else
            echo -e "${GREEN}[+] $tool is already installed.${NC}"
        fi
    done
}

# Save completed step
save_marker() {
    echo "$1" >> "$output_dir/.resume_marker"
}

# Check if step has been completed
load_marker() {
    grep -q "$1" "$output_dir/.resume_marker" 2>/dev/null
}

# GAU
run_gau() {
    if ! load_marker "gau-$1"; then
        echo -e "${GREEN}[+] Running GAU for $1...${NC}"
        gau "$1" > "$output_dir/gau_$1.txt" 2>/dev/null &
        save_marker "gau-$1"
    fi
}

# Gauplus
run_gauplus() {
    if ! load_marker "gauplus-$1"; then
        echo -e "${GREEN}[+] Running Gauplus for $1...${NC}"
        gauplus "$1" > "$output_dir/gauplus_$1.txt" 2>/dev/null &
        save_marker "gauplus-$1"
    fi
}

# Katana
run_katana() {
    if ! load_marker "katana-$1"; then
        echo -e "${GREEN}[+] Running Katana for $1...${NC}"
        echo "https://$1" | katana -silent > "$output_dir/katana_$1.txt" 2>/dev/null &
        save_marker "katana-$1"
    fi
}

# Cariddi
run_cariddi() {
    local input=$1
    local output=$2
    local flag=$3

    if ! load_marker "$flag"; then
        echo -e "${GREEN}[+] Running Cariddi ($flag)...${NC}"
        cat "$input" | cariddi | grep http > "$output"
        save_marker "$flag"
    fi
}

# Merge output files
merge_outputs() {
    echo -e "${GREEN}[+] Merging all output files...${NC}"
    find "$output_dir" -type f -name "*.txt" ! -name "merged_urls.txt" ! -name "unique_urls.txt" ! -name ".resume_marker" -exec cat {} + | sort -u > "$output_dir/merged_urls.txt"
    echo -e "${GREEN}[+] Merged output saved to $output_dir/merged_urls.txt${NC}"
}

# Run uro
run_uro() {
    echo -e "${GREEN}[+] Running uro on merged URLs...${NC}"
    uro "$output_dir/merged_urls.txt" > "$output_dir/unique_urls.txt"
    echo -e "${GREEN}[+] Cleaned URLs saved to $output_dir/unique_urls.txt${NC}"
}

# Trap CTRL+C
trap 'echo -e "\n${RED}[!] Interrupted. Resume later from saved state.${NC}"; exit 1' INT

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d) domain="$2"; shift ;;
        -l) list="$2"; shift ;;
        -u) cariddi_url="$2"; shift ;;
        -lu) cariddi_list="$2"; shift ;;
        -o) output_dir="$2"; shift ;;
        -h)
            echo -e "Usage:"
            echo "./$(basename "$0") -d <domain> -o <output_folder>"
            echo "./$(basename "$0") -l <domain_list> -o <output_folder>"
            echo "./$(basename "$0") -u <url> -o <output_folder>"
            echo "./$(basename "$0") -lu <url_list> -o <output_folder>"
            exit 0
            ;;
        *) echo -e "${RED}Unknown argument: $1${NC}"; exit 1 ;;
    esac
    shift
done

# Validate output folder
if [ -z "$output_dir" ]; then
    echo -e "${RED}[!] Output folder (-o) is required.${NC}"
    exit 1
fi

mkdir -p "$output_dir"

# Start
check_dependencies

if [ -n "$domain" ]; then
    run_gau "$domain"
    run_gauplus "$domain"
    run_katana "$domain"
    wait
elif [ -n "$list" ]; then
    while read -r dom; do
        [ -z "$dom" ] && continue
        run_gau "$dom"
        run_gauplus "$dom"
        run_katana "$dom"
    done < "$list"
    wait
fi

if [ -n "$cariddi_url" ]; then
    echo "$cariddi_url" > "$output_dir/tmp_url.txt"
    run_cariddi "$output_dir/tmp_url.txt" "$output_dir/cariddi_url.txt" "cariddi_url"
elif [ -n "$cariddi_list" ]; then
    run_cariddi "$cariddi_list" "$output_dir/cariddi_list.txt" "cariddi_list"
fi

merge_outputs
run_uro

echo -e "${GREEN}[*] Done. All output saved to: $output_dir${NC}"
