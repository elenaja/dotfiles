#!/bin/bash

DOTFILES_DIRECTORY="${HOME}/git/dotfiles"
DOTFILES_TARBALL_PATH="https://github.com/canemacchina/dotfiles/tarball/master"
DOTFILES_GIT_REMOTE="https://github.com/canemacchina/dotfiles.git"
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
    mkdir -p ${DOTFILES_DIRECTORY}
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
source ./lib/fonts

# Before relying on Homebrew, check that packages can be compiled
if xcode-select --install ; then
    e_header "You need xcode command line tool. Installing..."
    read -p "Press ENTER when installation is completed to continue " -n 1
fi

# Check for Homebrew
if ! type_exists 'brew'; then
    e_header "Installing Homebrew..."
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    brew doctor
    brew tap homebrew/versions
    brew tap homebrew/dupes
    e_header "Installing webfonttools formulae..."
    brew tap bramstein/webfonttools
fi

e_header "Installing Git..."
brew install git

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

e_header "Syncing dotfiles from Git..."
# Pull down the latest changes
git pull --rebase origin master
# Update submodules
git submodule update --recursive --init --quiet

printf "\n"
seek_confirmation "Installing brew and brew cask packages."
if is_confirmed; then
    # Install Homebrew formulae
    run_brew
    e_success "done installing brew and brew cask packages..."
else
    e_warning "Skipped installing brew and brew cask packages."
fi

printf "\n"
seek_confirmation "Installing Node.js packages."
if is_confirmed; then
    # Install Node packages
    run_npm
    e_success "Done installing Node.js packages..."
else
    e_warning "Skipped installing Node.js packages.."
fi

printf "\n"
seek_confirmation "Installing Roboto font."
if is_confirmed; then
    # Install fonts
    run_fonts
    e_success "Done installing Roboto font..."
else
    e_warning "Skipped installing Roboto font.."
fi

printf "\n"
seek_confirmation "Updating Sublime Text preferences and packages."
if is_confirmed; then
    # Copy sublime text packages and configs
    run_sublime
    e_success "Done updating Sublime Text preferences and packages..."
else
    e_warning "Skipped updating Sublime Text preferences and packages."
fi

printf "\n"
e_warning "Overwrite your existing dotfiles."
seek_confirmation "(Don't panic, a backup folder will be created)"
if is_confirmed; then
    backupFiles
    e_success "Dotfiles backup complete!"
    mirrorfiles
    e_success "Dotfiles update complete!"
else
    e_warning "Skipped overwrite existing dotfiles."
fi

source ${HOME}/.bash_profile

printf "\n"
e_warning "Update OS X Settings."
seek_confirmation "Warning: This step may modify your OS X system defaults."
if is_confirmed; then
    run_osx
    e_success "OS X settings updated! You may need to restart."
else
    e_warning "Skipped OS X settings update."
fi

printf "\n"
seek_confirmation "Wipe all dock icons"
if is_confirmed; then
    defaults write com.apple.dock persistent-apps -array
    e_success "Done Wiping all dock icons"
else
    e_warning "Skipped wipe all dock icons."
fi

printf "\n"
seek_confirmation "Installing Terminal material theme."
if is_confirmed; then
    open ./extra/material-theme.terminal
    e_success "Succesfully installed Terminal material theme"
    e_header "setting terminal preferences"

    pathToTerminalPrefs="${HOME}/Library/Preferences/com.apple.Terminal.plist"
    # Close if the shell exited cleanly
    /usr/libexec/PlistBuddy -c "Add :Window\ Settings:material-theme:shellExitAction integer 1" ${pathToTerminalPrefs}

    # Make the window a bit larger
    /usr/libexec/PlistBuddy -c "Add :Window\ Settings:material-theme:columnCount integer 120" ${pathToTerminalPrefs}
    /usr/libexec/PlistBuddy -c "Add :Window\ Settings:material-theme:rowCount integer 30" ${pathToTerminalPrefs}

    # Set the "material-theme" as the default
    defaults write com.apple.Terminal "Startup Window Settings" -string "material-theme"
    defaults write com.apple.Terminal "Default Window Settings" -string "material-theme"
else
    e_warning "Skipped installing Terminal material theme."
fi

printf "\n"
e_success "Done setting up your system. Enjoy!"
