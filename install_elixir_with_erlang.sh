# Add Erlang & Elixir repo
sudo apt-get update
sudo apt-get install -y curl gnupg
curl -fsSL https://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc | sudo tee /etc/apt/trusted.gpg.d/erlang.gpg > /dev/null
echo "deb https://packages.erlang-solutions.com/ubuntu $(lsb_release -cs) contrib" | sudo tee /etc/apt/sources.list.d/erlang.list

# Install Elixir & Erlang
sudo apt-get update
sudo apt-get install -y elixir

# Confirm it’s installed
elixir -v
mix -v
