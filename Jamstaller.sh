echo -e "
\e]P0282c34
\e]P1e06c75
\e]P298c379
\e]P3e5c07b
\e]P461afef
\e]P5c678dd
\e]P656b6c2
\e]P7abb2bf
\e]P85c6370
\e]P9e06c75
\e]PA98c379
\e]PBe5c07b
\e]PC61afef
\e]PDc678dd
\e]PE56b6c2
\e]PFffffff
" && clear


green="$(printf '\033[32m')"
gray="$(printf '\033[90m')"
reset="$(printf '\033[0m')"

./prompt_tui "Jamstaller" \
  "${green}[*]${reset} Install Location" \
  "${gray}[]${reset} System Setup" \
  "${gray}[]${reset} User Setup" \
  "${gray}[]${reset} Network Setup"
