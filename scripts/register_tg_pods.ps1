param (
    [string]$Region = "ap-southeast-1",
    [string]$Cluster = "eks-ap-southeast-1",
    [string]$Namespace = "retail-store-sample-prod",
    [string]$TargetGroupName = "aws-ha-zero-downtime-primary-tg"
)

# 1. Update kubeconfig
Write-Host "Updating kubeconfig for EKS cluster $Cluster in $Region..."
aws eks update-kubeconfig --name $Cluster --region $Region

# 2. Get Target Group ARN
Write-Host "Retrieving Target Group ARN for $TargetGroupName..."
$tgArn = (aws elbv2 describe-target-groups --region $Region --names $TargetGroupName --query "TargetGroups[0].TargetGroupArn" --output text)
if ($null -eq $tgArn -or $tgArn -eq "None") {
    Write-Error "Target Group $TargetGroupName not found in region $Region."
    exit 1
}
Write-Host "Target Group ARN: $tgArn"

# 3. Get Pod IPs
Write-Host "Retrieving Pod IPs for deployment ui in namespace $Namespace..."
$podIps = (kubectl get pods -n $Namespace -l app.kubernetes.io/name=ui -o jsonpath='{.items[*].status.podIP}')
if ([string]::IsNullOrEmpty($podIps)) {
    Write-Warning "No running pods found for retail-store-sample-app in namespace $Namespace."
    exit 0
}

$ips = $podIps -split " "
Write-Host "Found Pod IPs: ($($ips -join ', '))"

# 4. Register targets
$targets = @()
foreach ($ip in $ips) {
    if ($ip.Trim() -ne "") {
        $targets += "Id=$ip,Port=8080"
    }
}

if ($targets.Count -gt 0) {
    $targetsArg = $targets -join " "
    Write-Host "Registering targets: $targetsArg"
    Invoke-Expression "aws elbv2 register-targets --region $Region --target-group-arn $tgArn --targets $targetsArg"
    Write-Host "Successfully registered targets!"
}
