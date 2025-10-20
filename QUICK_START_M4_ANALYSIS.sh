#!/bin/bash
#
# Quick Start: M4 Hardware Analysis
# Script per raccogliere informazioni dal tuo Mac M4
#
# ATTENZIONE: Esegui questo script sul tuo Mac M4, non su altri sistemi
#

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}M4 Hardware Analysis - Quick Start${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Verifica che siamo su macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}ERRORE: Questo script deve essere eseguito su macOS${NC}"
    exit 1
fi

# Verifica che siamo su Apple Silicon
ARCH=$(uname -m)
if [[ "$ARCH" != "arm64" ]]; then
    echo -e "${RED}ERRORE: Questo script richiede Apple Silicon (arm64)${NC}"
    exit 1
fi

# Crea directory di ricerca
RESEARCH_DIR="$HOME/m4-research"
echo -e "${YELLOW}Creazione directory di ricerca in: $RESEARCH_DIR${NC}"
mkdir -p "$RESEARCH_DIR"/{device-tree,kernel-analysis,boot-analysis,firmware,comparisons}

cd "$RESEARCH_DIR"

echo ""
echo -e "${GREEN}[1/8] Raccolta informazioni hardware...${NC}"
system_profiler SPHardwareDataType > m4_hardware_info.txt
sysctl hw > m4_hw_sysctl.txt
echo "   Salvato: m4_hardware_info.txt, m4_hw_sysctl.txt"

echo ""
echo -e "${GREEN}[2/8] Estrazione Device Tree completo...${NC}"
ioreg -lw0 > device-tree/m4_full_ioreg.txt
echo "   Salvato: device-tree/m4_full_ioreg.txt"
echo "   Dimensione: $(wc -l < device-tree/m4_full_ioreg.txt) linee"

echo ""
echo -e "${GREEN}[3/8] Estrazione Platform Expert Device...${NC}"
ioreg -c IOPlatformExpertDevice -d 2 -l > device-tree/m4_platform.txt
ioreg -c IOPlatformExpertDevice -r -d 1 > device-tree/m4_platform_root.txt
echo "   Salvato: device-tree/m4_platform*.txt"

echo ""
echo -e "${GREEN}[4/8] Analisi boot configuration...${NC}"
nvram -p > boot-analysis/nvram_boot_args.txt 2>/dev/null || echo "   Nota: nvram richiede privilegi elevati"
nvram boot-args > boot-analysis/nvram_boot_args_only.txt 2>/dev/null || true
echo "   Salvato: boot-analysis/nvram_boot_args.txt"

echo ""
echo -e "${GREEN}[5/8] Raccolta informazioni kernel...${NC}"
uname -a > kernel-analysis/kernel_version.txt
sysctl -a > kernel-analysis/sysctl_all.txt 2>/dev/null
kextstat > kernel-analysis/loaded_kexts.txt
echo "   Salvato: kernel-analysis/{kernel_version,sysctl_all,loaded_kexts}.txt"

echo ""
echo -e "${GREEN}[6/8] Analisi security settings...${NC}"
csrutil status > boot-analysis/sip_status.txt 2>/dev/null || echo "SIP status: unknown" > boot-analysis/sip_status.txt
echo "   Salvato: boot-analysis/sip_status.txt"

echo ""
echo -e "${GREEN}[7/8] Ricerca componenti M4-specifici nel device tree...${NC}"
grep -i "m4" device-tree/m4_full_ioreg.txt > device-tree/m4_specific_references.txt || echo "No direct M4 references found" > device-tree/m4_specific_references.txt
grep -i "sptm\|secure.*page" device-tree/m4_full_ioreg.txt > device-tree/sptm_references.txt || echo "No SPTM references found" > device-tree/sptm_references.txt
echo "   Salvato: device-tree/{m4_specific_references,sptm_references}.txt"

echo ""
echo -e "${GREEN}[8/8] Generazione summary report...${NC}"

cat > ANALYSIS_SUMMARY.txt << EOF
===================================================
M4 Hardware Analysis Summary
Generated: $(date)
===================================================

SYSTEM INFORMATION:
$(system_profiler SPHardwareDataType | grep -E "Model Name|Model Identifier|Chip|Memory")

KERNEL:
$(uname -a)

SIP STATUS:
$(cat boot-analysis/sip_status.txt)

LOADED KEXTS COUNT:
$(wc -l < kernel-analysis/loaded_kexts.txt) kernel extensions loaded

DEVICE TREE SIZE:
$(wc -l < device-tree/m4_full_ioreg.txt) lines in IORegistry dump

FILES COLLECTED:
$(find . -type f | wc -l) files total

DIRECTORY STRUCTURE:
$(tree -L 2 . 2>/dev/null || find . -type d | sed 's|[^/]*/| |g')

===================================================
NEXT STEPS:
===================================================

1. Review device-tree/m4_full_ioreg.txt for hardware details
2. Check device-tree/sptm_references.txt for SPTM mentions
3. Compare with M1/M2 data if available
4. Join Asahi Linux IRC: #asahi on irc.oftc.net
5. Read M4_BOOTLOADER_RESEARCH.md for detailed analysis plan

===================================================
QUICK COMMANDS:
===================================================

# View platform info
cat device-tree/m4_platform.txt

# Search for specific hardware
grep -i "keyword" device-tree/m4_full_ioreg.txt

# List all loaded kexts
cat kernel-analysis/loaded_kexts.txt

# Check boot arguments
cat boot-analysis/nvram_boot_args.txt

===================================================
EOF

cat ANALYSIS_SUMMARY.txt

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Analisi completata!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Dati salvati in: $RESEARCH_DIR${NC}"
echo ""
echo -e "File principali:"
echo -e "  - ${GREEN}ANALYSIS_SUMMARY.txt${NC} - Questo summary"
echo -e "  - ${GREEN}device-tree/m4_full_ioreg.txt${NC} - Device tree completo"
echo -e "  - ${GREEN}kernel-analysis/sysctl_all.txt${NC} - Tutte le variabili kernel"
echo ""
echo -e "${YELLOW}Prossimi passi:${NC}"
echo -e "  1. Leggi M4_BOOTLOADER_RESEARCH.md per il piano completo"
echo -e "  2. Unisciti a #asahi su irc.oftc.net"
echo -e "  3. Confronta questi dati con M1/M2 se disponibili"
echo ""
echo -e "${YELLOW}Per analisi avanzata (richiede SIP disabilitato):${NC}"
echo -e "  - DTrace tracing"
echo -e "  - Kernel debugging"
echo -e "  - ATTENZIONE: Rischi di sicurezza!"
echo ""
