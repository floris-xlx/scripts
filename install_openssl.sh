CORRECT SSL LIB

sudo apt-get update
sudo apt-get install libssl-dev
sudo apt install build-essential
sudo apt install plocate
sudo updatedb 

locate openssl.pc (RETURN FROM THIS SHOULD BE USED AS PATH IN NEXT)
export PKG_CONFIG_PATH=/usr/lib/pkgconfig