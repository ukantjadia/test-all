#!/bin/bash - 
set -o nounset                              # Treat unset variables as an error

# Check if existing nvim config is present, if yes, then createing bakup at ~/bak.nvim
#if [ -f ~/.config/nvim/init.vim ] || [ -f ~/.config/nvim/init.lua ]; then
#    mv ~/.config/nvim/ ~/bak.nvim
#    echo 'createing bakup of existing neovim config at ~/bak.nvim'
##    echo '[-] Existing nvim init config file found in ~/.config/nvim/. Please backup or remove it first before running this script.'
#fi
#
#sleep 1
#mkdir -p ~/.config/nvim
#
#sleep 1
echo '[*] Installing dependencies ...'
if [[ "$OSTYPE" = "darwin"* ]]; then
    brew install \
        wget \
        curl \
        git \
        gcc \
        ripgrep \
        python3
else
    declare -A osInfo;
    osInfo[/etc/redhat-release]=yum
    osInfo[/etc/arch-release]=pacman
    osInfo[/etc/gentoo-release]=emerge
    osInfo[/etc/SuSE-release]=zypp
    osInfo[/etc/debian_version]=apt
    osInfo[/etc/alpine-release]=apk

    for f in ${!osInfo[@]}
    do
        if [[ -f $f ]];then
#            sudo ${osInfo[$f]} update
            sudo ${osInfo[$f]} install \
            wget \
            curl \
            git \
            build-essential \
            ripgrep \
            python3 \
            python3-pip \
            python3-venv \
            -y
        fi
    done
fi

cd ~/.config/nvim
echo "[*] Installing neovim ..."
wget "https://github.com/neovim/neovim/releases/download/stable/nvim-linux64.tar.gz" 
mkdir -p ~/.local/bin
tar xf ~/.config/nvim/nvim-linux64.tar.gz -C ~/.local
read -p 'Want neovim for all user'
if 
ln -sf $(readlink -f ~/.local/nvim-linux64/bin/nvim) ~/.local/bin/nvim

# Adding path 
if ! [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
    echo "[*] Adding ~/.local/bin to PATH"
    if [ -n "`$SHELL -c 'echo $ZSH_VERSION'`" ]; then
        SHELL_CONFIG_FILE=~/.zshrc
    elif [ -n "`$SHELL -c 'echo $BASH_VERSION'`" ]; then
        SHELL_CONFIG_FILE=~/.profile
    else
        echo "[-] Could not detect what shell you are using. Ensure to manually add ~/.local/bin to your PATH"
    fi
    echo -e '\nPATH="$HOME/.local/bin:$PATH"' >> $SHELL_CONFIG_FILE
    export PATH="$HOME/.local/bin:$PATH"
fi

# Install nvm, node, npm, language servers
NVM_VERSION=0.39.1
NODE_VERSION=16.0.0
echo "[*] Installing nvm $NVM_VERSION ..."
curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/v$NVM_VERSION/install.sh" | bash # installs Node Version Manager to ~/.nvm, it also detects bash or zsh and appends source lines to ~/.bashrc or ~/.zshrc accordingly
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # to get the nvm command working without sourcing bash configs
echo "[*] Installing node $NODE_VERSION ..."
nvm install $NODE_VERSION # installs specific version of Node
echo "[*] Setting npm config to use ~/.local as prefix ..."
npm config set prefix '~/.local/' # npm install -g will now install to ~/.local/bin
echo "[*] Installing language servers ..."
npm i -g pyright # python language server
#npm i -g typescript typescript-language-server # uncomment to install typescript language server. remember to add "tsserver" to the "servers" list in init.vim within the lua section. See https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md for other language servers.

# Install vim-plug plugin manager
echo '[*] Installing vim-plug'
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

# Enter Neovim and install plugins with vim-plug's :PlugInstall using a temporary init.vim, which avoids warnings about missing colorschemes, functions, etc
## need to speify the location fo rthe init file
echo -e '[*] Running :PlugInstall within nvim ...'
loc=$(readlink -f .)
sed '/call plug#end/q' ./init.vim > ~/.config/nvim/init.vim
nvim -c 'PlugInstall' -c 'qa'

# Copy init.vim and lua scripts in current working directory to nvim's config location
echo '[*] Copying init.vim & lua/ -> ~/.config/nvim/'
cp -r ./init.vim ./lua/ ~/.config/nvim/

echo -e "[+] Done, welcome to your new \033[1m\033[92mneovim\033[0m experience! Try it by running: nvim. (NOTE, remember to: source $SHELL_CONFIG_FILE) Want to customize it? Modify ~/.config/nvim/init.vim! Remember to change your terminal font to a nerd font :)"

