#Set-ExecutionPolicy RemoteSigned    #do not enable this line
#current project directory
$ScriptRoot = Split-Path $MyInvocation.MyCommand.Path

."$ScriptRoot\functions.ps1"

$pinvoke = add-type -name pinvoke -passThru -memberDefinition @'

[DllImport("user32.dll", CharSet = CharSet.Auto)]
public static extern bool SetWindowText(IntPtr hwnd, String lpString);

'@

#===================================start ngork=========================================
#$ngrok_user= Read-Host 'ngrok user =?';
#$ngrok_pass= Read-Host 'ngrok pass =?';
<#
# added to ngrok.yml configuration file
$diff_port=Read-host "Use one other port behind, ie: 8080, i using VisualSVN Server listening 8080 port."
if ([string]::IsNullOrEmpty($diff_port)) {
    $diff_port="80"
    echo "Use default port: 80"
}
#>
#Start-Process "cmd.exe"  ("/c ngrok -authtoken gwUgKJWPQZH6FW1mz2oZ -httpauth='{0}:{1}' 80" -f ($ngrok_user,$ngrok_pass))
# -subdomain=hoangweb --> read from ngrok.yml
$ngrok=Start-Process "cmd.exe" "/c cd $ScriptRoot&&bin\ngrok_old.exe -config ngrok.yml start hw-xampp hw-vsvn hw-ftp&&timeout /t 5"  -passthru

$ngrok_status= questionYesNo 'Do you see tunnel "hw-xampp" working ? if run ngrok failt, try other tunnel name in ngrok.yml file.'
if ($ngrok_status -eq 1){
    exit
}
echo $ngrok_status


$ngrok_id="hw-xampp"
$change_ngrok="{0}.ngrok.com" -f $ngrok_id

$remind_phpmyadmin_pass="$ScriptRoot/old-phpmyadmin-pass.txt"
$remind_ngrok_process="$ScriptRoot/ngrok-process.txt"

#---------save ngrok process
For ($i=0; $i -le 5; $i++) {
    if (-not [string]::IsNullOrEmpty($ngrok.Id)){
        $pinvoke::setWindowText($ngrok.mainWindowHandle, "Hoangweb.COM - Share localhost")        
        #$pinvoke::setProcessName($notepad.mainWindowHandle, "hoang")
    }
}
(""+$ngrok.Id+"").Trim()|set-content $remind_ngrok_process

#===================================config.inc.php=========================================
$config="C:/xampp/phpMyAdmin/config.inc.php"
$pass = randomStr 10
$content=(get-content $config|out-string)
if($content -match ".+'password'.+=(.+)"){
    
    #save old passs
    ($matches[1] -replace "^(\s+)?('|`")|('|`")[;\s]+?$", "")|set-content $remind_phpmyadmin_pass
    
    #$content=$content -replace $matches[0],"XX"
    $content -replace $matches[1],("'{0}';" -f $pass)|Foreach {$_.TrimEnd()} | where {$_ -ne ""}|set-content $config
    
    #$content
}
#===================================edit wp-config.php=======================================
$wp_config="E:\HoangData\xampp_htdocs\wpmultisite/wp-config.php"
$config_str=(get-content $wp_config|out-string)

#find ngrok id
if($config_str -match "define.+?NGROK_ID.+"){
    #make sure ngrok ID is match values in wp-config.php
    #$config_str=$config_str -replace $matches[1],$ngrok_id
    $pattern = "define.+NGROK_ID.+"
    $config_str=[regex]::Replace(
        $config_str, 
        $pattern, 
        { 
            ("define('NGROK_ID', '{0}');" -f $ngrok_id)
        }
    )
    $config_str=$config_str | Foreach {$_.TrimEnd()} | where {$_ -ne ""}
    $config_str|set-content $wp_config
    
}
#change $ngrok_url
if($config_str -match "(\$)ngrok_url.+"){
    #make sure ngrok ID is match values in wp-config.php    
    $config_str -replace ($matches[0] -replace '\$','\$'),'$ngrok_url="http://".NGROK_ID.".ngrok.com";' |set-content $wp_config    
}

#================================change domain in wp_blogs table=====================================
$changeurl=("/c curl -sS `"http://localhost/wpmultisite/hoang/hw-changeurl.php?do=public_site&domain={0}`"" -f $change_ngrok)
#Start-Process "cmd.exe" "$changeurl" -passthru -wait

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
Write-Host "stdout: $stdout"
Write-Host "stderr: $stderr"
Write-Host "exit code: " + $p.ExitCode

#====================================httpd-vhosts.conf=============================================
#edit httpd-vhosts.conf
#note: do not need

$virtualHost=@"
<VirtualHost $ngrok_id.ngrok.com>
     DocumentRoot "D:/HoangData/xampp_htdocs/"
     ServerName $ngrok_id.ngrok.com
     ServerAlias $ngrok_id.ngrok.com
     CustomLog "logs/dummy-host2.$ngrok_id.ngrok.com-access.log" combined
     ErrorLog "logs/dummy-host2.$ngrok_id.ngrok.com-error.log"
     <Directory "D:/HoangData/xampp_htdocs/wpmultisite">
          Options Indexes FollowSymLinks
          AllowOverride All
          Order allow,deny
          Allow from all
     </Directory>
</VirtualHost>
"@;
$vhosts="C:\xampp\apache\conf\extra\httpd-vhosts.conf"
$content = (get-content $vhosts|out-string)


if($content -notmatch "ngrok.com"){
    #add-content $vhosts $virtualHost
}
else{ 
    if( $content -match "(\.|\s)[\w]+\.ngrok\.com"){
        $content=$content -replace $matches[0]," $change_ngrok"
        
    }
    #$content
    #if( $content -match "(\s)[\w]+\.ngrok\.com"){
     #   $content=$content -replace $matches[0]," $change_ngrok"
        
    #}
    #$content|set-content $vhosts
    
}
#===================================HOSTS======================================================
# Uncomment lines with localhost on them:
$hostsPath = "$env:windir\System32\drivers\etc\hosts"
$hostsPath1 = "E:\HoangData\softwares\utilities\hosts file manager\hosts"
$hostsPath1_HOSTS = $hostsPath1+"\HOSTS";
$hosts = get-content $hostsPath1_HOSTS|Out-String


####
# modify hosts file
####
if($hosts -match '.+ngrok.com')
{
#$hosts = $hosts -replace "`n", "`r`n"
$hosts=($hosts -replace $matches[0],"127.0.0.1  $ngrok_id.ngrok.com")
$hosts=$hosts | Foreach {$_.TrimEnd()} | where {$_ -ne ""}
 $hosts|set-content $hostsPath1_HOSTS -Encoding UTF8
}
else {
    #$hosts=$hosts | Foreach {$_.TrimEnd()} | where {$_ -ne ""}
    "`n127.0.0.1 $ngrok_id.ngrok.com"|add-content $hostsPath1_HOSTS -Encoding UTF8
}
####update hosts file
Start-Process "$hostsPath1/mvps.bat" -verb runAs

#=================================restart XAMPP==========================================
$comment=@'
$mypid=tcpPort "80"
$mypid
if([string]::IsNullOrEmpty($mypid)){
    
}else{
    stop-process -id $mypid
}

$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.RedirectStandardError = $true
$pinfo.RedirectStandardOutput = $true
$pinfo.UseShellExecute = $false
#$pinfo.Arguments = "localhost"
$pinfo.FileName = "c:/xampp/xampp_stop.exe"

$p = New-Object System.Diagnostics.Process
$p.StartInfo = $pinfo

$p.Start() | Out-Null
$p.WaitForExit()

$pinfo.FileName = "c:/xampp/xampp_start.exe"
$p.StartInfo = $pinfo
$p.Start() | Out-Null
$p.WaitForExit()
'@;
#open url
Start-Process "http://localhost:4040"    #track ngrok request
Start-Process "http://$ngrok_id.ngrok.com/wpmultisite/"

#Write-Host "Press any key to continue ..."
#Start-Sleep -s 60