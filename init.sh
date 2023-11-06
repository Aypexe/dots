#!/bin/bash
#author:	michael talarico
#desc:		automated installation and configuration of commonly used CLI stack

get_pkg_mgr () {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if [ -n "$(command -v yum)" ]; then 
      echo "yum"
    fi
    if [ -n "$(command -v apt)" ]; then
      echo "apt"
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "brew"
  else
    echo "unknown OS"
    exit 1
  fi
}

check_error () {
  if [ $? == 0 ]; then
    echo "done"
  else
    echo "error: $?"
  fi
}

install_build_essentials () {
  echo -n "ensuring build-essential is installed... "
  case $PKGMGR in
      apt)
        sudo apt-get -qq update
        sudo apt-get -qq install -y build-essential gcc 
        ;;
      *)
        echo "skipping build essential install"
  esac
  check_error
}

install_rust () {
  echo -n "installing rust... "
  if ! [ -n "$(command -v cargo)" ]; then
    : $(curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y)
    source "$HOME/.cargo/env"
    check_error
  else 
    echo "skipping"
  fi
}

install_nu () {
  echo -n "installing nu... "
  if ! [ -n "$(command -v nu)" ]; then
    case $PKGMGR in
      yum)
        sudo yum install -y -q libxcb openssl-devel libX11-devel
        ;;
      apt)
        sudo apt-get -qq install -y pkg-config libssl-dev
        ;;
      brew)
        brew --quiet install openssl cmake
        ;;
      *)
        echo "unknown os"
        exit 1
        ;;
    esac
    cargo -q install nu
    check_error
  else 
    echo "skipping"
  fi
}

install_starship () {
  echo -n "installing starship... "
  if ! [ -n "$(command -v starship)" ]; then
    : $(curl -sS https://starship.rs/install.sh | sh -s -- -y)
    check_error
  else 
    echo "skipping"
  fi
}

install_zellij () {
  echo -n "installing zellij... "
  if ! [ -n "$(command -v zellij)" ]; then
    cargo -q install --locked zellij
    check_error
  else 
    echo "skipping"
  fi
}

install_utilities () {
  echo -n "installing utilities... "
  cargo -q install bat fd-find ripgrep hyperfine tokei tealdeer git-delta pastel gping
  check_error
}

install_helix () {
  echo -n "installing helix... "
  if ! [ -n "$(command -v hx)" ]; then
    rm -rf /tmp/helix
    git clone https://github.com/helix-editor/helix /tmp/helix --quiet
    (cd /tmp/helix && RUSTFLAGS="-C target-feature=-crt-static" cargo -q install --path helix-term --locked)
    check_error
  else 
    echo "skipping"
  fi
}

install_lvim () {
  echo -n "installing nvim... "
  if ! [ -n "$(command -v nvim)" ]; then
    cargo install --quiet bob-nvim
    1>/dev/null bob use stable
  fi
  if ! [ -n "$(command -v lvim)" ]; then
    : $(LV_BRANCH='release-1.3/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.3/neovim-0.9/utils/installer/install.sh -- -y))
    check_error
  else
    echo "skipping"
  fi
}

config_nu () {
  echo -n "configuring nu... "
  nupath=$(which nu)
  if [ $(getent passwd $(whoami) | awk -F: '{ print $7 }') != $nupath ]; then
    grep $nupath /etc/shells || echo $nupath | sudo tee -a /etc/shells > /dev/null
    chsh -s $nupath
  fi
  [ -f $HOME/.config/nushell/history.txt ] && cp $HOME/.config/nushell/history.txt /tmp/nushell_history.txt
  rm -rf $HOME/.config/nushell/
  cp -r $SCRIPTPATH/nushell/ $HOME/.config/nushell/
  [ -f /tmp/nushell_history.txt ] && cp /tmp/nushell_history.txt $HOME/.config/nushell/history.txt
  check_error
}

config_zellij () {
  echo -n "configuring zellij... "
  rm -rf $HOME/.config/zellij/
  cp -r $SCRIPTPATH/zellij/ $HOME/.config/zellij/
  check_error
}

# prereqs
mkdir -p $HOME/.config

PKGMGR=$(get_pkg_mgr)
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# elevate priviledges
while ! echo "$PW" | sudo -S -v > /dev/null 2>&1; do
    read -s -p "password: " PW
    echo
done


if [[ $1 == "help" || $1 == "--help" || $1 == "-h" ]]; then
  echo "init.sh [ config | install ]"
  echo "    config: configures and exits"
  echo "    install: installs and exits"
  echo ""
  echo "  no input will both configure and install"
  exit 0
fi

# installation
if ! [[ $1 == "config" || $1 == "c" || $1 == "--config" || $1 == "-c" ]]; then
  install_build_essentials
  install_rust
  install_nu
  install_starship
  install_zellij
  install_helix
  install_lvim
  install_utilities
fi

# configuration
if ! [[ $1 == "install" || $1 == "i" || $1 == "--install" || $1 == "-i" ]]; then
  config_nu
  config_zellij
fi
