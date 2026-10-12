# Olymparch: shell tools in interactive bash, each one only when it is installed (fzf, zoxide, starship).
# /etc/profile.d covers login shells; ~/.bashrc sources this file too, so every terminal gets them.
# shellcheck shell=bash
# ~/.local/bin first in PATH (Claude Code, Zeus/olympus and other per-user installs land there). Read by the tty1
# login that starts Hyprland too, so apps started from the menu see it as well.
case ":${PATH}:" in *":${HOME}/.local/bin:"*) ;; *) PATH=${HOME}/.local/bin:${PATH}; export PATH ;; esac
if [ -n "${BASH_VERSION:-}" ] && [[ $- == *i* ]] && [ -z "${_olymparch_shell_tools:-}" ]; then
    _olymparch_shell_tools=1
    # fzf: Ctrl+R history search, Ctrl+T files, Alt+C directories
    if command -v fzf >/dev/null 2>&1; then eval "$(fzf --bash 2>/dev/null)"; fi
    # zoxide: «z NAME» jumps to a directory you have been in
    if command -v zoxide >/dev/null 2>&1; then eval "$(zoxide init bash)"; fi
    # starship: the prompt
    if command -v starship >/dev/null 2>&1 && [ "${TERM:-dumb}" != dumb ]; then eval "$(starship init bash)"; fi
fi
