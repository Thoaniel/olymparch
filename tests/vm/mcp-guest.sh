#!/bin/bash
# Run inside the test VM by tests/vm/mcp (this repo is on /mnt over 9p). Results go to the kernel log as
# «<2>MCP…», which the host reads on the serial console.
#   mcp-guest.sh setup      as root: olymparch-mcp, olymparch-settings, the shell, schema, i18n, skills and the user
#                           units in place, as the ISO + installer would
#   mcp-guest.sh stubs      as the user: stand-ins for claude, hermes and openclaw in ~/.local/bin (they only write
#                           what they were asked to do), and a Hermes config of the user's own
#   mcp-guest.sh register   as the user: olymparch-mcp register, then show and check what it wrote
#   mcp-guest.sh http       as the user: the socket unit, then curl without/with the token
set -uo pipefail
src=/mnt
mark() { echo "<2>MCP: $*" >/dev/kmsg; }
case $1 in
setup)
    cp -r "$src/default/shell/." /usr/share/olymparch/shell/
    cp -r "$src/default/i18n" "$src/default/settings" "$src/default/skills" /usr/share/olymparch/
    install -m755 "$src/system/bin/olymparch-mcp" "$src/system/bin/olymparch-settings" "$src/system/bin/olymparch-doctor" /usr/bin/
    install -m644 "$src/default/systemd/user/olymparch-mcp.socket" "$src/default/systemd/user/olymparch-mcp.service" \
        "$src/default/systemd/user/olymparch-mcp-register.service" /usr/lib/systemd/user/
    chmod 666 /dev/kmsg
    mark SETUP-OK
    ;;
stubs)
    mkdir -p ~/.local/bin ~/.hermes
    cat >~/.local/bin/claude <<'EOF'
#!/bin/bash
echo "claude $*" >>~/agents.log
case "$1 $2" in
  "mcp get") [ -f ~/.claude-mcp-olymparch ] ;;
  "mcp add") printf '%s\n' "$*" >~/.claude-mcp-olymparch ;;
  "mcp remove") rm -f ~/.claude-mcp-olymparch ;;
esac
EOF
    cat >~/.local/bin/openclaw <<'EOF'
#!/bin/bash
echo "openclaw $*" >>~/agents.log
case "$1 $2" in
  "mcp show") [ -f ~/.openclaw-mcp-olymparch ] ;;
  "mcp set") printf '%s\n' "$4" >~/.openclaw-mcp-olymparch ;;
  "mcp unset") rm -f ~/.openclaw-mcp-olymparch ;;
esac
EOF
    printf '#!/bin/bash\necho "hermes $*" >>~/agents.log\n' >~/.local/bin/hermes
    chmod +x ~/.local/bin/claude ~/.local/bin/openclaw ~/.local/bin/hermes
    printf 'model:\n  default: local\nmcp_servers:\n  github:\n    command: npx\n' >~/.hermes/config.yaml
    mark STUBS-OK
    ;;
register)
    export PATH=$HOME/.local/bin:$PATH
    clear
    olymparch-mcp register
    echo "── ~/.hermes/config.yaml"; cat ~/.hermes/config.yaml
    echo "── claude: $(cat ~/.claude-mcp-olymparch)"
    echo "── openclaw: $(cat ~/.openclaw-mcp-olymparch)"
    echo "── ferdigheter:"; ls -l ~/.claude/skills ~/.hermes/skills ~/.openclaw/skills | grep -- '->' | awk '{print $9, $10, $11}' | head -8
    n1=$(grep -c 'mcp add' ~/agents.log)
    olymparch-mcp register >/dev/null
    n2=$(grep -c 'mcp add' ~/agents.log)
    if grep -q 'github:' ~/.hermes/config.yaml && grep -q '  olymparch:' ~/.hermes/config.yaml && [ "$n1" = 1 ] && [ "$n2" = 1 ] &&
        [ -L ~/.claude/skills/olymparch ] && [ -f ~/.openclaw/skills/olymparch-settings/SKILL.md ]; then mark REGISTER-OK; else mark REGISTER-NO; fi
    ;;
unregister)
    export PATH=$HOME/.local/bin:$PATH
    clear
    olymparch-mcp unregister
    echo "── ~/.hermes/config.yaml"; cat ~/.hermes/config.yaml
    if [ ! -e ~/.claude-mcp-olymparch ] && [ ! -e ~/.claude/skills/olymparch ] && ! grep -q olymparch ~/.hermes/config.yaml &&
        grep -q github ~/.hermes/config.yaml; then mark UNREGISTER-OK; else mark UNREGISTER-NO; fi
    ;;
http)
    clear
    systemctl --user daemon-reload
    systemctl --user start olymparch-mcp-register.service
    systemctl --user enable --now olymparch-mcp.socket
    sleep 1
    tok=$(cat "$XDG_RUNTIME_DIR/olymparch-mcp/token")
    init='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"curl"}}}'
    a=$(curl -s -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' -H 'Accept: application/json' -d "$init" http://127.0.0.1:47110/mcp)
    b=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $tok" -H 'Origin: http://evil.example' -H 'Content-Type: application/json' -H 'Accept: application/json' -d "$init" http://127.0.0.1:47110/mcp)
    c=$(curl -s -H "Authorization: Bearer $tok" -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' -d "$init" http://127.0.0.1:47110/mcp)
    echo "uten token: $a · fremmed Origin: $b"
    echo "med token: ${c:0:160}"
    echo "token-fil: $(stat -c '%a %U' "$XDG_RUNTIME_DIR/olymparch-mcp/token") · lytter: $(ss -Hltn 'sport = :47110' | awk '{print $4}')"
    if [ "$a" = 401 ] && [ "$b" = 403 ] && [[ $c == *'"protocolVersion": "2025-06-18"'* ]] && ! ss -Hltn 'sport = :47110' | grep -qv 127.0.0.1; then
        mark HTTP-OK; else mark HTTP-NO; fi
    ;;
esac
