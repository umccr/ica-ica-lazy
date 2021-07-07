#!/usr/bin/env bash

: '
Wraps around autocompletion to run the appspec completion command from within the docker container
'

# Set to fail on non-zero exit code
set -euo pipefail

# Globals
AUTOCOMPLETION_DIR="autocompletion"
TEMPLATE_DIR="specs/"

(
  : '
  Run the rest in a subshell
  '

  # Change to autocompletion dir
  cd "${AUTOCOMPLETION_DIR}"

  # Create the bash and zsh dirs
  mkdir -p "bash"
  mkdir -p "zsh"

  # Run through bash completions
  for spec in "${TEMPLATE_DIR}"/*.yaml; do
     [[ -e "$spec" ]] || break  # handle the case of no *.yaml files
     name_root="$(basename "${spec%.yaml}")"

    # Run the bash completion script
    appspec completion \
      "${spec}" \
      --name "${name_root}" \
      --bash > "bash/${name_root}.bash"

     # Overwrite shebang
     sed -i '1c#!/usr/bin/env bash' "bash/${name_root}.bash"
  done

  # Run the zsh completions
  for spec in specs/*.yaml; do
    [[ -e "$spec" ]] || break  # handle the case of no *.yaml files
    name_root="$(basename "${spec%.yaml}")"
    appspec completion \
      "${spec}" \
      --name "${name_root}" \
      --zsh > "zsh/_${name_root}"
  done
)