function spice --wraps='curl -fsSL https://raw.githubusercontent.com/spicetify/cli/main/install.sh | sh' --description 'alias spice=curl -fsSL https://raw.githubusercontent.com/spicetify/cli/main/install.sh | sh'
    curl -fsSL https://raw.githubusercontent.com/spicetify/cli/main/install.sh | sh $argv
end
