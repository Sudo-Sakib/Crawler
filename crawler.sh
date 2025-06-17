#!/bin/bash

# Color
GREEN="\e[0;32m"
RED="\e[0;31m"
NC="\e[0m"

# Tools required
REQUIRED_TOOLS=(gauplus katana cariddi)

# Check dependencies and install if missing
check_dependencies() {
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            echo -e "${RED}[!] $tool is not installed. Installing...${NC}"
            if ! go install github.com/projectdiscovery/$tool@latest 2>/dev/null; then
                echo -e "${RED}[-] Failed to install $tool. Please install it manually.${NC}"
                exit 1
            fi
            export PATH=$PATH:$(go env GOPATH)/bin
        else
            echo -e "${GREEN}[+] $tool is installed.${NC}"
        fi
    done
}

# Save resume marker
save_marker() {
    echo "$1" >> "$output_dir"/.resume_marker
}

# Load resume markers
load_marker() {
    grep "$1" "$output_dir"/.resume_marker 2>/dev/null
}

# Run Gauplus
run_gauplus() {
    if ! load_marker "gauplus"; then
        echo -e "${GREEN}[+] Running Gauplus...${NC}"
        gauplus "$1" > "$output_dir/gauplus.txt"
        save_marker "gauplus"
    fi
}

# Run Katana
run_katana() {
    if ! load_marker "katana"; then
        echo -e "${GREEN}[+] Running Katana...${NC}"
        echo "https://$1" | katana -silent > "$output_dir/katana.txt"
        save_marker "katana"
    fi
}

# Run Cariddi
run_cariddi() {
    local input=$1
    local outfile=$2
    local flag=$3

    if ! load_marker "$flag"; then
        echo -e "${GREEN}[+] Running Cariddi ($flag)...${NC}"
        cat "$input" | cariddi | grep http > "$outfile"
        save_marker "$flag"
    fi
}

# Merge all outputs
merge_outputs() {
    cat "$output_dir"/*.txt | sort -u > "$output_dir/merged_urls.txt"
    echo -e "${GREEN}[+] Merged output saved to $output_dir/merged_urls.txt${NC}"
}

# Trap Ctrl+C to allow resume
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

# Validate
if [ -z "$output_dir" ]; then
    echo -e "${RED}[!] Output folder (-o) is required.${NC}"
    exit 1
fi
mkdir -p "$output_dir"

check_dependencies

# Start process
if [ -n "$domain" ]; then
    run_gauplus "$domain"
    run_katana "$domain"
elif [ -n "$list" ]; then
    while read -r dom; do
        run_gauplus "$dom"
        run_katana "$dom"
    done < "$list"
fi

if [ -n "$cariddi_url" ]; then
    echo "$cariddi_url" > "$output_dir/tmp_single_url.txt"
    run_cariddi "$output_dir/tmp_single_url.txt" "$output_dir/cariddi_url.txt" "cariddi_url"
elif [ -n "$cariddi_list" ]; then
    run_cariddi "$cariddi_list" "$output_dir/cariddi_list.txt" "cariddi_list"
fi

merge_outputs

echo -e "${GREEN}[*] Done. All output saved to $output_dir${NC}"
