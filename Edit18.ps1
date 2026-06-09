# Edit.ps1 - 整合版规则编辑器
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
# 启用 Windows Forms 视觉样式和高 DPI 支持
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

# 声明进程支持 DPI 感知（Windows 8.1 以上）
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class DpiHelper {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")]
    public static extern int SetProcessDpiAwareness(int value);
}
"@
try { [DpiHelper]::SetProcessDPIAware() } catch { }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rulesDir = Join-Path $scriptDir "rules"

if (-not (Test-Path $rulesDir)) {
    [System.Windows.Forms.MessageBox]::Show("未找到 rules 文件夹！`n路径: $rulesDir", "错误", 'OK', 'Error')
    exit
}

# 全局变量
$script:currentFilePath = $null
$script:fileData = @{}
$script:editingTextBox = $null
$script:allowTitleEdit = $false

# 函数定义
function LoadFileData($filePath) {
    if ($script:fileData.ContainsKey($filePath)) { return $script:fileData[$filePath] }
    $titles = @()
    $titleRules = @{}
    $currentTitle = $null
    $orphanRules = @()
    if (Test-Path $filePath) {
        $lines = Get-Content $filePath -Encoding UTF8
        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            if ($trimmed -eq "") { continue }
            if ($trimmed -match '^#') {
                $currentTitle = $trimmed -replace '^#\s*', ''
                if ($currentTitle -eq "") { $currentTitle = "空标题" }
                if (-not $titleRules.ContainsKey($currentTitle)) {
                    $titles += $currentTitle
                    $titleRules[$currentTitle] = [System.Collections.ArrayList]::new()
                }
            } else {
                if ($currentTitle) { $titleRules[$currentTitle].Add($line) }
                else { $orphanRules += $line }
            }
        }
        if ($titles.Count -eq 0) {
            if ($orphanRules.Count -gt 0) {
                $titles = @("未分类")
                $titleRules["未分类"] = [System.Collections.ArrayList]::new($orphanRules)
            }
        } else {
            if ($orphanRules.Count -gt 0) {
                $firstTitle = $titles[0]
                $titleRules[$firstTitle].AddRange($orphanRules)
            }
        }
    }
    $data = @{ titles = $titles; titleRules = $titleRules }
    $script:fileData[$filePath] = $data
    return $data
}

function SaveCurrentFile {
    if (-not $script:currentFilePath) { return }
    $data = $script:fileData[$script:currentFilePath]
    $titles = $data.titles
    $titleRules = $data.titleRules
    $output = @()
    foreach ($title in $titles) {
        $output += "# $title"
        foreach ($rule in $titleRules[$title]) { $output += $rule }
        $output += ""
    }
    while ($output.Count -gt 0 -and $output[-1] -eq "") { $output = $output[0..($output.Count-2)] }
    $output | Out-File -FilePath $script:currentFilePath -Encoding UTF8 -Force
}

function RefreshTreeView {
    $treeView.Nodes.Clear()
    if (-not $script:currentFilePath) { return }
    $data = $script:fileData[$script:currentFilePath]
    foreach ($title in $data.titles) {
        $node = New-Object System.Windows.Forms.TreeNode($title)
        $node.Tag = $title
        $treeView.Nodes.Add($node)
    }
    if ($treeView.Nodes.Count -gt 0) {
        $treeView.SelectedNode = $treeView.Nodes[0]
        RefreshRuleList
    } else { $listView.Items.Clear() }
}

function RefreshRuleList {
    $listView.Items.Clear()
    if (-not $treeView.SelectedNode) { return }
    if (-not $script:currentFilePath) { return }
    $currentTitle = $treeView.SelectedNode.Tag
    $data = $script:fileData[$script:currentFilePath]
    if ($data.titleRules.ContainsKey($currentTitle)) {
        foreach ($rule in $data.titleRules[$currentTitle]) {
            $null = $listView.Items.Add($rule)
        }
    }
}

function SaveCurrentEdit {
    $tb = $script:editingTextBox
    if (-not $tb -or $tb.IsDisposed) { return }
    $newRule = $tb.Text.Trim()
    if ($newRule -ne "") {
        $tag = $tb.Tag
        $data = $script:fileData[$script:currentFilePath]
        $data.titleRules[$tag.Title][$tag.Index] = $newRule
        if ($tag.Index -lt $listView.Items.Count) {
            $listView.Items[$tag.Index].Text = $newRule
        }
    }
    $tb.Dispose()
    $script:editingTextBox = $null
}

# 创建窗体
$form = New-Object System.Windows.Forms.Form
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
$form.Text = "规则编辑器"
$form.Font = [System.Drawing.Font]::new("Segoe UI", 9)
$form.Size = New-Object System.Drawing.Size(1200, 700)
$form.MinimumSize = New-Object System.Drawing.Size(1000, 500)
$form.StartPosition = "CenterScreen"

$form.Add_FormClosing({
    if ($script:editingTextBox -and -not $script:editingTextBox.IsDisposed) {
        $script:editingTextBox.Dispose()
        $script:editingTextBox = $null
    }
})

# 左侧文件列表
$fileListView = New-Object System.Windows.Forms.ListView
$fileListView.Location = New-Object System.Drawing.Point(10, 10)
$fileListView.Size = New-Object System.Drawing.Size(250, 600)
$fileListView.View = [System.Windows.Forms.View]::Details
$fileListView.FullRowSelect = $true
$fileListView.GridLines = $true
$fileListView.MultiSelect = $false
$fileListView.Columns.Add("规则文件", 230)
$fileListView.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left

$txtFiles = Get-ChildItem -Path $rulesDir -Filter "*.txt" -File
foreach ($file in $txtFiles) {
    $item = New-Object System.Windows.Forms.ListViewItem($file.Name)
    $item.Tag = $file.FullName
    $fileListView.Items.Add($item)
}

$fileListView.Add_SelectedIndexChanged({
    if ($fileListView.SelectedItems.Count -eq 0) { return }
    $selected = $fileListView.SelectedItems[0]
    $newPath = $selected.Tag
    if ($newPath -eq $script:currentFilePath) { return }
    $script:currentFilePath = $newPath
    $null = LoadFileData $script:currentFilePath
    RefreshTreeView
})

# ---------- 左侧文件列表右键菜单：删除规则文件 ----------
$fileContextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$deleteFileMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$deleteFileMenuItem.Text = "删除规则文件"
$deleteFileMenuItem.Add_Click({
    if ($fileListView.SelectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("请先选中要删除的规则文件", "提示")
        return
    }
    $selectedItem = $fileListView.SelectedItems[0]
    $filePath = $selectedItem.Tag
    $fileName = [System.IO.Path]::GetFileName($filePath)
    
    # 使用字符串拼接，避免引号嵌套问题
    $msg = '确定要删除规则文件 "' + $fileName + '" 吗？'
    $result = [System.Windows.Forms.MessageBox]::Show($msg, "确认", 'YesNo', 'Warning')
    if ($result -eq 'Yes') {
        try {
            Remove-Item -Path $filePath -Force
            $fileListView.Items.Remove($selectedItem)
            if ($script:currentFilePath -eq $filePath) {
                $script:currentFilePath = $null
                $treeView.Nodes.Clear()
                $listView.Items.Clear()
            }
            if ($script:fileData.ContainsKey($filePath)) {
                $script:fileData.Remove($filePath)
            }
            [System.Windows.Forms.MessageBox]::Show("文件已删除", "完成", 'OK', 'Information')
        } catch {
            [System.Windows.Forms.MessageBox]::Show("删除失败：$_", "错误", 'OK', 'Error')
        }
    }
})
$fileContextMenu.Items.Add($deleteFileMenuItem)
$fileListView.ContextMenuStrip = $fileContextMenu

# 中间标题树
$treeView = New-Object System.Windows.Forms.TreeView
$treeView.Font = [System.Drawing.Font]::new("Segoe UI", 9)
$treeView.Location = New-Object System.Drawing.Point(270, 10)
$treeView.Size = New-Object System.Drawing.Size(250, 600)
$treeView.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$treeView.FullRowSelect = $true
$treeView.HideSelection = $false
$treeView.LabelEdit = $true

$treeView.Add_BeforeLabelEdit({
    if (-not $script:allowTitleEdit) { $_.CancelEdit = $true }
    $script:allowTitleEdit = $false
})

$treeView.Add_DoubleClick({
    $node = $treeView.SelectedNode
    if ($node -and $node.Tag -ne "未分类") {
        $script:allowTitleEdit = $true
        $node.BeginEdit()
    } elseif ($node -and $node.Tag -eq "未分类") {
        [System.Windows.Forms.MessageBox]::Show('不能编辑"未分类"标题', "提示")
    }
})

$treeView.Add_AfterLabelEdit({
    $node = $_.Node
    $newText = $_.Label
    $oldTitle = $node.Tag
    if ([string]::IsNullOrWhiteSpace($newText) -or $newText -eq $oldTitle) {
        $_.CancelEdit = $true
        return
    }
    $data = $script:fileData[$script:currentFilePath]
    if ($data.titleRules.ContainsKey($newText)) {
        [System.Windows.Forms.MessageBox]::Show("标题 '$newText' 已存在", "提示")
        $_.CancelEdit = $true
        return
    }
    $data.titleRules[$newText] = $data.titleRules[$oldTitle]
    $data.titleRules.Remove($oldTitle)
    $index = [array]::IndexOf($data.titles, $oldTitle)
    if ($index -ge 0) { $data.titles[$index] = $newText }
    $node.Text = $newText
    $node.Tag = $newText
    RefreshRuleList
    $_.CancelEdit = $false
})

$treeView.Add_AfterSelect({
    if ($script:editingTextBox -and -not $script:editingTextBox.IsDisposed) { SaveCurrentEdit }
    RefreshRuleList
})

# 右侧规则列表
$listView = New-Object System.Windows.Forms.ListView
$listView.Location = New-Object System.Drawing.Point(530, 10)
$listView.Font = [System.Drawing.Font]::new("Segoe UI", 9)
$listView.Size = New-Object System.Drawing.Size(650, 600)
$listView.View = [System.Windows.Forms.View]::Details
$listView.FullRowSelect = $true
$listView.GridLines = $true
$listView.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$listView.Columns.Add("规则内容", 640)

# 右键菜单
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$addRuleMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$addRuleMenuItem.Text = "添加新规则"
$addRuleMenuItem.Add_Click({
    if (-not $treeView.SelectedNode) {
        [System.Windows.Forms.MessageBox]::Show("请先选择一个标题", "提示")
        return
    }
    $currentTitle = $treeView.SelectedNode.Tag
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "添加新规则"
    $inputForm.Size = New-Object System.Drawing.Size(700, 220)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $inputForm.MaximizeBox = $false
    $inputForm.MinimizeBox = $false
    $label = New-Object System.Windows.Forms.Label -Property @{Text="路径："; Location='10,15'; Size='70,20'}
    $textBox = New-Object System.Windows.Forms.TextBox -Property @{
        Location='80,12'
        Size='590,60'
        Multiline=$true
        WordWrap=$true
        ScrollBars='Vertical'
        Font=[System.Drawing.Font]::new("Consolas", 11)   # 使用等宽字体方便查看路径
    }
    
    # 创建四个快捷按钮
    $btnProgram = New-Object System.Windows.Forms.Button -Property @{Text="Program"; Location='100,85'; Size='90,25'}
    $btnWindows = New-Object System.Windows.Forms.Button -Property @{Text="Windows"; Location='200,85'; Size='90,25'}
    $btnLocal = New-Object System.Windows.Forms.Button -Property @{Text="Local"; Location='300,85'; Size='90,25'}
    $btnRoaming = New-Object System.Windows.Forms.Button -Property @{Text="Roaming"; Location='400,85'; Size='90,25'}
    
    # 定义插入文本的通用函数
    $insertText = {
        param($textToInsert)
        $tb = $textBox
        if ($tb.SelectionLength -gt 0) {
            $tb.SelectedText = $textToInsert
        } else {
            $tb.Text = $tb.Text.Insert($tb.SelectionStart, $textToInsert)
            $tb.SelectionStart = $tb.SelectionStart + $textToInsert.Length
        }
        $tb.Focus()
    }
    
    $btnProgram.Add_Click({ & $insertText "%PROGRAMDATA%\" })
    $btnWindows.Add_Click({ & $insertText "%SystemRoot%\" })
    $btnLocal.Add_Click({ & $insertText "%LOCALAPPDATA%\" })
    $btnRoaming.Add_Click({ & $insertText "%APPDATA%\" })
    
    $btnOk = New-Object System.Windows.Forms.Button -Property @{Text="确定"; Location='230,125'; Size='80,30'; DialogResult='OK'}
    $btnCancel = New-Object System.Windows.Forms.Button -Property @{Text="取消"; Location='330,125'; Size='80,30'; DialogResult='Cancel'}
    
    $inputForm.Controls.AddRange(@($label, $textBox, $btnProgram, $btnWindows, $btnLocal, $btnRoaming, $btnOk, $btnCancel))
    
    if ($inputForm.ShowDialog() -eq 'OK') {
        $newRule = $textBox.Text.Trim()
        if ($newRule -ne "") {
            $data = $script:fileData[$script:currentFilePath]
            $data.titleRules[$currentTitle].Add($newRule)
            RefreshRuleList
        }
    }
    $inputForm.Dispose()
})
$contextMenu.Items.Add($addRuleMenuItem)

$deleteRuleMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$deleteRuleMenuItem.Text = "删除规则"
$deleteRuleMenuItem.Add_Click({
    if ($listView.SelectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("请先选中要删除的规则", "提示")
        return
    }
    $result = [System.Windows.Forms.MessageBox]::Show("确定删除选中的规则吗？", "确认", 'YesNo', 'Question')
    if ($result -eq 'Yes') {
        $currentTitle = $treeView.SelectedNode.Tag
        $data = $script:fileData[$script:currentFilePath]
        $selectedIndices = @()
        foreach ($item in $listView.SelectedItems) {
            $selectedIndices += $listView.Items.IndexOf($item)
        }
        $selectedIndices | Sort-Object -Descending | ForEach-Object {
            if ($_ -ge 0 -and $_ -lt $data.titleRules[$currentTitle].Count) {
                $data.titleRules[$currentTitle].RemoveAt($_)
            }
        }
        RefreshRuleList
    }
})
$contextMenu.Items.Add($deleteRuleMenuItem)

# 添加分隔线
$contextMenu.Items.Add([System.Windows.Forms.ToolStripSeparator]::new())

# 刷新菜单项（无任何提示，静默刷新）
$refreshMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$refreshMenuItem.Text = "刷新"
$refreshMenuItem.Add_Click({
    # 保存当前正在编辑的规则（如果有）
    if ($script:editingTextBox -and -not $script:editingTextBox.IsDisposed) { SaveCurrentEdit }
    
    if (-not $script:currentFilePath) { return }
    
    # 检查文件是否存在，不存在则忽略
    if (-not (Test-Path $script:currentFilePath)) { return }
    
    # 移除缓存，强制重新读取文件
    if ($script:fileData.ContainsKey($script:currentFilePath)) {
        $script:fileData.Remove($script:currentFilePath)
    }
    
    # 重新加载文件数据
    $null = LoadFileData $script:currentFilePath
    
    # 记录刷新前选中的标题
    $oldTitle = if ($treeView.SelectedNode) { $treeView.SelectedNode.Tag } else { $null }
    
    # 刷新树
    RefreshTreeView
    
    # 恢复之前选中的标题（如果还存在）
    if ($oldTitle -and $treeView.Nodes.Count -gt 0) {
        $foundNode = $null
        foreach ($node in $treeView.Nodes) {
            if ($node.Tag -eq $oldTitle) {
                $foundNode = $node
                break
            }
        }
        if ($foundNode) {
            $treeView.SelectedNode = $foundNode
        } else {
            $treeView.SelectedNode = $treeView.Nodes[0]
        }
    } elseif ($treeView.Nodes.Count -gt 0) {
        $treeView.SelectedNode = $treeView.Nodes[0]
    }
    
    RefreshRuleList
})
$contextMenu.Items.Add($refreshMenuItem)

$listView.ContextMenuStrip = $contextMenu

# 双击编辑规则
$listView.Add_DoubleClick({
    if ($script:editingTextBox -and -not $script:editingTextBox.IsDisposed) { SaveCurrentEdit }
    if (-not $treeView.SelectedNode) { return }
    if ($listView.SelectedItems.Count -eq 0) { return }
    $currentTitle = $treeView.SelectedNode.Tag
    $item = $listView.SelectedItems[0]
    $index = $listView.Items.IndexOf($item)
    $data = $script:fileData[$script:currentFilePath]
    if ($index -lt 0 -or $index -ge $data.titleRules[$currentTitle].Count) { return }
    $originalRule = $data.titleRules[$currentTitle][$index]
    $bounds = $item.GetBounds(0)
    $topLeft = $listView.PointToScreen($bounds.Location)
    $topLeft = $form.PointToClient($topLeft)
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Location = $topLeft
    $tb.AutoSize = $false
    $tb.Height = $bounds.Height
    $tb.Width = $bounds.Width
    $tb.Text = $originalRule
    $tb.Font = $listView.Font
    $tb.ForeColor = 'Black'
    $tb.BackColor = 'LightYellow'
    $tb.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $tb.Margin = 0
    $tb.Padding = 0
    $tb.Tag = @{ Title = $currentTitle; Index = $index; Saved = $false }
    $tb.Add_KeyDown({
        if ($_.KeyCode -eq 'Enter') { SaveCurrentEdit }
        elseif ($_.KeyCode -eq 'Escape') {
            if ($script:editingTextBox) { $script:editingTextBox.Dispose() }
            $script:editingTextBox = $null
        }
    })
    $tb.Add_Leave({
        if (-not $this.Tag.Saved) {
            $this.Tag.Saved = $true
            SaveCurrentEdit
        }
    })
    $form.Controls.Add($tb)
    $script:editingTextBox = $tb
    $tb.BringToFront()
    $tb.Select()
    $tb.Focus()
})

# 鼠标点击外部保存
$listView.Add_MouseDown({
    if ($script:editingTextBox) { SaveCurrentEdit }
    if ($_.Button -eq 'Right') {
        $hit = $listView.HitTest([System.Drawing.Point]::new($_.X, $_.Y))
        if ($hit.Item) { $hit.Item.Selected = $true }
    }
})
$treeView.Add_MouseDown({
    if ($script:editingTextBox) { SaveCurrentEdit }
    if ($_.Button -eq 'Right') {
        $hit = $treeView.HitTest([System.Drawing.Point]::new($_.X, $_.Y))
        if ($hit.Node) { $treeView.SelectedNode = $hit.Node }
    }
})

# ========== 标题右键菜单 ==========
$treeViewContextMenu = New-Object System.Windows.Forms.ContextMenuStrip

# 新建标题（复用“添加标题”按钮功能）
$newTitleMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$newTitleMenuItem.Text = "新建标签"
$newTitleMenuItem.Add_Click({ $btnAddTitle.PerformClick() })
$treeViewContextMenu.Items.Add($newTitleMenuItem)

# 删除标题
$deleteTitleMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$deleteTitleMenuItem.Text = "删除标签"
$deleteTitleMenuItem.Add_Click({
    $node = $treeView.SelectedNode
    if (-not $node) { return }
    $titleToDelete = $node.Tag
    if ($titleToDelete -eq "未分类") {
        [System.Windows.Forms.MessageBox]::Show('不能删除"未分类"标签', "提示")
        return
    }
    # 使用字符串拼接避免引号冲突
    $msg = '确定删除标签 "' + $titleToDelete + '" 及其所有规则吗？'
    $result = [System.Windows.Forms.MessageBox]::Show($msg, "确认", 'YesNo', 'Warning')
    if ($result -eq 'Yes') {
        $data = $script:fileData[$script:currentFilePath]
        $data.titleRules.Remove($titleToDelete)
        $data.titles = @($data.titles | Where-Object { $_ -ne $titleToDelete })
        $treeView.Nodes.Remove($node)
        if ($treeView.Nodes.Count -gt 0) {
            $treeView.SelectedNode = $treeView.Nodes[0]
            RefreshRuleList
        } else {
            $listView.Items.Clear()
        }
    }
})
$treeViewContextMenu.Items.Add($deleteTitleMenuItem)

$treeView.ContextMenuStrip = $treeViewContextMenu

# 按钮
$btnAddTitle = New-Object System.Windows.Forms.Button
$btnAddTitle.Text = "添加标签"
$btnAddTitle.Location = New-Object System.Drawing.Point(280, 620)
$btnAddTitle.Size = New-Object System.Drawing.Size(90, 30)
$btnAddTitle.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$btnAddTitle.Add_Click({
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "新建标签"
    $inputForm.Size = New-Object System.Drawing.Size(400, 130)
    $inputForm.StartPosition = "CenterParent"
    $label = New-Object System.Windows.Forms.Label -Property @{Text="标签名称："; Location='10,15'; Size='80,20'}
    $textBox = New-Object System.Windows.Forms.TextBox -Property @{Location='100,12'; Size='260,20'}
    $btnOk = New-Object System.Windows.Forms.Button -Property @{Text="确定"; Location='120,55'; Size='80,30'; DialogResult='OK'}
    $btnCancel = New-Object System.Windows.Forms.Button -Property @{Text="取消"; Location='220,55'; Size='80,30'; DialogResult='Cancel'}
    $inputForm.Controls.AddRange(@($label, $textBox, $btnOk, $btnCancel))
    if ($inputForm.ShowDialog() -eq 'OK') {
        $newTitle = $textBox.Text.Trim()
        if ($newTitle -ne "") {
            $data = $script:fileData[$script:currentFilePath]
            if (-not $data.titleRules.ContainsKey($newTitle)) {
                $data.titleRules[$newTitle] = [System.Collections.ArrayList]::new()
                $data.titles += $newTitle
                $node = New-Object System.Windows.Forms.TreeNode($newTitle)
                $node.Tag = $newTitle
                $treeView.Nodes.Add($node)
            } else {
                [System.Windows.Forms.MessageBox]::Show("标签已存在", "提示")
            }
        }
    }
    $inputForm.Dispose()
})

$btnExec = New-Object System.Windows.Forms.Button
$btnExec.Text = "执行规则"
$btnExec.Location = New-Object System.Drawing.Point(10, 620)
$btnExec.Size = New-Object System.Drawing.Size(90, 30)
$btnExec.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$btnExec.Add_Click({
    $batPath = Join-Path $scriptDir "clean.bat"
    if (-not (Test-Path $batPath)) {
        [System.Windows.Forms.MessageBox]::Show("未找到 clean.bat", "错误", 'OK', 'Error')
        return
    }
    if ([System.Windows.Forms.MessageBox]::Show("以管理员权限执行 clean.bat ？", "确认", 'YesNo', 'Question') -ne 'Yes') { return }
    try {
        $proc = Start-Process -FilePath $batPath -Verb RunAs -WindowStyle Hidden -Wait -PassThru
        if ($proc.ExitCode -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("执行完成！查看 clean_log.txt", "完成", 'OK', 'Information')
        } else {
            [System.Windows.Forms.MessageBox]::Show("执行失败，退出码 $($proc.ExitCode)", "错误", 'OK', 'Error')
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("无法启动：$_", "错误", 'OK', 'Error')
    }
})

# ---------- 设置按钮（纯符号，无图标） ----------
$configPath = Join-Path $scriptDir "config.ini"
$currentLogSetting = 1
if (Test-Path $configPath) {
    $configContent = Get-Content $configPath -Raw -ErrorAction SilentlyContinue
    if ($configContent -match 'LogNonExistingPaths\s*=\s*(\d)') {
        $currentLogSetting = [int]$matches[1]
    }
}

$btnSettings = New-Object System.Windows.Forms.Button
$btnSettings.Text = ""
$btnSettings.Font = [System.Drawing.Font]::new("Segoe UI", 11)
$btnSettings.Size = New-Object System.Drawing.Size(40, 30)
$btnSettings.Location = New-Object System.Drawing.Point(950, 620)
$btnSettings.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
$btnSettings.FlatStyle = [System.Windows.Forms.FlatStyle]::Standard
$btnSettings.ImageAlign = 'MiddleCenter'

$imagePath = Join-Path $PSScriptRoot "data\gear.png"
if (Test-Path $imagePath) {
    $btnSettings.Image = [System.Drawing.Image]::FromFile($imagePath)
} else {
    $btnSettings.Text = "⚙"  # 备用符号
}

$btnSettings.Add_Click({
    $settingsForm = New-Object System.Windows.Forms.Form
    $settingsForm.Text = "设置"
    $settingsForm.Size = New-Object System.Drawing.Size(400, 250)   # 高度从180增加到250
    $settingsForm.StartPosition = "CenterParent"
    $settingsForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $settingsForm.MaximizeBox = $false
    $settingsForm.MinimizeBox = $false

    # 软件名称和版本信息
    $lblAbout = New-Object System.Windows.Forms.Label
    $lblAbout.Text = "软件名称：标枪           版本：0.18"
    $lblAbout.Location = New-Object System.Drawing.Point(20, 15)
    $lblAbout.Size = New-Object System.Drawing.Size(350, 25)
    $lblAbout.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $lblAbout.ForeColor = [System.Drawing.Color]::DarkBlue

    $checkBox = New-Object System.Windows.Forms.CheckBox
    $checkBox.Text = '记录“路径不存在”日志'
    $checkBox.Location = New-Object System.Drawing.Point(20, 50)
    $checkBox.Size = New-Object System.Drawing.Size(300, 30)
    $checkBox.Checked = ($currentLogSetting -eq 1)

    $labelNote = New-Object System.Windows.Forms.Label
    $labelNote.Text = '关闭此选项后，clean.bat 将不会在日志中写入不存在的路径信息。'
    $labelNote.Location = New-Object System.Drawing.Point(20, 80)
    $labelNote.Size = New-Object System.Drawing.Size(350, 40)
    $labelNote.ForeColor = [System.Drawing.Color]::Gray
    $labelNote.Font = [System.Drawing.Font]::new("Segoe UI", 8)

    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "确定"
    $btnOK.Location = New-Object System.Drawing.Point(180, 140)   # 下移10像素
    $btnOK.Size = New-Object System.Drawing.Size(80, 30)
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "取消"
    $btnCancel.Location = New-Object System.Drawing.Point(280, 140)
    $btnCancel.Size = New-Object System.Drawing.Size(80, 30)
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

    $settingsForm.Controls.AddRange(@($lblAbout, $checkBox, $labelNote, $btnOK, $btnCancel))

    if ($settingsForm.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $newValue = if ($checkBox.Checked) { 1 } else { 0 }
        if (Test-Path $configPath) {
            $content = Get-Content $configPath -Raw
            if ($content -match 'LogNonExistingPaths\s*=\s*\d') {
                $content = $content -replace 'LogNonExistingPaths\s*=\s*\d', "LogNonExistingPaths=$newValue"
            } else {
                $content += "`nLogNonExistingPaths=$newValue"
            }
        } else {
            $content = "[Settings]`nLogNonExistingPaths=$newValue"
        }
        $null = New-Item -Path $configPath -Force -Value $content -ErrorAction SilentlyContinue
        $script:currentLogSetting = $newValue
        [System.Windows.Forms.MessageBox]::Show("设置已保存，下次执行 clean.bat 时生效。", "提示", 'OK', 'Information')
    }
    $settingsForm.Dispose()
})

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = "保存"
$btnSave.Location = New-Object System.Drawing.Point(1000, 620)
$btnSave.Size = New-Object System.Drawing.Size(90, 30)
$btnSave.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
$btnSave.Add_Click({
    SaveCurrentFile
    [System.Windows.Forms.MessageBox]::Show("保存成功！", "完成", 'OK', 'Information')
})

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "关闭"
$btnClose.Location = New-Object System.Drawing.Point(1100, 620)
$btnClose.Size = New-Object System.Drawing.Size(80, 30)
$btnClose.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
$btnClose.Add_Click({ $form.Close() })

$form.Controls.AddRange(@($fileListView, $treeView, $listView, $btnAddTitle, $btnExec, $btnSettings, $btnSave, $btnClose))

if ($fileListView.Items.Count -gt 0) {
    $fileListView.Items[0].Selected = $true
    $fileListView.Select()
}

$form.ShowDialog() | Out-Null
$form.Dispose()