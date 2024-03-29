#!/usr/bin/env bash

: '
The install.sh script completes the following steps

1. Creates the directory ~/.ica-ica-lazy
2. Adds functions to ~/.ica-ica-lazy/functions
2a. Adds internal-functions to ~/.ica-ica-lazy/internal-functions
2b. Adds templates to ~/.ica-ica-lazy/templates
3. Adds scripts to ~/.ica-ica-lazy/scripts
4. Adds autocompletions to ~/.ica-ica-lazy/autocomplete/<SHELL>/
'

set -euo pipefail

#########
# GLOCALS
#########

main_dir="${HOME}/.ica-ica-lazy"
api_key_path="${ICA_ICA_LAZY_DEFAULT_API_KEY_PATH-/ica/api-keys/default-api-key}"

help_message="Usage: install.sh
Installs ica-ica-lazy software and scripts into users home directory'.
You should have the following applications installed before continuing:

* aws
* curl
* docker | podman
* jq
* python3
* rsync
* pass (optional but recommended)

MacOS users, please install greadlink through 'brew install coreutils'
"

echo_stderr() {
  echo "$@" 1>&2
}

print_help() {
  echo_stderr "${help_message}"
}

get_docker_binary(){
  if type docker 1>/dev/null 2>&1; then
    echo "docker"
  else
    echo "podman"
  fi
}


check_readlink_program() {
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    readlink_program="greadlink"
  else
    readlink_program="readlink"
  fi

  if ! type "${readlink_program}" 1>/dev/null; then
      if [[ "${readlink_program}" == "greadlink" ]]; then
        echo_stderr "On a mac but 'greadlink' not found"
        echo_stderr "Please run 'brew install coreutils' and then re-run this script"
        return 1
      else
        echo_stderr "readlink not installed. Please install before continuing"
      fi
  fi
}


binaries_check(){
  : '
  Check each of the required binaries are available
  '
  if ! (type aws curl jq python3 rsync 1>/dev/null); then
    return 1
  fi

  if ! (type "$(get_docker_binary)" 1>/dev/null 2>&1); then
    echo_stderr "Warning: docker/podman is not installed. Required by ica-illumination, and for default gds-view output"
  fi
}

get_this_path() {
  : '
  Mac users use greadlink over readlink
  Return the directory of where this install.sh file is located
  '
  local this_dir

  # darwin is for mac, else linux
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    readlink_program="greadlink"
  else
    readlink_program="readlink"
  fi

  # Get directory name of the install.sh file
  this_dir="$(dirname "$("${readlink_program}" -f "${0}")")"

  # Return directory name
  echo "${this_dir}"
}

get_user_shell(){
  : '
  Quick one-liner to get user shell
  '
  # Quick "one liner" to get 'bash' or 'zsh'
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    basename "$(finger "${USER}" | grep 'Shell:*' | cut -f3 -d ":")"
  else
    basename "$(awk -F: -v user="$USER" '$1 == user {print $NF}' /etc/passwd)"
  fi
}

#########
# CHECKS
#########
if ! check_readlink_program; then
  echo_stderr "ERROR: Failed installation at readlink check stage"
  print_help
  exit 1
fi

if ! binaries_check; then
  echo_stderr "ERROR: Failed installation at the binaries check stage. Please check the requirements highlighted in usage."
  print_help
  exit 1
fi

user_shell="$(get_user_shell)"

if [[ -z "${user_shell}" ]]; then
  echo_stderr "Couldn't get user shell, using '\$SHELL' env var '$SHELL'"
  user_shell="$(basename "${SHELL}")"
fi

# Check bash version
if [[ "${user_shell}" == "bash" ]]; then
  echo_stderr "Checking bash version"
  if [[ "$( "${SHELL}" -c "echo \"\${BASH_VERSION}\" 2>/dev/null" | cut -d'.' -f1)" -lt "4" ]]; then
    echo_stderr "Please upgrade to bash version 4 or higher, if you are running MacOS then please run the following commands"
    echo_stderr "brew install bash"
    echo_stderr "sudo bash -c \"echo \$(brew --prefix)/bin/bash >> /etc/shells\""
    echo_stderr "chsh -s \$(brew --prefix)/bin/bash"
    exit 1
  fi
fi

# Checking bash-completion is installed (for bash users only)
if [[ "${user_shell}" == "bash" ]]; then
  if ! ("${SHELL}" -lic "type _init_completion 1>/dev/null"); then
    echo_stderr "Could not find the command '_init_completion' which is necessary for auto-completion scripts"
    echo_stderr "If you are running on MacOS, please run the following command:"
    echo_stderr "brew install bash-completion@2 --HEAD"
    echo_stderr "Then add the following lines to ${HOME}/.bash_profile"
    echo_stderr "#######BASH COMPLETION######"
    echo_stderr "[[ -r \"\$(brew --prefix)/etc/profile.d/bash_completion.sh\" ]] && . \"\$(brew --prefix)/etc/profile.d/bash_completion.sh\""
    echo_stderr "############################"
    echo_stderr "If you are running on Linux:"
    echo_stderr "Please clone the following git repository \"https://github.com/scop/bash-completion\""
    echo_stderr "And following the installation commands. If you do not have sudo permissions"
    echo_stderr "Please set the --prefix option for the ./configure command to a local path"
    exit 1
  fi
fi

# Check bash version for macos users (even if they're not using bash as their shell)
if [[ "${OSTYPE}" == "darwin"* ]]; then
    echo_stderr "Checking env bash version"
    if [[ "$(bash -c "echo \${BASH_VERSION}" | cut -d'.' -f1)" -le "4" ]]; then
      echo_stderr "ERROR: Please install bash version 4 or higher (even if you're running zsh as your default shell)"
      echo_stderr "ERROR: Please run 'brew install bash'"
      exit 1
  fi
fi

#############
# CREATE DIRS
#############
mkdir -p "${main_dir}"


####################
# API KEY INVOCATION
####################

# Check pass or call errors
if ! (type pass); then
  echo_stderr "Warning: pass is not installed. You will need to need to update the code at \"${main_dir}/get_api_key.sh\""
else
  # Check pass db
  echo_stderr "pass binary found"
  echo_stderr "Checking pass db has a value at ${api_key_path}"
  echo_stderr "You may be prompted for your gpg password in a few seconds"
  sleep 4

  # Get API Key path
  if ! pass "${api_key_path}" 1>/dev/null; then
    echo_stderr "Could not confirm an api key at ${api_key_path} in your pass db"
    echo_stderr "You may need to update the code at \"${main_dir}/get_api_key.sh\""
  fi
fi

# Get API key
if [[ -r "${main_dir}/get_api_key.sh" ]]; then
  # Dont overwrite api key sh
  echo_stderr "File \"${main_dir}/get_api_key.sh\" already exists so not overwriting. Please modify if required"
else
  # Created single line api-key shell script
  {
    echo "#!/usr/bin/env bash"
    echo "# This file was autogenerated by ica-ica-lazy"
    echo "# This file is called by ica-ica-lazy commands when a users API key is required"
    echo "# Without arguments this file should provide an API key to stdout on return"
    echo "pass \"${api_key_path}\""
  } >> "${main_dir}/get_api_key.sh"
fi

# Ensure file is executable
chmod +x "${main_dir}/get_api_key.sh"

# Ensure file is not readable by others
chmod 700 "${main_dir}/"
chmod 700 "${main_dir}/get_api_key.sh"


##############
# COPY SCRIPTS
##############
rsync --delete --archive \
  "$(get_this_path)/scripts/" "${main_dir}/scripts/"

chmod +x "${main_dir}/scripts/"*


################
# COPY FUNCTIONS
################
rsync --delete --archive \
  "$(get_this_path)/functions/" "${main_dir}/functions/"


######################
# COPY AUTOCOMPLETIONS
######################
rsync --delete --archive \
  "$(get_this_path)/autocompletion/" "${main_dir}/autocompletion/"


#########################
# COPY INTERNAL FUNCTIONS
#########################
rsync --delete --archive \
  "$(get_this_path)/internal-functions/" "${main_dir}/internal-functions/"


################
# COPY TEMPLATES
################
rsync --delete --archive \
  "$(get_this_path)/templates/" "${main_dir}/templates/"

################
# COPY VERSION
################
if [[ -r "$(get_this_path)/version.txt" ]]; then
  cp "$(get_this_path)/version.txt" "${main_dir}/version.txt"
else
  echo_stderr "Could not find version.txt inside release file, may be installed from src"
  echo "latest" > "${main_dir}/version.txt"
fi

#################
# PRINT USER HELP
#################
if [[ "${user_shell}" == "bash" ]]; then
  rc_profile="${HOME}/.bashrc"
elif [[ "${user_shell}" == "zsh" ]]; then
  rc_profile="${HOME}/.zshrc"
else
  rc_profile="${HOME}/.${user_shell}rc"
fi

echo_stderr "INSTALLATION COMPLETE!"
echo_stderr "To start using the lazy scripts, add the following lines to ${rc_profile}"
echo_stderr "######ICA-ICA-LAZY######"
echo_stderr "export ICA_BASE_URL=\"https://aps2.platform.illumina.com\""
echo_stderr "export ICA_ICA_LAZY_HOME=\"${main_dir}\""
echo_stderr "# Add scripts to PATH var"
echo_stderr "export PATH=\"\$PATH:\$ICA_ICA_LAZY_HOME/scripts\""
echo_stderr "# Source functions"
echo_stderr "source \"\$ICA_ICA_LAZY_HOME/functions/\"*\".sh\""

# Autocompletion differs between shells
echo_stderr "# Source autocompletions"
if [[ "${user_shell}" == "bash" ]]; then
  echo_stderr "for f in \"\$ICA_ICA_LAZY_HOME/autocompletion/${user_shell}/\"*\".bash\"; do"
  echo_stderr "    . \"\$f\""
  echo_stderr "done"
elif [[ "${user_shell}" == "zsh" ]]; then
  echo_stderr "fpath=(\"\$ICA_ICA_LAZY_HOME/autocompletion/${user_shell}/\" \$fpath)"
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    # Mac Users need to run 'autoload' before running compinit
    echo_stderr "autoload -Uz compinit"
  fi
  echo_stderr "compinit"
fi

echo_stderr "########################"
