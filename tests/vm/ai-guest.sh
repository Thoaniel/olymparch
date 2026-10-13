#!/bin/bash
# Run inside the test VM by tests/vm/ai (this repo is on /mnt over 9p). Results go to the kernel log as «<2>AI: …»,
# which the host reads on the serial console.
#   ai-guest.sh setup        as root: the shell, i18n, settings, agent files and the AI commands in place, as the ISO
#                            and the installer would; tmux (the agents' runner) from the mirrors
#   ai-guest.sh stubs        as the user: Olympus' stub (olympus bar) and two fake agents — one with its own background
#                            mode (like Claude Code) and one that runs in tmux — and a key for the tmux one
#   ai-guest.sh scenario S   as the user: the stub's scenario (idle, chat, approval, timeout, fallback, off), shell restarted
#   ai-guest.sh task KIND    as the user: start a task with the fake native or tmux agent; checks ps and the logs for
#                            the key while it runs
set -uo pipefail
src=/mnt
mark() { echo "<2>AI: $*" >/dev/kmsg; }
restart_shell() {
    for p in $(pgrep -u "$(id -u)" -x quickshell); do kill "$p"; done   # launch-shell starts it again
    sleep 4
}
case $1 in
setup)
    cp -r "$src/default/shell/." /usr/share/olymparch/shell/
    cp -r "$src/default/i18n" "$src/default/settings" "$src/default/agents" "$src/default/skills" "$src/default/hypr" /usr/share/olymparch/
    for b in olymparch-agent olymparch-keys olymparch-mcp olymparch-settings olymparch-sysinfo olymparch-doctor; do
        install -m755 "$src/system/bin/$b" /usr/bin/
    done
    command -v tmux >/dev/null || pacman -S --noconfirm --needed tmux >/dev/null 2>&1
    chmod 666 /dev/kmsg
    command -v tmux >/dev/null && mark SETUP-OK || mark SETUP-NO-TMUX
    ;;
stubs)
    mkdir -p ~/.local/bin ~/.config/olymparch/agents ~/dev/prosjekt
    install -m755 "$src/tests/vm/olympus-stub" ~/.local/bin/olympus
    # a native agent: `fakenative --bg …` records a session; `fakenative agents --json` lists it; stop marks it stopped
    cat >~/.local/bin/fakenative <<'SH'
#!/bin/sh
db=$HOME/.fakenative
case $1 in
    --bg) printf '[{"id":"bg1","cwd":"%s","kind":"background","state":"working","startedAt":%s}]' "$PWD" "$(date +%s)000" >"$db"; echo "started bg1" ;;
    agents) cat "$db" 2>/dev/null || echo '[]' ;;
    stop) sed -i 's/"state":"[a-z]*"/"state":"stopped"/' "$db" ;;
esac
SH
    # a tmux agent: prints, says whether it got its key (never the key), and waits a bit
    cat >~/.local/bin/fakerunner <<'SH'
#!/bin/sh
echo "Jobber med: $1"
echo "nøkkel i miljøet: ${FAKE_KEY:+ja}"
sleep 25
echo "Ferdig: la til en test"
SH
    chmod +x ~/.local/bin/fakenative ~/.local/bin/fakerunner
    printf '%s\n' 'id = "fakenative"' 'name = "Testagent (egen bakgrunn)"' 'binary = "fakenative"' '[permissions]' 'modes = ["default"]' 'default = "default"' \
        '[native]' 'new = ["fakenative", "--bg", "--permission-mode", "{mode}", "{prompt}"]' 'list = ["fakenative", "agents", "--json"]' \
        'status_map = { working = "working", blocked = "waiting", done = "done", failed = "error", stopped = "stopped" }' \
        'stop = ["fakenative", "stop", "{id}"]' >~/.config/olymparch/agents/fakenative.toml
    printf '%s\n' 'id = "fakerunner"' 'name = "Testagent (tmux)"' 'binary = "fakerunner"' '[permissions]' 'modes = ["ask"]' 'default = "ask"' \
        '[task]' 'command = ["fakerunner", "{prompt}"]' '[env]' 'FAKE_KEY = "fakekey"' >~/.config/olymparch/agents/fakerunner.toml
    printf 'sk-vmtest-%s\n' "$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')" | olymparch-keys set fakekey >/dev/null
    olymparch-keys get fakekey >~/.vmtest-key   # only so the check below knows what to look for
    echo idle >~/.olympus-stub-bar
    restart_shell
    mark STUBS-OK
    ;;
scenario)
    echo "$2" >~/.olympus-stub-bar
    restart_shell
    mark "SCENARIO-$2"
    ;;
task)
    case $2 in
        native) id=$(olymparch-agent new fakenative ~/dev/prosjekt "rydd i README") ;;
        runner) id=$(olymparch-agent new fakerunner ~/dev/prosjekt "lag en test") ;;
    esac
    echo "$id" >~/.vmtest-task-$2
    sleep 3
    key=$(cat ~/.vmtest-key)
    # the key: never in any process's argv, the task's log, agents.json, the shell's log or the journal
    if ps -eo args | grep -v grep | grep -qF "$key"; then mark "KEY-IN-PS-$2"; fi
    if grep -rqF "$key" "${XDG_STATE_HOME:-$HOME/.local/state}/olymparch" "$XDG_RUNTIME_DIR/olymparch/agents.json" 2>/dev/null ||
        journalctl --user -b --no-pager 2>/dev/null | grep -qF "$key"; then mark "KEY-IN-LOGS-$2"; fi
    [[ $id == fake* ]] && mark "TASK-$2-$id" || mark "TASK-$2-FAILED"
    ;;
watch)   # in the background: which panel is open, whether Zeus' card is up and what Zeus says, when it changes
    last=''
    mark WATCH-START
    q() { timeout 3 qs ipc -p /usr/share/olymparch/shell call "$@" 2>/dev/null; }
    while true; do
        now="PANEL=$(q panel current) CARD=$(q zeuscard shown) ZEUS=$(q zeus status | tr -d ' ')"
        [ "$now" != "$last" ] && mark "$now" && last=$now
        sleep 0.5
    done
    ;;
bar-log)   # what the shell sent Olympus' stub (approve, deny …)
    grep -oE '"cmd":"[a-z_]+"' ~/olympus-bar.log 2>/dev/null | sort | uniq -c | while read -r n c; do mark "SENT $c x$n"; done
    mark BAR-LOG-DONE
    ;;
status)
    for d in "${XDG_STATE_HOME:-$HOME/.local/state}"/olymparch/agents/fakerunner-*/; do
        [ -d "$d" ] || continue
        mark "RUNNER-EXIT $(cat "$d/exit" 2>/dev/null || echo none) tmux=$(tmux -V 2>/dev/null) script=$(tail -n 1 "$d/run.sh" 2>/dev/null | cut -c1-60)"
        tail -n 4 "$d/log" 2>/dev/null | while IFS= read -r l; do mark "RUNNER-LOG $l"; done
    done
    python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(" ".join(t["agent"]+"="+t["status"] for t in d["tasks"]))' \
        "$XDG_RUNTIME_DIR/olymparch/agents.json" | while read -r l; do mark "TASKS $l"; done
    ;;
esac
