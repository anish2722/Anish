#!/bin/bash

# ===== LICENSE =====
VALID_KEY="ANISH272-VIP-2026"
read -p "Enter License Key: " key
[[ "$key" != "$VALID_KEY" ]] && echo "❌ Invalid Key" && exit

clear
echo "🚀 ANISH272 ULTRA INSTALLER"
sleep 2

# ===== UPDATE =====
apt update -y && apt upgrade -y

# ===== INSTALL =====
apt install -y wget curl jq screen python3 nginx openssh-server dropbear openssl net-tools

# ===== SSH + DROPBEAR =====
sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=143/g' /etc/default/dropbear
systemctl restart dropbear

# ===== BADVPN =====
wget -O /usr/bin/badvpn-udpgw https://github.com/ambrop72/badvpn/releases/download/1.999.130/badvpn-udpgw
chmod +x /usr/bin/badvpn-udpgw
screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7300

# ===== WEBSOCKET =====
cat > /usr/local/bin/ws.py << 'EOF'
import socket, threading
RESPONSE = b"HTTP/1.1 101 ANISH272 VIP SERVER\r\n\r\n"

def handle(c):
    c.send(RESPONSE)
    t=socket.socket()
    t.connect(("127.0.0.1",22))

    def f(s,d):
        while True:
            data=s.recv(4096)
            if not data: break
            d.sendall(data)

    threading.Thread(target=f,args=(c,t)).start()
    threading.Thread(target=f,args=(t,c)).start()

s=socket.socket()
s.bind(('',80))
s.listen(100)

while True:
    c,a=s.accept()
    threading.Thread(target=handle,args=(c,)).start()
EOF

screen -dmS ws python3 /usr/local/bin/ws.py

# ===== SSL =====
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
-keyout /etc/nginx/ssl/key.pem \
-out /etc/nginx/ssl/cert.pem \
-subj "/CN=ANISH272"

cat > /etc/nginx/sites-enabled/default << 'EOF'
server {
 listen 443 ssl;
 ssl_certificate /etc/nginx/ssl/cert.pem;
 ssl_certificate_key /etc/nginx/ssl/key.pem;

 location / {
  proxy_pass http://127.0.0.1:80;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection "Upgrade";
 }
}
EOF

systemctl restart nginx

# ===== BANNER =====
cat > /etc/issue.net << 'EOF'
╔══════════════════════╗
   🚀 ANISH272 VIP 🚀
╚══════════════════════╝
⚡ FAST • STABLE • SECURE ⚡
💎 PREMIUM SERVER 💎
EOF

echo "Banner /etc/ssh/sshd_config" >> /etc/ssh/sshd_config
systemctl restart ssh

# ===== CLOUDFLARE SUBDOMAIN =====
cf_add_domain() {
read -p "Email: " email
read -p "API Key: " key
read -p "Domain: " domain
read -p "Subdomain: " sub

ip=$(curl -s ifconfig.me)

zone=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$domain" \
-H "X-Auth-Email: $email" \
-H "X-Auth-Key: $key" | jq -r '.result[0].id')

curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone/dns_records" \
-H "X-Auth-Email: $email" \
-H "X-Auth-Key: $key" \
-H "Content-Type: application/json" \
--data "{\"type\":\"A\",\"name\":\"$sub\",\"content\":\"$ip\",\"ttl\":120,\"proxied\":true}"

echo "✅ Created: $sub.$domain"
}

# ===== CONFIG GENERATOR =====
gen_config() {
read -p "Username: " user
read -p "Domain: " domain

cat > /root/$user.dark <<EOF
{
 "server": "$domain",
 "port": "443",
 "type": "ssh",
 "payload": "GET / HTTP/1.1\\r\\nHost: $domain\\r\\nUpgrade: websocket\\r\\nConnection: Upgrade"
}
EOF

echo "✅ Config: /root/$user.dark"
}

# ===== TELEGRAM BOT =====
cat > /usr/local/bin/bot.py << 'EOF'
import requests,time,os

TOKEN="PUT_TOKEN"
CHAT="PUT_CHATID"

def send(m):
 requests.get(f"https://api.telegram.org/bot{TOKEN}/sendMessage?chat_id={CHAT}&text={m}")

def updates(o):
 return requests.get(f"https://api.telegram.org/bot{TOKEN}/getUpdates?offset={o}").json()

u=0
while True:
 d=updates(u)
 for r in d["result"]:
  u=r["update_id"]+1
  t=r["message"]["text"]

  if t=="/start": send("🚀 ANISH272 BOT ONLINE")
  elif t=="/online": send(os.popen("who").read())
  elif t.startswith("/create"):
   try:
    _,a,b=t.split()
    os.system(f"useradd -m {a}")
    os.system(f"echo '{a}:{b}'|chpasswd")
    send("Created "+a)
   except: send("Error")
  elif t.startswith("/delete"):
   _,a=t.split()
   os.system(f"userdel -r {a}")
   send("Deleted "+a)

 time.sleep(3)
EOF

screen -dmS bot python3 /usr/local/bin/bot.py

# ===== MENU =====
cat > /usr/bin/menu << 'EOF'
#!/bin/bash
clear
echo "===== ANISH272 ULTRA PANEL ====="
echo "1 Create User"
echo "2 Delete User"
echo "3 Add Subdomain"
echo "4 Online Users"
echo "5 Generate Config"
echo "6 Exit"
read -p "Select: " x

case $x in
1) read -p "u: " u; read -p "p: " p; useradd -m $u; echo "$u:$p"|chpasswd;;
2) read -p "u: " u; userdel -r $u;;
3) bash -c "$(declare -f cf_add_domain); cf_add_domain";;
4) who;;
5) bash -c "$(declare -f gen_config); gen_config";;
*) exit;;
esac
EOF

chmod +x /usr/bin/menu

clear
echo "================================="
echo "🔥 ANISH272 ULTRA INSTALLED 🔥"
echo "IP: $(curl -s ifconfig.me)"
echo "WS: 80 | SSL: 443"
echo "Command: menu"
echo "================================="
