Set-ExecutionPolicy RemoteSigned
cd "E:\HoangData\softwares\utilities\PS2EXE-v0.5.0.0"
$source="E:\HoangData\HoangWeb\projects\public-ngrok"
.\ps2exe.ps1 -inputFile "$source/hw-ngrok-reset.ps1" -outputFile "$source/hw-ngrok-reset.exe"