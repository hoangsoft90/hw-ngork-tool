#winscp 
#open ftp://hwvn@216.172.164.142/

$i=0
$cond=1
while($cond -eq 1){
    $i++;
    Write-Host $i
    if($i -ge 10) {
        $cond=0
    }
}