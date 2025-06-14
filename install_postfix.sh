sudo apt update
sudo apt install postfix mailutils

# Click 1 internet site
# Fill in the email domain as server name
# Set an A record to the servers ip
# Set an MX record with value `mail` to the server ip 


sudo systemctl reload postfix
sudo systemctl enable postfix
