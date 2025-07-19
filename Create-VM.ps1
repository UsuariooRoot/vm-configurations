param (
  [string]$RGName = "MyRG",
  [string]$VMName = "MyVM",
  [string]$Location = "westus3",
  [string]$Size = "Standard_B2als_v2"
)

# Verificar si ya estamos conectados a Azure
try {
  $context = Get-AzContext
  if ($null -eq $context) {
    Write-Host "No hay sesión activa de Azure. Conectando..." -ForegroundColor Yellow
    Connect-AzAccount
  }
  else {
    Write-Host "Ya conectado a Azure como: $($context.Account.Id)" -ForegroundColor Green
  }
}
catch {
  Write-Host "Error al verificar la conexión. Intentando conectar..." -ForegroundColor Yellow
  Connect-AzAccount
}

# Buscar y seleccionar la suscripción de Azure for Students
try {
  $studentSubscription = Get-AzSubscription | Where-Object { $_.Name -like "*student*" -or $_.Name -like "*Student*" }
    
  if ($studentSubscription) {
    if ($studentSubscription.Count -gt 1) {
      Write-Host "Se encontraron múltiples suscripciones de estudiante:" -ForegroundColor Yellow
      $studentSubscription | ForEach-Object { Write-Host "- $($_.Name)" }
      $selectedSub = $studentSubscription[0]
    }
    else {
      $selectedSub = $studentSubscription
    }
        
    Set-AzContext -SubscriptionId $selectedSub.Id
    Write-Host "Suscripción seleccionada: $($selectedSub.Name)" -ForegroundColor Green
  }
  else {
    Write-Host "No se encontró suscripción de Azure for Students. Usando la suscripción actual." -ForegroundColor Yellow
  }
}
catch {
  Write-Host "Error al seleccionar la suscripción. Continuando con la actual..." -ForegroundColor Yellow
}

# Definir credenciales
$Username = "azureuser"
$Password = ConvertTo-SecureString "Pa$$w0rd123!" -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential ($Username, $Password)

# Crear VM (y el RG si no existe)
try {
  Write-Host "Creando VM '$VMName' en el grupo de recursos '$RGName'..." -ForegroundColor Cyan
    
  New-AzVM `
    -ResourceGroupName $RGName `
    -Name $VMName `
    -Location $Location `
    -Image "Ubuntu2204" `
    -Size $Size `
    -VirtualNetworkName ($RGName + "Vnet") `
    -SubnetName ($RGName + "Subnet") `
    -SecurityGroupName ($RGName + "NSG") `
    -PublicIpAddressName ($RGName + "PIP") `
    -Credential $Cred `
    -OpenPorts 22, 443
    
  Write-Host "VM creada exitosamente!" -ForegroundColor Green
}
catch {
  Write-Host "Error al crear la VM: $($_.Exception.Message)" -ForegroundColor Red
}