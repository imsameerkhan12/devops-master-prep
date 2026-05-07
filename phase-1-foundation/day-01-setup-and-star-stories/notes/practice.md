# Day 1 Hands-on Practice Notes

> Platform used: https://labex.io/labs/linux-linux-ls-command-content-listing-219205

---

## 1. File Creation

```bash
touch sameer.txt       # creates empty file
ls -ll                 # view permissions
```

---

## 2. File Permissions

### Permission String Breakdown

```
-rw-rw-r--
│  │  │  │
│  │  │  └── Others
│  │  └───── Group
│  └──────── Owner
└─────────── File type (- = file, d = directory, l = symlink)
```

### Permission Letters

| Letter | Meaning |
|--------|---------|
| `r` | Read |
| `w` | Write |
| `x` | Execute |
| `-` | Permission missing |

### File Example: `-rw-rw-r--`

| Who | Permissions | Can do |
|-----|------------|--------|
| Owner | `rw-` | read ✅, write ✅, execute ❌ |
| Group | `rw-` | read ✅, write ✅, execute ❌ |
| Others | `r--` | read ✅, write ❌, execute ❌ |

### Directory Example: `drwxrwxr-x`

For directories, permission meaning changes:

| Permission | Meaning |
|------------|---------|
| `r` | List files inside |
| `w` | Create / delete files |
| `x` | Enter / access directory |

| Who | Permissions | Can do |
|-----|------------|--------|
| Owner | `rwx` | list, create/delete, enter ✅ |
| Group | `rwx` | same as owner ✅ |
| Others | `r-x` | list + enter ✅, cannot create/delete ❌ |

---

## 3. Numeric Permission Form

| Permission | Value |
|------------|-------|
| `r` | 4 |
| `w` | 2 |
| `x` | 1 |

```bash
chmod 755 sameer.txt
# Owner = 4+2+1 = 7 (rwx)
# Group = 4+0+1 = 5 (r-x)
# Others = 4+0+1 = 5 (r-x)
```

---

## 4. chmod and chown

```bash
chmod 755 sameer.txt          # change permissions
sudo adduser sameer
sudo chown sameer sameer.txt  # change owner
```

---

## 5. SUID and SGID

Special Linux permissions that allow programs to run with permissions of the owner/group instead of current user.

**SUID (Set User ID):** Program runs as the file owner, not the executing user.  
**SGID (Set Group ID):** Program/directory runs with file's group permissions.

---

## 6. Important System Directories

| Path | Purpose |
|------|---------|
| `/etc/passwd` | User account info |
| `/etc/shadow` | Encrypted passwords |
| `/etc/group` | Group info |
| `/var/log/` | System logs |
| `/proc/` | Process / kernel runtime info |
| `/sys/` | Hardware / kernel / device info |

---

## 7. Process Management

### ps aux

```bash
ps aux           # show all running processes
ps aux | grep nginx
```

| Part | Meaning |
|------|---------|
| `ps` | process status |
| `a` | all users' processes |
| `u` | user-oriented format |
| `x` | include background/no-terminal processes |

### Process States

| State | Meaning |
|-------|---------|
| `R` | Running |
| `S` | Sleeping |
| `Z` | Zombie |
| `T` | Stopped |

---

## 8. top

Live process + resource usage viewer — Linux's Task Manager.

```bash
top
```

### Reading top output

```
top - 15:20:01 up 2 days, 3 users, load average: 0.50, 0.40, 0.35
Tasks: 120 total
%Cpu(s): 10 us, 5 sy, 85 id
MiB Mem: 8000 total, 2000 free
```

**Load Average:** CPU load over 1 min / 5 min / 15 min

**CPU States:**

| Term | Meaning |
|------|---------|
| `us` | user processes |
| `sy` | system/kernel |
| `id` | idle CPU |

**Process Columns:**

| Column | Meaning |
|--------|---------|
| PID | Process ID |
| USER | Owner |
| %CPU | CPU usage |
| %MEM | Memory usage |
| COMMAND | Process name |

**Keyboard Shortcuts in top:**

| Key | Action |
|-----|--------|
| `q` | quit |
| `k` | kill process (enter PID) |
| `P` | sort by CPU |
| `M` | sort by memory |
| `1` | show all CPU cores |

---

## 9. htop

Better, colorful, modern version of top.

```bash
htop
# install if needed:
sudo apt install htop
```

| Feature | top | htop |
|---------|-----|------|
| Color UI | ❌ | ✅ |
| Mouse support | ❌ | ✅ |
| Easy scrolling | ❌ | ✅ |
| Better visualization | ❌ | ✅ |
| Process tree | Limited | Easy |

---

## 10. kill — Signals

```bash
kill SIGNAL PID
kill -15 1234    # SIGTERM — graceful
kill -9 1234     # SIGKILL — force
```

### Important Signals

| Signal | Name | Meaning |
|--------|------|---------|
| 15 | SIGTERM | Graceful stop |
| 9 | SIGKILL | Force kill immediately |
| 1 | SIGHUP | Reload config |
| 2 | SIGINT | Ctrl+C |

### SIGTERM vs SIGKILL

| Feature | SIGTERM (15) | SIGKILL (9) |
|---------|-------------|-------------|
| Graceful | ✅ | ❌ |
| Cleanup possible | ✅ | ❌ |
| App can handle signal | ✅ | ❌ |
| Immediate kill | ❌ | ✅ |
| Recommended first | ✅ | ❌ |

**Best practice:** Always try `kill -15` first. Use `kill -9` only if process refuses to stop.

**Why kill -9 can be dangerous:** No cleanup → corrupted files, broken DB transactions, locked resources.

### Kubernetes Pod Termination Flow

```
kubectl delete pod
      ↓
SIGTERM sent → container gets chance to shutdown
      ↓
wait terminationGracePeriodSeconds (default 30s)
      ↓
still alive? → SIGKILL
```

### Practice

```bash
sleep 500 &           # start background process
ps aux | grep sleep   # find PID
kill -15 PID          # graceful stop
kill -9 PID           # force stop (if needed)
kill -l               # list all signals
```

**Interview answer:**
> SIGTERM allows graceful shutdown and cleanup. SIGKILL immediately terminates the process without cleanup. Kubernetes first sends SIGTERM, waits the grace period, then sends SIGKILL if still running.

---

## 11. Networking Commands

### ss -tunlp

Modern replacement for `netstat`. Check listening ports + which process uses them.

```bash
ss -tunlp
```

| Option | Meaning |
|--------|---------|
| `-t` | TCP sockets |
| `-u` | UDP sockets |
| `-n` | numeric IP/ports |
| `-l` | listening sockets |
| `-p` | show process using port |

Common ports seen:

| Port | Service |
|------|---------|
| 22 | SSH |
| 80 | HTTP/NGINX |

### lsof -i :8080

Find which process is using a specific port.

```bash
lsof -i :8080
```

| Part | Meaning |
|------|---------|
| `lsof` | list open files |
| `-i` | network files/sockets |
| `:8080` | specific port |

### dig +trace

DNS debugging — shows full resolution path.

```bash
dig google.com           # simple lookup
dig +trace google.com    # full recursive chain
```

**DNS resolution flow:**
```
Root DNS → .com DNS → google.com authoritative DNS → final IP
```

**Useful for debugging:** Route53, Cloudflare, Kubernetes CoreDNS, Ingress DNS.

### curl -v

HTTP/API debugging with full detail.

```bash
curl -v https://google.com
curl -v http://localhost:8080/health
curl -vk https://site.com        # -k ignores invalid SSL cert
```

**Output symbols:**

| Symbol | Meaning |
|--------|---------|
| `>` | Request sent |
| `<` | Response received |

Shows: DNS lookup → TCP connection → TLS handshake → request headers → response headers.

### tcpdump -i any port 443

Packet capture tool.

```bash
tcpdump -i any port 443          # HTTPS traffic
tcpdump -i any port 80           # HTTP traffic
tcpdump host 8.8.8.8             # specific host
tcpdump -i any port 443 -w capture.pcap   # save to file (open in Wireshark)
```

| Part | Meaning |
|------|---------|
| `-i any` | capture all interfaces |
| `port 443` | HTTPS only |

### 5 Commands Summary

| Problem | Command |
|---------|---------|
| Is service listening? | `ss -tunlp` |
| Which process uses port? | `lsof -i :8080` |
| DNS problem? | `dig +trace` |
| HTTP/API issue? | `curl -v` |
| Deep packet issue? | `tcpdump` |

---

## 12. systemd

Service manager / init system in modern Linux.

Responsible for: starting services at boot, stopping/restarting, managing daemons, logging.

### systemctl Commands

| Command | Meaning |
|---------|---------|
| `systemctl start nginx` | Start service |
| `systemctl stop nginx` | Stop service |
| `systemctl restart nginx` | Restart service |
| `systemctl status nginx` | Check status |
| `systemctl enable nginx` | Start on boot |
| `systemctl disable nginx` | Don't start on boot |
| `systemctl --failed` | Show failed services |

### Status States

| State | Meaning |
|-------|---------|
| `active (running)` | Service healthy |
| `inactive` | Stopped |
| `failed` | Crashed/error |

### start vs enable

| Command | Meaning |
|---------|---------|
| `start` | Start now only |
| `enable` | Start automatically on boot |

### journalctl — Read Service Logs

```bash
journalctl -u nginx              # nginx logs
journalctl -u kubelet -f         # follow kubelet logs (K8s node debug gold)
journalctl -b                    # boot logs
journalctl -u myapp --since "10 min ago"
```

**K8s interview answer:**
> If a node is NotReady or pods aren't starting, first thing to check: `journalctl -u kubelet -f`

### Custom Service Unit File

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My Python App

[Service]
ExecStart=/usr/bin/python3 /app/app.py
Restart=always

[Install]
WantedBy=multi-user.target
```

After editing unit files:
```bash
sudo systemctl daemon-reload
sudo systemctl restart myapp
```

### Real DevOps Workflow

```
systemctl status myapp     → check if running
journalctl -u myapp -f     → check logs
systemctl restart myapp    → restart
```

---

## 13. set -euo pipefail

Essential safety header for every production shell script.

```bash
#!/bin/bash
set -euo pipefail
```

| Option | Meaning |
|--------|---------|
| `-e` | Exit script on any error |
| `-u` | Undefined variables = error |
| `pipefail` | Pipeline fails if ANY command in it fails |

### Why Each Matters

**`-e` (exit on error):**
```bash
# WITHOUT -e: script continues after failure (dangerous)
cd wrongfolder
echo "Deployment continues"   # still runs!

# WITH -e: script stops immediately at cd failure
```

**`-u` (undefined variable = error):**
```bash
# WITHOUT -u:
rm -rf /$DIR/*   # if $DIR is empty → rm -rf //* → disaster

# WITH -u: "NAME: unbound variable" error → caught before damage
```

**`pipefail`:**
```bash
# WITHOUT pipefail:
false | true   # exit status = 0 (success) — WRONG, false failed!

# WITH pipefail:
false | true   # exit status = 1 — correctly fails
```

### Real Production Example

```bash
#!/bin/bash
set -euo pipefail

kubectl apply -f deployment.yaml
docker push myimage
helm upgrade myapp ./chart

# If ANY command fails → script stops immediately
# Prevents broken half-deployments
```

### Interview Answer

> `set -euo pipefail` makes shell scripts safer by: exiting on command failures (`-e`), catching undefined variables before they cause damage (`-u`), and detecting failures inside pipelines (`pipefail`). Used in all production CI/CD scripts.
