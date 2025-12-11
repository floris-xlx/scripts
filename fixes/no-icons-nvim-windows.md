No icons on windows (nvim) no matter if its powershell or alacritty,
This is because theres a degraded GUI as it doesnt support POSIX PTY
install this via powershell admin;
(experimental)
```
winget install wez.wezterm
winget install nushell
winget install Neovim 
```

Then modify alacritty

```toml
shell:
  program: wezterm
  args:
    - start
    - --pty
    - nvim
```



Alacritty configs can be fouund here on windows;
%APPDATA%\alacritty\alacritty.toml

* Older versions can also be a .yml file


