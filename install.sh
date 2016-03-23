#!/bin/bash

DOTFILES_DIRECTORY="${HOME}/git/dotfiles"
DOTFILES_TARBALL_PATH="https://github.com/canemacchina/dotfiles/tarball/master"
DOTFILES_GIT_REMOTE="git@github.com:canemacchina/dotfiles.git"
DOTFILES_BACKUP_FOLDER="${HOME}/dotfiles_backup/"
DOTFILES="aliases bash_profile bash_prompt bashrc exports functions gitconfig gitignore inputrc"

link() {
    # Force create/replace the symlink.
    ln -fs ${1} ${2}
}

backupFiles() {
    bckfld="${DOTFILES_BACKUP_FOLDER}/$(date +%s)"
    mkdir -p ${bckfld}
    for file in ${DOTFILES}; do
        mv "${HOME}/.${file}" ${bckfld}
    done
}

mirrorfiles() {
    for file in ${DOTFILES}; do
        link "${DOTFILES_DIRECTORY}/${file}" "${HOME}/.${file}"
    done
}

# If missing, download and extract the dotfiles repository
if [[ ! -d ${DOTFILES_DIRECTORY} ]]; then
    printf "$(tput setaf 7)Downloading dotfiles...\033[m\n"
    mkdir ${DOTFILES_DIRECTORY}
    # Get the tarball
    curl -fsSLo ${HOME}/dotfiles.tar.gz ${DOTFILES_TARBALL_PATH}
    # Extract to the dotfiles directory
    tar -zxf ${HOME}/dotfiles.tar.gz --strip-components 1 -C ${DOTFILES_DIRECTORY}
    # Remove the tarball
    rm -rf ${HOME}/dotfiles.tar.gz
fi

cd ${DOTFILES_DIRECTORY}

source ./lib/utils
source ./lib/brew
source ./lib/npm
source ./lib/osx
source ./lib/sublime

# Before relying on Homebrew, check that packages can be compiled
if ! type_exists 'gcc'; then
    e_header "You need xcode command line tool. Installing..."
    xcode-select --install
fi

# Check for Homebrew
if ! type_exists 'brew'; then
    e_header "Installing Homebrew..."
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    brew doctor
    brew tap homebrew/versions
    e_header "Installing Homebrew cask..."
    brew tap caskroom/cask
    brew tap caskroom/versions
    e_header "Installing webfonttools formulae..."
    brew tap bramstein/webfonttools
fi

# Check for git
if ! type_exists 'git'; then
    e_header "Installing Git..."
    brew install git
fi

# Initialize the git repository if it's missing
if ! is_git_repo; then
    e_header "Initializing git repository..."
    git init
    git remote add origin ${DOTFILES_GIT_REMOTE}
    git fetch origin master
    # Reset the index and working tree to the fetched HEAD
    # (submodules are cloned in the subsequent sync step)
    git reset --hard FETCH_HEAD
    # Remove any untracked files
    git clean -fd
fi

e_header "Syncing dotfiles..."
# Pull down the latest changes
git pull --rebase origin master
# Update submodules
git submodule update --recursive --init --quiet

# Install Homebrew formulae
e_header "Installing brew and brew cask packages..."
run_brew
e_success "done installing brew and brew cask packages..."
# Install Node packages
e_header "Installing Node.js packages..."
run_npm
e_success "Done installing Node.js packages..."
# Copy sublime text packages and configs
e_header "Updating Sublime Text preferences and packages..."
run_sublime
e_success "Done updating Sublime Text preferences and packages..."

e_header "Overwrite your existing dotfiles.\n(Don't panic, a backup folder will be created)"
backupFiles
e_success "Dotfiles backup complete!"
mirrorfiles
e_success "Dotfiles update complete!"
source ${HOME}/.bash_profile

# Ask before potentially overwriting OS X defaults
seek_confirmation "Warning: This step may modify your OS X system defaults."

if is_confirmed; then
    run_osx
    e_success "OS X settings updated! You may need to restart."
else
    printf "Skipped OS X settings update.\n"
fi

e_header "Installing Terminal material theme"
open ./extra/material-theme.terminal
e_success "Succesfully installed Terminal material theme"