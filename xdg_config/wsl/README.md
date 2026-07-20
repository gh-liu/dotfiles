# wsl

```powershell

# 1. 端口、防火墙

$listenPort = 9092
$wslIp = wsl -- hostname -I | ForEach-Object { $_.Split(' ')[0] }
netsh interface portproxy add v4tov4 `
    listenaddress=0.0.0.0 `
    listenport=$listenPort `
    connectaddress=$wslIp `
    connectport=$listenPort

New-NetFirewallRule `
  -Name "WSL-Port-9092" `
  -DisplayName "WSL Port 9092" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort $listenPort `
  -Action Allow

# 2. 列表、删除

netsh interface portproxy show all
netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=8080

Get-NetFirewallRule |
    Where-Object DisplayName -like "*WSL*"

Get-NetFirewallPortFilter

Remove-NetFirewallRule `
    -Name "WSL-Port-8080"
```

