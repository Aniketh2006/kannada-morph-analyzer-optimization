#!/usr/bin/env bash
# Records the exact test environment next to the results.
# Run immediately BEFORE and AFTER a benchmark session:
#   bash scripts/env_snapshot_linux.sh before
#   bash scripts/env_snapshot_linux.sh after
out="environment_linux_${1:-snapshot}.txt"
{
  echo "timestamp        : $(date -Is)"
  echo "hostname         : $(hostname)"
  echo "os               : $(. /etc/os-release && echo "$PRETTY_NAME")"
  echo "kernel           : $(uname -r)"
  echo "cpu model        : $(lscpu | awk -F: '/Model name/ {gsub(/^ +/,"",$2); print $2; exit}')"
  echo "cpu threads      : $(nproc)   (sockets/cores: $(lscpu | awk -F: '/Socket\(s\)|Core\(s\) per socket/ {gsub(/ /,"",$2); printf "%s ", $2}'))"
  echo "cpu governor     : $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo n/a)"
  echo "cpu freq (MHz)   : $(awk '/cpu MHz/ {printf "%d ", $4}' /proc/cpuinfo)"
  echo "memory           : $(free -h | awk '/Mem:/ {print $2 " total, " $7 " available"}')"
  echo "storage          : $(lsblk -dno NAME,MODEL,SIZE -e7 | head -3 | tr '\n' ';')"
  echo "power source     : $(cat /sys/class/power_supply/A*/online 2>/dev/null | head -1 | sed 's/1/AC connected/;s/0/ON BATTERY/')"
  echo "load average     : $(cut -d' ' -f1-3 /proc/loadavg)"
  echo "perl             : $(perl -e 'print "$^V  ($^X)"')"
  echo "perl archname    : $(perl -MConfig -e 'print $Config{archname}, "  threads=", ($Config{useithreads}||"no")')"
  echo "MCE version      : $(perl -MMCE -e 'print $MCE::VERSION' 2>/dev/null || echo NOT INSTALLED)"
  echo "Storable version : $(perl -MStorable -e 'print $Storable::VERSION')"
  echo "dict_all.txt     : $(tr -d '\r' < dict_all.txt | sha256sum | cut -c1-16) (CR stripped)"
  echo "words file       : $(tr -d '\r' < random_words_100.txt | sha256sum | cut -c1-16) (CR stripped)"
} | tee "$out"
echo "saved: $out"
