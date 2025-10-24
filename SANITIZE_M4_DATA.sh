#!/bin/bash
#
# Sanitize M4 Hardware Data
# Rimuove informazioni sensibili prima del push su GitHub pubblico
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}M4 Data Sanitization Tool${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Verifica che la directory m4-research esista
if [ ! -d "m4-research" ]; then
    echo -e "${RED}ERRORE: Directory m4-research non trovata${NC}"
    echo "Esegui questo script dalla root del repository dopo aver copiato m4-research/"
    exit 1
fi

# Crea backup
echo -e "${YELLOW}[1/5] Creazione backup...${NC}"
BACKUP_DIR="m4-research-backup-$(date +%Y%m%d-%H%M%S)"
cp -r m4-research "$BACKUP_DIR"
echo "   Backup salvato in: $BACKUP_DIR"

# Crea directory sanitizzata
echo -e "${YELLOW}[2/5] Creazione directory sanitizzata...${NC}"
SANITIZED_DIR="m4-research-sanitized"
rm -rf "$SANITIZED_DIR"
mkdir -p "$SANITIZED_DIR"/{device-tree,kernel-analysis,boot-analysis,firmware,comparisons}

# Funzione per sanitizzare un file
sanitize_file() {
    local input="$1"
    local output="$2"

    if [ ! -f "$input" ]; then
        echo "   Skip: $input (non esiste)"
        return
    fi

    # Copia e sanitizza
    cat "$input" | \
        sed 's/IOPlatformSerialNumber" = <[^>]*>/IOPlatformSerialNumber" = <REDACTED>/g' | \
        sed 's/"serial-number" = <[^>]*>/"serial-number" = <REDACTED>/g' | \
        sed 's/"IOPlatformUUID" = "[^"]*"/"IOPlatformUUID" = "REDACTED"/g' | \
        sed 's/"UUID" = "[^"]*"/"UUID" = "REDACTED"/g' | \
        sed 's/"target-uuid" = <[^>]*>/"target-uuid" = <REDACTED>/g' | \
        sed 's/\b([0-9]{1,3}\.){3}[0-9]{1,3}\b/XXX.XXX.XXX.XXX/g' | \
        sed 's/\b([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}\b/XX:XX:XX:XX:XX:XX/g' | \
        sed 's/"local-mac-address" = <[^>]*>/"local-mac-address" = <REDACTED>/g' | \
        sed 's/"MAC-address" = <[^>]*>/"MAC-address" = <REDACTED>/g' | \
        sed "s/$(hostname)/HOSTNAME_REDACTED/g" > "$output"

    echo "   ✓ Sanitizzato: $(basename "$input")"
}

echo -e "${YELLOW}[3/5] Sanitizzazione file device-tree...${NC}"
sanitize_file "m4-research/device-tree/m4_full_ioreg.txt" "$SANITIZED_DIR/device-tree/m4_full_ioreg.txt"
sanitize_file "m4-research/device-tree/m4_platform.txt" "$SANITIZED_DIR/device-tree/m4_platform.txt"
sanitize_file "m4-research/device-tree/m4_platform_root.txt" "$SANITIZED_DIR/device-tree/m4_platform_root.txt"
sanitize_file "m4-research/device-tree/m4_specific_references.txt" "$SANITIZED_DIR/device-tree/m4_specific_references.txt"
sanitize_file "m4-research/device-tree/sptm_references.txt" "$SANITIZED_DIR/device-tree/sptm_references.txt"

echo -e "${YELLOW}[4/5] Sanitizzazione file kernel-analysis...${NC}"
sanitize_file "m4-research/kernel-analysis/kernel_version.txt" "$SANITIZED_DIR/kernel-analysis/kernel_version.txt"
sanitize_file "m4-research/kernel-analysis/sysctl_all.txt" "$SANITIZED_DIR/kernel-analysis/sysctl_all.txt"
sanitize_file "m4-research/kernel-analysis/loaded_kexts.txt" "$SANITIZED_DIR/kernel-analysis/loaded_kexts.txt"

echo -e "${YELLOW}[5/5] Sanitizzazione altri file...${NC}"
sanitize_file "m4-research/m4_hardware_info.txt" "$SANITIZED_DIR/m4_hardware_info.txt"
sanitize_file "m4-research/m4_hw_sysctl.txt" "$SANITIZED_DIR/m4_hw_sysctl.txt"
sanitize_file "m4-research/boot-analysis/nvram_boot_args.txt" "$SANITIZED_DIR/boot-analysis/nvram_boot_args.txt"
sanitize_file "m4-research/boot-analysis/nvram_boot_args_only.txt" "$SANITIZED_DIR/boot-analysis/nvram_boot_args_only.txt"
sanitize_file "m4-research/boot-analysis/sip_status.txt" "$SANITIZED_DIR/boot-analysis/sip_status.txt"

# Crea nuovo ANALYSIS_SUMMARY
echo -e "${YELLOW}Creazione nuovo ANALYSIS_SUMMARY...${NC}"
cat > "$SANITIZED_DIR/ANALYSIS_SUMMARY.txt" << EOF
===================================================
M4 Hardware Analysis Summary (SANITIZED)
Generated: $(date)
===================================================

⚠️  NOTA: Questo dataset è stato sanitizzato per rimuovere:
    - Serial numbers
    - UUID hardware
    - MAC addresses
    - Indirizzi IP
    - Hostname
    - Altre informazioni identificative

SYSTEM INFORMATION:
$(system_profiler SPHardwareDataType 2>/dev/null | grep -E "Model Name|Chip|Memory" | sed "s/$(hostname)/HOSTNAME_REDACTED/g" || echo "N/A")

KERNEL:
$(uname -s -r)

SIP STATUS:
$(cat "$SANITIZED_DIR/boot-analysis/sip_status.txt" 2>/dev/null || echo "Unknown")

LOADED KEXTS COUNT:
$(wc -l < "$SANITIZED_DIR/kernel-analysis/loaded_kexts.txt" 2>/dev/null || echo "0") kernel extensions loaded

DEVICE TREE SIZE:
$(wc -l < "$SANITIZED_DIR/device-tree/m4_full_ioreg.txt" 2>/dev/null || echo "0") lines in IORegistry dump

FILES SANITIZED:
$(find "$SANITIZED_DIR" -type f | wc -l) files total

===================================================
SANITIZATION LOG:
===================================================

Removed/Redacted:
- IOPlatformSerialNumber
- serial-number fields
- IOPlatformUUID
- target-uuid
- IP addresses (replaced with XXX.XXX.XXX.XXX)
- MAC addresses (replaced with XX:XX:XX:XX:XX:XX)
- local-mac-address
- Hostname (replaced with HOSTNAME_REDACTED)

Original backup: $BACKUP_DIR

===================================================
EOF

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Sanitizzazione completata!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Directory create:"
echo -e "  ${GREEN}$BACKUP_DIR${NC} - Backup originale (NON committare!)"
echo -e "  ${GREEN}$SANITIZED_DIR${NC} - Dati sanitizzati (safe per GitHub pubblico)"
echo ""
echo -e "${YELLOW}Prossimi passi:${NC}"
echo ""
echo -e "1. Verifica che la sanitizzazione sia OK:"
echo -e "   ${GREEN}grep -r 'IOPlatformSerialNumber' $SANITIZED_DIR/${NC}"
echo -e "   ${GREEN}grep -r 'UUID' $SANITIZED_DIR/${NC}"
echo ""
echo -e "2. Se OK, sostituisci la directory:"
echo -e "   ${GREEN}rm -rf m4-research${NC}"
echo -e "   ${GREEN}mv $SANITIZED_DIR m4-research${NC}"
echo ""
echo -e "3. Aggiungi al .gitignore il backup:"
echo -e "   ${GREEN}echo 'm4-research-backup-*' >> .gitignore${NC}"
echo ""
echo -e "4. Commit e push:"
echo -e "   ${GREEN}git add m4-research/ .gitignore${NC}"
echo -e "   ${GREEN}git commit -m 'Add sanitized M4 hardware analysis data'${NC}"
echo -e "   ${GREEN}git push${NC}"
echo ""
echo -e "${RED}⚠️  IMPORTANTE: NON committare la directory $BACKUP_DIR !${NC}"
echo ""
