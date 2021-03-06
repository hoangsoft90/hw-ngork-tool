#do not enable this line
#Set-ExecutionPolicy RemoteSigned
$pinvoke = add-type -name pinvoke -passThru -memberDefinition @'

[DllImport("user32.dll", CharSet = CharSet.Auto)]
public static extern bool SetWindowText(IntPtr hwnd, String lpString);

'@

#current project directory
$ScriptRoot = Split-Path $MyInvocation.MyCommand.Path
$change_ngrok="localhost"

$remind_phpmyadmin_pass="$ScriptRoot/old-phpmyadmin-pass.txt"
$remind_ngrok_process="$ScriptRoot/ngrok-process.txt"

#$site_slug=Read-host "Enter site slug you want to reset ?"
# since we scan all sites in network
$site_slug = ""

echo "Note: for my plugins use `skin class` such as 'hw-list-custom-taxonomy-widget,hw-pagenavi, ..' you need to access the plugin setting to refresh skin URL (since you change URL in ngork tunnel)."

#_-------kill ngrok process
if(Test-path $remind_ngrok_process){
    $processId=get-content $remind_ngrok_process|out-string
    Try{
        if(-not [string]::IsNullOrEmpty($processId)) {
            #stop-process -id $processId  #not work
            start-process "cmd.exe" "/C taskkill /PID $processId" -wait
            
            #remove file that store ngork process id
            Remove-item $remind_ngrok_process
        }
    }
    Catch{
        echo "Can't not find process ID=$processId"
    }
    Write-Host "Press any key to continue ..."
    #$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
#---------------reset phpmyadmin password
$config="C:/xampp/phpMyAdmin/config.inc.php"
if (Test-path "$ScriptRoot/old-phpmyadmin-pass.txt"){
    $pass = get-content -path $remind_phpmyadmin_pass
}
else {
    #default pass
    $pass = "hoang"
}
$content=(get-content $config|out-string)
if($content -match ".+'password'.+=(.+)"){

    #$content=$content -replace $matches[0],"XX"
    $content -replace $matches[1],("'{0}';" -f $pass)|Foreach {$_.TrimEnd()} | where {$_ -ne ""}|set-content $config
    
    #$content
}
#===================================edit wp-config.php=======================================
$wp_config="E:\HoangData\xampp_htdocs\wpmultisite/wp-config.php"
$config_str=(get-content $wp_config|out-string)

#find ngrok id
if($config_str -match "define[\('\s]+NGROK_ID.+"){
    $pattern = "define[\('\s]+NGROK_ID.+"
    $config_str=[regex]::Replace(
        $config_str, 
        $pattern, 
        { 
            "define('NGROK_ID', '');"
        }
    )
}
if($config_str -match "(\$)ngrok_url.+"){
    #make sure ngrok ID is match values in wp-config.php
    $matches[0]=$matches[0] -replace '\$','\$'
    $config_str=$config_str -replace $matches[0],'$ngrok_url=HW_ORIGINAL_URL;'
}
$config_str=$config_str | Foreach {$_.TrimEnd()} | where {$_ -ne ""}
$config_str|set-content $wp_config
#---------------reset domain column in wp_blogs table
#$changeurl="/c curl -sS `"http://localhost/wpmultisite/hoang/hw-changeurl.php?do=off_site&domain={0}&site={1}`"" -f ($change_ngrok,$site_slug)
$changeurl="/c curl -sS `"http://localhost/wpmultisite/hoang/hw-changeurl.php?do=off_site`""
$cond=1
while($cond -eq 1){
    #Start-Process "cmd.exe" $changeurl -passthru -wait
    #start-process "http://localhost/wpmultisite/hoang/hw-changeurl.php?do=off_site"
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "cmd.exe"
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $changeurl

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    
    if($stdout.Trim() -eq ""){
        $cond=0
    }
    #Write-Host "stdout: $stdout"
    #Write-Host "stderr: $stderr"
    #Write-Host "exit code: " + $p.ExitCode
}
<#

#>