e_header "Installing Node.js packages..."

# Install packages globally and quietly
npm install gulp npm-check bower --global --quiet

[[ $? ]] && e_success "Done"