# Day 2: Linux Fundamentals Refresh

## Core Concepts

### File System + Permissions
```bash
# Numeric: rwx = 4+2+1
chmod 755 file   # owner=rwx, group=rx, others=rx
chmod u+x file   # symbolic — add execute for user

# Special bits
# SUID (4xxx): run as file owner — e.g., /usr/bin/passwd
# SGID (2xxx): run as group / inherit group in dir
# Sticky (1xxx): only owner can delete — e.g., /tmp

# Key files
/etc/passwd    # user accounts (no passwords)
/etc/shadow    # hashed passwords
/etc/group     # group definitions
/var/log/      # system logs
/proc/         # kernel + process virtual filesystem
/sys/          # kernel hardware interface
```

### Process Management
```bash
ps aux | grep nginx          # find process
top / htop                   # live process view
kill -15 <pid>               # SIGTERM — graceful shutdown (app cleans up)
kill -9 <pid>                # SIGKILL — immediate, no cleanup

# K8s pod termination flow:
# SIGTERM → grace period (default 30s) → SIGKILL
# Set terminationGracePeriodSeconds in pod spec
```

### Networking Commands (DevOps Daily)
```bash
ss -tunlp                    # modern netstat — show all listening ports
lsof -i :8080                # what process is on port 8080
dig +trace google.com        # DNS resolution: root → TLD → authoritative
curl -v https://example.com  # verbose HTTP — shows TLS handshake + headers
tcpdump -i any port 443 -A   # packet capture on port 443
```

### systemd
```bash
systemctl start nginx
systemctl stop nginx
systemctl status nginx
systemctl enable nginx       # start on boot
systemctl restart nginx
systemctl reload nginx       # reload config without restart

journalctl -u kubelet -f     # follow kubelet logs (K8s node debug gold)
journalctl -u nginx --since "10 min ago"
```

### Shell Scripting
```bash
#!/bin/bash
set -euo pipefail
# -e: exit on error
# -u: error on undefined variable
# -o pipefail: pipe error = script error

# Function
my_func() {
  local var="$1"
  echo "$var"
}

# Array
items=("a" "b" "c")
for i in "${items[@]}"; do echo "$i"; done

# Trap for cleanup
trap 'echo "Cleaning up..."; rm -f /tmp/myfile' EXIT
```

---

## My 20-Command Cheatsheet

| Command | What it does |
|---------|-------------|
| `chmod 755 file` | rwx for owner, rx for group/others |
| `chown user:group file` | change ownership |
| `umask 022` | default permission mask (files=644, dirs=755) |
| `ps aux | grep proc` | find process by name |
| `kill -15 PID` | graceful shutdown (SIGTERM) |
| `kill -9 PID` | force kill (SIGKILL) |
| `ss -tunlp` | show listening ports + PIDs |
| `lsof -i :8080` | what's using port 8080 |
| `dig +trace domain.com` | full DNS resolution trace |
| `curl -v URL` | verbose HTTP with headers + TLS |
| `tcpdump -i any port 80` | capture packets |
| `journalctl -u svc -f` | follow service logs |
| `systemctl status svc` | service status |
| `df -h` | disk space |
| `du -sh /path` | directory size |
| `free -h` | memory usage |
| `top -bn1` | CPU + memory snapshot |
| `netstat -rn` | routing table |
| `strace -p PID` | trace system calls |
| `set -euo pipefail` | safe script header |

---

## End-of-Day Deliverable Checklist
- [ ] Run all Linux commands inside `kubectl exec -it` on a pod
- [ ] Write AWS S3 list script with error handling
- [ ] `journalctl -u kubelet --since '10 min ago'` on Minikube node
- [ ] OOM a pod intentionally, see SIGKILL in `kubectl describe`
