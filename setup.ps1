# 呆呆鸟小龙虾配置脚本
# 支持自定义 URL、API Key 和模型

$ConfigDir = "$env:USERPROFILE\.daidaibird"
$ConfigFile = "$ConfigDir\config.ps1"

$DefaultUrl = "https://api.daidaibird.top"
$DefaultModel = "gpt-4o"

function Load-Config {
    if (Test-Path $ConfigFile) {
        . $ConfigFile
    }
}

function Save-Config {
    if (-not (Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }
    @"
`$script:ApiUrl = "$script:ApiUrl"
`$script:ApiKey = "$script:ApiKey"
`$script:Model = "$script:Model"
"@ | Set-Content -Path $ConfigFile -Encoding UTF8
    Write-Host "配置已保存到 $ConfigFile" -ForegroundColor Green
}

function Select-Model {
    Write-Host "`n=== 选择模型 ===" -ForegroundColor Cyan
    $currentModel = if ($script:Model) { $script:Model } else { "未设置" }
    Write-Host "当前模型: $currentModel`n" -ForegroundColor Yellow

    $url = if ($script:ApiUrl) { $script:ApiUrl } else { $DefaultUrl }
    $key = $script:ApiKey

    if ($key) {
        Write-Host "正在从 $url 获取可用模型列表..."
        try {
            $headers = @{ "Authorization" = "Bearer $key" }
            $response = Invoke-RestMethod -Uri "$url/v1/models" -Headers $headers -TimeoutSec 10 -ErrorAction Stop
            $models = $response.data | ForEach-Object { $_.id } | Sort-Object

            if ($models.Count -gt 0) {
                Write-Host "找到 $($models.Count) 个可用模型:`n" -ForegroundColor Green
                for ($i = 0; $i -lt $models.Count; $i++) {
                    $num = $i + 1
                    if ($models[$i] -eq $script:Model) {
                        Write-Host "  $num) $($models[$i]) <- 当前" -ForegroundColor Green
                    } else {
                        Write-Host "  $num) $($models[$i])"
                    }
                }
                Write-Host ""
                Write-Host "  0) 手动输入自定义模型"
                Write-Host ""
                $choice = Read-Host "选择模型编号 (回车保持不变)"

                if ([string]::IsNullOrEmpty($choice)) {
                    if (-not $script:Model) { $script:Model = $DefaultModel }
                } elseif ($choice -eq "0") {
                    $custom = Read-Host "输入自定义模型名称"
                    if ($custom) { $script:Model = $custom }
                } elseif ($choice -match '^\d+$') {
                    $idx = [int]$choice
                    if ($idx -ge 1 -and $idx -le $models.Count) {
                        $script:Model = $models[$idx - 1]
                        Write-Host "已选择: $($script:Model)" -ForegroundColor Green
                    } else {
                        Write-Host "无效选择，保持当前模型" -ForegroundColor Red
                    }
                } else {
                    Write-Host "无效选择，保持当前模型" -ForegroundColor Red
                }
            } else {
                Write-Host "无法获取模型列表，请手动输入" -ForegroundColor Yellow
                $custom = Read-Host "模型名称 [$currentModel]"
                if ($custom) { $script:Model = $custom }
                elseif (-not $script:Model) { $script:Model = $DefaultModel }
            }
        } catch {
            Write-Host "获取模型列表失败: $($_.Exception.Message)" -ForegroundColor Yellow
            $custom = Read-Host "模型名称 [$currentModel]"
            if ($custom) { $script:Model = $custom }
            elseif (-not $script:Model) { $script:Model = $DefaultModel }
        }
    } else {
        Write-Host "尚未设置 API Key，请手动输入模型名称" -ForegroundColor Yellow
        $custom = Read-Host "模型名称 [$DefaultModel]"
        if ($custom) { $script:Model = $custom }
        else { $script:Model = $DefaultModel }
    }
}

function Configure-Api {
    Write-Host "`n=== API 配置 ===" -ForegroundColor Cyan

    $defaultDisplay = if ($script:ApiUrl) { $script:ApiUrl } else { $DefaultUrl }
    $inputUrl = Read-Host "API 地址 [$defaultDisplay]"
    if ($inputUrl) { $script:ApiUrl = $inputUrl.TrimEnd('/') }
    elseif (-not $script:ApiUrl) { $script:ApiUrl = $DefaultUrl }

    if ($script:ApiKey) {
        $masked = $script:ApiKey.Substring(0, 8) + "..." + $script:ApiKey.Substring($script:ApiKey.Length - 4)
        Write-Host "当前 API Key: $masked" -ForegroundColor Yellow
        $inputKey = Read-Host "输入新 API Key (留空保持不变)"
        if ($inputKey) { $script:ApiKey = $inputKey }
    } else {
        $inputKey = Read-Host "API Key (sk-xxx)"
        if (-not $inputKey) {
            Write-Host "API Key 不能为空" -ForegroundColor Red
            return
        }
        $script:ApiKey = $inputKey
    }

    Select-Model
    Save-Config
    Write-Host "`n配置完成!" -ForegroundColor Green
    Show-Config
}

function Show-Config {
    Write-Host "`n=== 当前配置 ===" -ForegroundColor Cyan
    if (-not (Test-Path $ConfigFile)) {
        Write-Host "尚未配置，请先运行配置" -ForegroundColor Yellow
        return
    }
    Load-Config
    $urlDisplay = if ($script:ApiUrl) { $script:ApiUrl } else { "未设置" }
    Write-Host "  API 地址: $urlDisplay" -ForegroundColor Green
    if ($script:ApiKey) {
        $masked = $script:ApiKey.Substring(0, 8) + "..." + $script:ApiKey.Substring($script:ApiKey.Length - 4)
        Write-Host "  API Key:  $masked" -ForegroundColor Green
    } else {
        Write-Host "  API Key:  未设置" -ForegroundColor Red
    }
    $modelDisplay = if ($script:Model) { $script:Model } else { "未设置" }
    Write-Host "  模型:     $modelDisplay" -ForegroundColor Green
    Write-Host ""
}

function Test-Connection {
    Write-Host "`n=== 测试 API 连接 ===" -ForegroundColor Cyan
    Load-Config

    if (-not $script:ApiKey) {
        Write-Host "请先配置 API Key" -ForegroundColor Red
        return
    }

    Write-Host "正在测试连接 $($script:ApiUrl) ..." -ForegroundColor Yellow
    Write-Host "使用模型: $($script:Model)`n" -ForegroundColor Yellow

    try {
        $headers = @{
            "Content-Type"  = "application/json"
            "Authorization" = "Bearer $($script:ApiKey)"
        }
        $body = @{
            model      = $script:Model
            messages   = @(@{ role = "user"; content = "Hi, reply with only: OK" })
            max_tokens = 10
        } | ConvertTo-Json -Depth 3

        $response = Invoke-RestMethod -Uri "$($script:ApiUrl)/v1/chat/completions" `
            -Method Post -Headers $headers -Body $body -TimeoutSec 30 -ErrorAction Stop

        Write-Host "连接成功! (HTTP 200)" -ForegroundColor Green
        $reply = $response.choices[0].message.content
        if ($reply) {
            Write-Host "模型回复: $reply" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "连接失败!" -ForegroundColor Red
        Write-Host "错误: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

function Export-Env {
    Write-Host "`n=== 导出环境变量 ===" -ForegroundColor Cyan
    Load-Config

    if (-not $script:ApiKey) {
        Write-Host "请先配置 API" -ForegroundColor Red
        return
    }

    Write-Host "`n以下命令可设置用户环境变量:`n" -ForegroundColor Yellow
    Write-Host "[Environment]::SetEnvironmentVariable('OPENAI_API_BASE', '$($script:ApiUrl)/v1', 'User')"
    Write-Host "[Environment]::SetEnvironmentVariable('OPENAI_API_KEY', '$($script:ApiKey)', 'User')"
    Write-Host "[Environment]::SetEnvironmentVariable('OPENAI_MODEL', '$($script:Model)', 'User')"
    Write-Host "[Environment]::SetEnvironmentVariable('OPENAI_BASE_URL', '$($script:ApiUrl)/v1', 'User')"
    Write-Host ""

    $autoWrite = Read-Host "是否自动写入用户环境变量? (y/N)"
    if ($autoWrite -match '^[Yy]$') {
        [Environment]::SetEnvironmentVariable('OPENAI_API_BASE', "$($script:ApiUrl)/v1", 'User')
        [Environment]::SetEnvironmentVariable('OPENAI_API_KEY', $script:ApiKey, 'User')
        [Environment]::SetEnvironmentVariable('OPENAI_MODEL', $script:Model, 'User')
        [Environment]::SetEnvironmentVariable('OPENAI_BASE_URL', "$($script:ApiUrl)/v1", 'User')
        [Environment]::SetEnvironmentVariable('API_BASE_URL', $script:ApiUrl, 'User')
        Write-Host "已写入用户环境变量，重启终端生效" -ForegroundColor Green
    }
    Write-Host ""
}

function Switch-Model {
    Load-Config
    Select-Model
    Save-Config
    Write-Host ""
}

function Delete-Config {
    Write-Host "`n=== 删除配置 ===" -ForegroundColor Cyan
    $confirm = Read-Host "确认删除所有配置? (y/N)"
    if ($confirm -match '^[Yy]$') {
        if (Test-Path $ConfigDir) {
            Remove-Item -Path $ConfigDir -Recurse -Force
        }
        $script:ApiUrl = $null
        $script:ApiKey = $null
        $script:Model = $null
        Write-Host "配置已删除" -ForegroundColor Green
    } else {
        Write-Host "已取消"
    }
    Write-Host ""
}

# === 命令行参数 ===
if ($args.Count -gt 0) {
    Load-Config
    switch ($args[0]) {
        "--url"    { $script:ApiUrl = $args[1].TrimEnd('/'); Save-Config; exit }
        "--key"    { $script:ApiKey = $args[1]; Save-Config; exit }
        "--model"  { $script:Model = $args[1]; Save-Config; exit }
        "--test"   { Test-Connection; exit }
        "--show"   { Show-Config; exit }
        "--export" { Export-Env; exit }
        { $_ -in "--help", "-h" } {
            Write-Host "用法: .\setup.ps1 [选项]"
            Write-Host ""
            Write-Host "交互模式:  .\setup.ps1"
            Write-Host ""
            Write-Host "快捷参数:"
            Write-Host "  --url <URL>      设置 API 地址"
            Write-Host "  --key <KEY>      设置 API Key"
            Write-Host "  --model <MODEL>  设置模型"
            Write-Host "  --test           测试连接"
            Write-Host "  --show           查看配置"
            Write-Host "  --export         导出环境变量"
            Write-Host "  -h, --help       显示帮助"
            exit
        }
    }
}

# === 交互模式 ===
Write-Host ""
Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       呆呆鸟小龙虾配置脚本 v1.0              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Load-Config

while ($true) {
    Write-Host "[1] 配置 API (URL / Key / 模型)" -ForegroundColor Green
    Write-Host "[2] 查看当前配置" -ForegroundColor Green
    Write-Host "[3] 测试 API 连接" -ForegroundColor Green
    Write-Host "[4] 导出环境变量" -ForegroundColor Green
    Write-Host "[5] 切换模型" -ForegroundColor Green
    Write-Host "[6] 删除配置" -ForegroundColor Green
    Write-Host "[0] 退出" -ForegroundColor Green
    Write-Host ""
    $choice = Read-Host "请选择 [0-6]"
    switch ($choice) {
        "1" { Configure-Api }
        "2" { Show-Config }
        "3" { Test-Connection }
        "4" { Export-Env }
        "5" { Switch-Model }
        "6" { Delete-Config }
        "0" { Write-Host "再见!" -ForegroundColor Green; exit }
        default { Write-Host "无效选择`n" -ForegroundColor Red }
    }
}
