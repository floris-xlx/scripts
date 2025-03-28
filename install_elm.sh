# Download the 0.19.1 binary for Linux.
#
# +-----------+----------------------+
# | FLAG      | MEANING              |
# +-----------+----------------------+
# | -L        | follow redirects     |
# | -o elm.gz | name the file elm.gz |
# +-----------+----------------------+
#
curl -L -o elm.gz https://github.com/elm/compiler/releases/download/0.19.1/binary-for-linux-64-bit.gz

# There should now be a file named `elm.gz` on your Desktop.
#
# The downloaded file is compressed to make it faster to download.
# This next command decompresses it, replacing `elm.gz` with `elm`.
#
gunzip elm.gz

# There should now be a file named `elm` on your Desktop!
#
# Every file has "permissions" about whether it can be read, written, or executed.
# So before we use this file, we need to mark this file as executable:
#
chmod +x elm

# The `elm` file is now executable. That means running `~/Desktop/elm --help`
# should work. Saying `./elm --help` works the same.
#
# But we want to be able to say `elm --help` without specifying the full file
# path every time. We can do this by moving the `elm` binary to one of the
# directories listed in your `PATH` environment variable:
#
sudo mv elm /usr/local/bin/

# Now it should be possible to run the `elm` binary just by saying its name!
#
elm --help