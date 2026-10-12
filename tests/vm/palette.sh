#!/bin/bash
# For the theme pictures (tests/vm/themes): the terminal's 16 colours and some coloured output.
echo
for i in 0 1 2 3 4 5 6 7; do printf '\e[4%dm    \e[0m' "$i"; done; echo
for i in 0 1 2 3 4 5 6 7; do printf '\e[10%dm    \e[0m' "$i"; done; echo
echo
printf '\e[31mfeil \e[32mok \e[33madvarsel \e[34minfo \e[35mmagenta \e[36mcyan \e[1;37mfet\e[0m \e[2mdempet\e[0m\n'
ls --color=always -F /usr/share/olymparch | head -n 6
