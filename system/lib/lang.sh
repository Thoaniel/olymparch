# shellcheck shell=bash
# The one language rule for Olymparch's shell commands (sourced, never run):
#   Norwegian (nb) when ${OLYMPARCH_LANG:-$LANG} starts with nb, nn or no; English (en) otherwise.
# With no LANG at all (sudo, a pacman hook, a systemd unit) it reads LANG= from /etc/locale.conf.
# LC_ALL and LC_MESSAGES are not looked at: they say how to format, not which language a person reads.
# The shell (default/shell/I18n.qml), the Lua and the Python commands use the same rule.
#
#   . /usr/lib/olymparch/lang.sh
#   echo "$(L "Disk is full" "Disken er full")"
_olymparch_lang=${OLYMPARCH_LANG:-${LANG:-}}
if [ -z "$_olymparch_lang" ] && [ -r /etc/locale.conf ]; then
    _olymparch_lang=$(sed -n 's/^LANG=["'\'']\{0,1\}\([^"'\'']*\).*/\1/p' /etc/locale.conf 2>/dev/null | tail -n 1)
fi
case $_olymparch_lang in
    nb*|nn*|no*) OLYMPARCH_LANG=nb ;;
    *) OLYMPARCH_LANG=en ;;
esac
unset _olymparch_lang
export OLYMPARCH_LANG
# L ENGLISH NORWEGIAN: prints the one for the language, without a newline
L() { if [ "$OLYMPARCH_LANG" = nb ]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
