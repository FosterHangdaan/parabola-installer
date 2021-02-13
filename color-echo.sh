# This file should be sourced. Do not run it directly!
if [[ $BASH_SOURCE == $0 ]]; then
  echo "$0 should be sourced. Do not run it directly!"
  exit 1
fi

colorEcho() {
  color=${1,,}  # Convert to lowercase
  prefix=''
  reset=`tput sgr0`

  case "$color" in
    'red')
      prefix=`tput setaf 1`
      ;;
    'green')
      prefix=`tput setaf 2`
      ;;
    'blue')
      prefix=`tput setaf 4`
      ;;
    'cyan')
      prefix=`tput setaf 6`
      ;;
    'yellow')
      prefix=`tput setaf 3`
      ;;
    'white')
      prefix=`tput setaf 7`
      ;;
    'black')
      prefix=`tput setaf 0`
      ;;
    *)
      echo "$2"
      return 1
      ;;
  esac

  echo "${prefix}${2}${reset}"
}
