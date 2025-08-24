sudo apt install gpg
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt-get update
sudo apt-get install alloy

sudo systemctl start alloy

sudo systemctl status alloy

sudo systemctl enable alloy.service

sudo systemctl restart alloy

# /etc/alloy/config.alloy
# should edit config
sudo nano /etc/alloy/config.alloy


sudo systemctl reload alloy

sudo systemctl restart alloy
