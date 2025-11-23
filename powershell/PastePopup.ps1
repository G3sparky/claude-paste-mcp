# Load WPF Assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName WindowsFormsIntegration
# --- Configuration ---
$TempDir = "$env:TEMP\claude-paste-mcp"
if (-not (Test-Path $TempDir)) { New-Item -ItemType Directory -Force -Path $TempDir | Out-Null }
# --- XAML UI Definition (Phase 3: Tables + Rich Text) ---
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Paste Item for Claude" Height="550" Width="750" WindowStartupLocation="CenterScreen" Topmost="True">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Margin" Value="5"/>
            <Setter Property="Padding" Value="10,5"/>
        </Style>
    </Window.Resources>
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/> <!-- Header -->
            <RowDefinition Height="*"/>    <!-- Content -->
            <RowDefinition Height="Auto"/> <!-- Progress -->
            <RowDefinition Height="Auto"/> <!-- Footer -->
        </Grid.RowDefinitions>
        <!-- Header -->
        <StackPanel Grid.Row="0" Margin="0,0,0,10">
            <TextBlock Text="Paste Items for Claude" FontSize="18" FontWeight="Bold" HorizontalAlignment="Center"/>
            <TextBlock Text="Press Ctrl+V to paste images, tables, or text. Select items to preview or delete." FontSize="12" Foreground="Gray" HorizontalAlignment="Center" Margin="0,5,0,0"/>
        </StackPanel>
        <!-- Main Content: List + Preview -->
        <Grid Grid.Row="1">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="200"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <!-- Left: Item List -->
            <DockPanel Grid.Column="0" Margin="0,0,10,0">
                <TextBlock Text="Items" DockPanel.Dock="Top" FontWeight="SemiBold" Margin="0,0,0,5"/>
                <ListBox Name="lbItems" DisplayMemberPath="name" BorderBrush="#CCCCCC" BorderThickness="1"/>
            </DockPanel>
            <!-- Right: Preview with Tabs -->
            <DockPanel Grid.Column="1">
                <TextBlock Text="Preview" DockPanel.Dock="Top" FontWeight="SemiBold" Margin="0,0,0,5"/>
                <Border BorderBrush="#DDDDDD" BorderThickness="1" Background="#F9F9F9">
                    <Grid>
                        <!-- Image Preview (for images) -->
                        <Image Name="imgPreview" Stretch="Uniform" Margin="5"/>
                        <!-- Tabbed Preview (for tables/text) -->
                        <TabControl Name="tabPreview" Visibility="Collapsed">
                            <TabItem Header="Source">
                                <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto">
                                    <TextBox Name="txtPreview" IsReadOnly="True" TextWrapping="Wrap" Background="Transparent" BorderThickness="0" Margin="5" FontFamily="Consolas" FontSize="11"/>
                                </ScrollViewer>
                            </TabItem>
                            <TabItem Header="Rendered" Name="tabRendered">
                                <WindowsFormsHost Name="wfHost">
                                    <x:Null/>
                                </WindowsFormsHost>
                            </TabItem>
                            <TabItem Header="Moodle Code" Name="tabMoodle">
                                <DockPanel>
                                    <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Margin="5">
                                        <Button Name="btnCopyMoodle" Content="Copy to Clipboard" Padding="10,5"/>
                                        <TextBlock Text="Red text = correct answers" VerticalAlignment="Center" Margin="10,0,0,0" Foreground="Gray" FontStyle="Italic"/>
                                    </StackPanel>
                                    <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto">
                                        <TextBox Name="txtMoodle" IsReadOnly="True" TextWrapping="Wrap" Background="#FFFEF0" BorderThickness="0" Margin="5" FontFamily="Consolas" FontSize="11" AcceptsReturn="True"/>
                                    </ScrollViewer>
                                </DockPanel>
                            </TabItem>
                            <TabItem Header="Moodle Preview" Name="tabMoodlePreview">
                                <WindowsFormsHost Name="wfHostMoodle">
                                    <x:Null/>
                                </WindowsFormsHost>
                            </TabItem>
                        </TabControl>
                    </Grid>
                </Border>
            </DockPanel>
        </Grid>
        <!-- Progress Bar -->
        <Grid Grid.Row="2" Margin="0,5,0,0">
            <ProgressBar Name="progressBar" Height="20" IsIndeterminate="True" Visibility="Collapsed"/>
            <TextBlock Name="lblProgress" Text="Processing..." HorizontalAlignment="Center" VerticalAlignment="Center" Visibility="Collapsed"/>
        </Grid>
        <!-- Footer: Status & Buttons -->
        <Grid Grid.Row="3" Margin="0,10,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>

            <TextBlock Name="lblStatus" Text="Ready." VerticalAlignment="Center" Foreground="Gray"/>
            <StackPanel Grid.Column="1" Orientation="Horizontal">
                <Button Name="btnRename" Content="Rename" IsEnabled="False"/>
                <Button Name="btnDelete" Content="Delete Selected" IsEnabled="False"/>
                <Button Name="btnCancel" Content="Cancel" IsCancel="True"/>
                <Button Name="btnConfirm" Content="Confirm" IsDefault="True" IsEnabled="False"/>
            </StackPanel>
        </Grid>
    </Grid>
</Window>
"@
# --- Load XAML ---
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)
# --- Locate Controls ---
$lbItems = $window.FindName("lbItems")
$imgPreview = $window.FindName("imgPreview")
$tabPreview = $window.FindName("tabPreview")
$txtPreview = $window.FindName("txtPreview")
$tabRendered = $window.FindName("tabRendered")
$tabMoodle = $window.FindName("tabMoodle")
$tabMoodlePreview = $window.FindName("tabMoodlePreview")
$txtMoodle = $window.FindName("txtMoodle")
$btnCopyMoodle = $window.FindName("btnCopyMoodle")
$wfHostMoodle = $window.FindName("wfHostMoodle")
$wfHost = $window.FindName("wfHost")
$progressBar = $window.FindName("progressBar")
$lblProgress = $window.FindName("lblProgress")
$lblStatus = $window.FindName("lblStatus")
$btnRename = $window.FindName("btnRename")
$btnDelete = $window.FindName("btnDelete")
$btnConfirm = $window.FindName("btnConfirm")
$btnCancel = $window.FindName("btnCancel")

# --- Setup WebBrowser for HTML rendering ---
$webBrowser = New-Object System.Windows.Forms.WebBrowser
$webBrowser.ScriptErrorsSuppressed = $true
$wfHost.Child = $webBrowser

# WebBrowser for Moodle preview
$webBrowserMoodle = New-Object System.Windows.Forms.WebBrowser
$webBrowserMoodle.ScriptErrorsSuppressed = $true
$wfHostMoodle.Child = $webBrowserMoodle

# --- Moodle Code Generation ---
function Convert-HtmlToMoodle {
    param([string]$html)

    # First, identify CSS classes that define red color
    # Look at ALL style blocks in the HTML (Excel puts styles in body, we have wrapper styles in head)
    $redClasses = @()
    $styleMatches = [regex]::Matches($html, '<style[^>]*>([\s\S]*?)</style>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    foreach ($styleMatch in $styleMatches) {
        $styleBlock = $styleMatch.Groups[1].Value
        # Look for classes with color:red (various formats)
        $classMatches = [regex]::Matches($styleBlock, '\.(\w+)\s*\{[^}]*color\s*:\s*#?[Rr][Ee]?[Dd]?[^}]*\}|\.(\w+)\s*\{[^}]*color\s*:\s*red[^}]*\}|\.(\w+)\s*\{[^}]*color\s*:\s*#[Ff][Ff]0000[^}]*\}')
        foreach ($m in $classMatches) {
            $className = if ($m.Groups[1].Value) { $m.Groups[1].Value } elseif ($m.Groups[2].Value) { $m.Groups[2].Value } else { $m.Groups[3].Value }
            if ($className -and $className -notin $redClasses) {
                $redClasses += $className
            }
        }
    }

    # Try to extract full table first
    $tableMatch = [regex]::Match($html, '<table[^>]*>([\s\S]*?)</table>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    # If no <table> tag found, check if we have table rows directly (Excel fragment)
    if (-not $tableMatch.Success) {
        # Check if there are <tr> elements - might be a fragment without <table> wrapper
        # Use [\s>] to match actual HTML elements, not CSS selectors like "table {"
        if ($html -match '<tr[\s>]') {
            # Extract just the table rows portion (from first <tr to last </tr>)
            $trMatch = [regex]::Match($html, '(<tr[\s\S]*</tr>)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($trMatch.Success) {
                $tableRows = $trMatch.Value
                $html = "<table>$tableRows</table>"
                $tableMatch = [regex]::Match($html, '<table[^>]*>([\s\S]*?)</table>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            }
        }
    }

    if (-not $tableMatch.Success) {
        return "<!-- No table found in HTML -->"
    }

    $tableContent = $tableMatch.Value

    # Process each row
    $rows = [regex]::Matches($tableContent, '<tr[^>]*>([\s\S]*?)</tr>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $cleanRows = @()

    foreach ($row in $rows) {
        $rowHtml = $row.Value
        $cells = [regex]::Matches($rowHtml, '<td[^>]*>([\s\S]*?)</td>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        $cleanCells = @()

        foreach ($cell in $cells) {
            $cellHtml = $cell.Value
            $cellContent = $cell.Groups[1].Value

            # Check if this cell has a red class or inline red color
            $isRed = $false

            # Check for red CSS class
            foreach ($redClass in $redClasses) {
                if ($cellHtml -match "class\s*=\s*[`"']?[^`"']*$redClass") {
                    $isRed = $true
                    break
                }
            }

            # Also check for inline style with color:red (various formats)
            if (-not $isRed) {
                if ($cellHtml -match 'style\s*=\s*[`"''][^`"'']*color\s*:\s*(red|#[Ff][Ff]0000|#[Ff]00)[^`"'']*[`"'']') {
                    $isRed = $true
                }
                # Check content for <font color=red> or <span style="color:red">
                if ($cellContent -match '<font[^>]*color\s*=\s*[`"'']?(red|#[Ff][Ff]0000|#[Ff]00)[`"'']?[^>]*>|<span[^>]*color\s*:\s*(red|#[Ff][Ff]0000|#[Ff]00)') {
                    $isRed = $true
                }
            }

            # Clean the cell content - remove tags, get text only
            $textContent = $cellContent -replace '<[^>]+>', ''
            $textContent = $textContent -replace '&nbsp;', ''
            $textContent = $textContent.Trim()

            # Build clean cell
            if ($isRed -and $textContent) {
                # This is an answer cell - convert to Moodle Cloze
                if ($textContent -match '^[\d.]+$') {
                    $moodleField = "{:NM:=$textContent}"
                } else {
                    $moodleField = "{:MC:~=`"$textContent`"}"
                }
                $cleanCells += "<td style=`"text-align: center;`">$moodleField</td>"
            } elseif ($textContent) {
                $cleanCells += "<td style=`"text-align: center;`">$textContent</td>"
            } else {
                $cleanCells += "<td style=`"text-align: center;`">&nbsp;</td>"
            }
        }

        # Check for header row (bgcolor or background-color with gray)
        $isHeader = $rowHtml -match 'bgcolor\s*=\s*["'']?#?[dD]3[dD]3[dD]3|background-color\s*:\s*#?808080|bgcolor\s*=\s*["'']?#?808080'

        if ($isHeader) {
            $cleanRows += "<tr style=`"background-color: #d3d3d3;`">" + ($cleanCells -join "") + "</tr>"
        } else {
            $cleanRows += "<tr>" + ($cleanCells -join "") + "</tr>"
        }
    }

    # Build clean table
    $cleanTable = @"
<table border="2" style="border-collapse: collapse; width: 100%;">
<tbody>
$($cleanRows -join "`n")
</tbody>
</table>
"@

    return $cleanTable
}
# --- State ---
$global:items = New-Object System.Collections.ArrayList
$global:imageCount = 0
$global:tableCount = 0
$global:textCount = 0
# --- Helper Functions ---
function Show-Progress {
    param([string]$message = "Processing...")
    $lblProgress.Text = $message
    $progressBar.Visibility = "Visible"
    $lblProgress.Visibility = "Visible"
    $window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)
}

function Hide-Progress {
    $progressBar.Visibility = "Collapsed"
    $lblProgress.Visibility = "Collapsed"
}

function Update-UIState {
    $hasItems = $global:items.Count -gt 0
    $btnConfirm.IsEnabled = $hasItems

    $hasSelection = $lbItems.SelectedItem -ne $null
    $btnDelete.IsEnabled = $hasSelection
    $btnRename.IsEnabled = $hasSelection
    if (-not $hasSelection) {
        $imgPreview.Source = $null
        $imgPreview.Visibility = "Visible"
        $tabPreview.Visibility = "Collapsed"
        $txtPreview.Text = ""
        $webBrowser.DocumentText = ""
    }
}
# --- Event Handlers ---
$window.Add_KeyDown({
    param($sender, $e)
    # Handle Ctrl+V
    if ($e.Key -eq 'V' -and ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control)) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $captured = $false

        # Priority 1: Check for HTML Format (Excel tables, web content)
        $htmlData = $null

        if ([System.Windows.Clipboard]::ContainsData("HTML Format")) {
            $htmlDataRaw = [System.Windows.Clipboard]::GetData("HTML Format")

            # Convert to string if needed (might be MemoryStream or byte array)
            if ($htmlDataRaw -is [System.IO.MemoryStream]) {
                $htmlDataRaw.Position = 0
                $reader = New-Object System.IO.StreamReader($htmlDataRaw, [System.Text.Encoding]::UTF8)
                $htmlData = $reader.ReadToEnd()
                $reader.Close()
            } elseif ($htmlDataRaw -is [byte[]]) {
                $htmlData = [System.Text.Encoding]::UTF8.GetString($htmlDataRaw)
            } elseif ($htmlDataRaw -is [string]) {
                $htmlData = $htmlDataRaw
            } elseif ($htmlDataRaw) {
                $htmlData = $htmlDataRaw.ToString()
            }
        }

        if ($htmlData -and $htmlData.Length -gt 0 -and -not $captured) {
            try {
                Show-Progress "Processing table data..."

                $global:tableCount++
                $name = "Table $($global:tableCount)"
                $filename = "table-$timestamp-$($global:tableCount).html"
                $path = Join-Path $TempDir $filename

                # Extract the actual HTML content from the clipboard HTML format
                # The format has headers like "Version:...", "StartFragment:...", etc.
                $htmlContent = $htmlData

                # Try to extract just the fragment between StartFragment and EndFragment
                if ($htmlData -match '<!--StartFragment-->([\s\S]*)<!--EndFragment-->') {
                    $htmlContent = $matches[1]
                }

                # If fragment doesn't include <table> tag but has <tr>, wrap it
                # Use regex to check for actual <table> element, not CSS selector like "table {"
                if ($htmlContent -notmatch '<table[\s>]' -and $htmlContent -match '<tr[\s>]') {
                    # Extract just the table rows (may have style block before them)
                    $trMatch = [regex]::Match($htmlContent, '(<tr[\s\S]*</tr>)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                    if ($trMatch.Success) {
                        $tableRows = $trMatch.Value
                        # Preserve any style block for rendering
                        $styleMatch = [regex]::Match($htmlContent, '(<style[^>]*>[\s\S]*?</style>)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                        $styleBlock = if ($styleMatch.Success) { $styleMatch.Value } else { "" }
                        $htmlContent = "$styleBlock<table border=`"2`">$tableRows</table>"
                    } else {
                        $htmlContent = "<table border=`"2`">$htmlContent</table>"
                    }
                }

                # Wrap in proper HTML document for rendering
                $fullHtml = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; font-size: 12px; margin: 10px; }
        table { border-collapse: collapse; width: 100%; }
        td, th { border: 1px solid #ccc; padding: 6px 8px; }
        th { background: #f0f0f0; font-weight: bold; }
        tr:nth-child(even) { background: #f9f9f9; }
    </style>
</head>
<body>
$htmlContent
</body>
</html>
"@

                # Save HTML file (full version for rendering)
                [System.IO.File]::WriteAllText($path, $fullHtml, [System.Text.Encoding]::UTF8)

                # Create preview (first 200 chars of plain text)
                $plainText = [System.Windows.Clipboard]::GetText()
                $preview = if ($plainText.Length -gt 200) { $plainText.Substring(0, 200) + "..." } else { $plainText }

                $newItem = [PSCustomObject]@{
                    type = "table"
                    name = $name
                    path = $path
                    contentPreview = $preview
                    rawHtml = $htmlContent
                }

                [void]$global:items.Add($newItem)
                [void]$lbItems.Items.Add($newItem)
                $lbItems.SelectedItem = $newItem

                Hide-Progress
                $lblStatus.Text = "Captured $name (HTML table)"
                $lblStatus.Foreground = "Green"
                $captured = $true
            }
            catch {
                Hide-Progress
                $lblStatus.Text = "Error pasting HTML: $_"
                $lblStatus.Foreground = "Red"
            }
        }

        # Priority 2: Check for Image
        if ([System.Windows.Clipboard]::ContainsImage() -and -not $captured) {
            try {
                Show-Progress "Processing image..."

                $image = [System.Windows.Clipboard]::GetImage()

                $global:imageCount++
                $name = "Image $($global:imageCount)"
                $filename = "image-$timestamp-$($global:imageCount).png"
                $path = Join-Path $TempDir $filename

                # Save PNG
                $encoder = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
                $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($image))
                $fs = [System.IO.File]::OpenWrite($path)
                $encoder.Save($fs)
                $fs.Close()

                $newItem = [PSCustomObject]@{
                    type = "image"
                    name = $name
                    path = $path
                    contentPreview = ""
                }

                [void]$global:items.Add($newItem)
                [void]$lbItems.Items.Add($newItem)
                $lbItems.SelectedItem = $newItem

                Hide-Progress
                $lblStatus.Text = "Captured $name"
                $lblStatus.Foreground = "Green"
                $captured = $true
            }
            catch {
                Hide-Progress
                $lblStatus.Text = "Error pasting image: $_"
                $lblStatus.Foreground = "Red"
            }
        }

        # Priority 3: Check for Rich Text Format
        $rtfData = [System.Windows.Clipboard]::GetData("Rich Text Format")
        if ($rtfData -and -not $captured) {
            try {
                Show-Progress "Processing rich text..."

                $global:textCount++
                $name = "Rich Text $($global:textCount)"
                $filename = "richtext-$timestamp-$($global:textCount).rtf"
                $path = Join-Path $TempDir $filename

                # Save RTF file
                [System.IO.File]::WriteAllText($path, $rtfData, [System.Text.Encoding]::UTF8)

                # Create preview from plain text
                $plainText = [System.Windows.Clipboard]::GetText()
                $preview = if ($plainText.Length -gt 200) { $plainText.Substring(0, 200) + "..." } else { $plainText }

                $newItem = [PSCustomObject]@{
                    type = "richtext"
                    name = $name
                    path = $path
                    contentPreview = $preview
                }

                [void]$global:items.Add($newItem)
                [void]$lbItems.Items.Add($newItem)
                $lbItems.SelectedItem = $newItem

                Hide-Progress
                $lblStatus.Text = "Captured $name"
                $lblStatus.Foreground = "Green"
                $captured = $true
            }
            catch {
                Hide-Progress
                $lblStatus.Text = "Error pasting RTF: $_"
                $lblStatus.Foreground = "Red"
            }
        }

        # Priority 4: Plain text fallback
        if ([System.Windows.Clipboard]::ContainsText() -and -not $captured) {
            try {
                Show-Progress "Processing text..."

                $plainText = [System.Windows.Clipboard]::GetText()
                if ($plainText -and $plainText.Trim().Length -gt 0) {
                    $global:textCount++
                    $name = "Text $($global:textCount)"
                    $filename = "text-$timestamp-$($global:textCount).txt"
                    $path = Join-Path $TempDir $filename

                    # Save text file
                    [System.IO.File]::WriteAllText($path, $plainText, [System.Text.Encoding]::UTF8)

                    $preview = if ($plainText.Length -gt 200) { $plainText.Substring(0, 200) + "..." } else { $plainText }

                    $newItem = [PSCustomObject]@{
                        type = "text"
                        name = $name
                        path = $path
                        contentPreview = $preview
                    }

                    [void]$global:items.Add($newItem)
                    [void]$lbItems.Items.Add($newItem)
                    $lbItems.SelectedItem = $newItem

                    Hide-Progress
                    $lblStatus.Text = "Captured $name"
                    $lblStatus.Foreground = "Green"
                    $captured = $true
                } else {
                    Hide-Progress
                }
            }
            catch {
                Hide-Progress
                $lblStatus.Text = "Error pasting text: $_"
                $lblStatus.Foreground = "Red"
            }
        }

        if (-not $captured) {
            $lblStatus.Text = "Clipboard is empty or contains unsupported format."
            $lblStatus.Foreground = "Red"
        }

        Update-UIState
    }
})
$lbItems.Add_SelectionChanged({
    $sel = $lbItems.SelectedItem
    if ($sel) {
        if ($sel.type -eq "image") {
            # Show image preview
            $imgPreview.Visibility = "Visible"
            $tabPreview.Visibility = "Collapsed"
            try {
                $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
                $bmp.BeginInit()
                $bmp.CacheOption = "OnLoad"
                $bmp.UriSource = $sel.path
                $bmp.EndInit()
                $imgPreview.Source = $bmp
            } catch {
                $imgPreview.Source = $null
            }
        } else {
            # Show tabbed preview for table, richtext, or text
            $imgPreview.Visibility = "Collapsed"
            $tabPreview.Visibility = "Visible"

            try {
                $content = [System.IO.File]::ReadAllText($sel.path, [System.Text.Encoding]::UTF8)
                # Limit source preview to 10000 chars for performance
                $sourceContent = $content
                if ($sourceContent.Length -gt 10000) {
                    $sourceContent = $sourceContent.Substring(0, 10000) + "`n`n... (truncated)"
                }
                $txtPreview.Text = $sourceContent

                # Show/hide Rendered and Moodle tabs based on content type
                if ($sel.type -eq "table") {
                    $tabRendered.Visibility = "Visible"
                    $tabMoodle.Visibility = "Visible"
                    $tabMoodlePreview.Visibility = "Visible"
                    # Render HTML in WebBrowser
                    $webBrowser.DocumentText = $content

                    # Generate Moodle code from HTML
                    # Use full content which has the table wrapper, plus rawHtml for style detection
                    $moodleCode = Convert-HtmlToMoodle -html $content
                    $txtMoodle.Text = $moodleCode

                    # Show Moodle preview (wrap in basic HTML)
                    $moodlePreviewHtml = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; font-size: 12px; margin: 10px; }
        table { border-collapse: collapse; width: 100%; }
        td, th { border: 1px solid #333; padding: 6px 8px; }
        tr[style*="background-color"] td { font-weight: bold; }
    </style>
</head>
<body>
$moodleCode
</body>
</html>
"@
                    $webBrowserMoodle.DocumentText = $moodlePreviewHtml
                } else {
                    # For text/richtext, hide Rendered and Moodle tabs
                    $tabRendered.Visibility = "Collapsed"
                    $tabMoodle.Visibility = "Collapsed"
                    $tabMoodlePreview.Visibility = "Collapsed"
                    $tabPreview.SelectedIndex = 0
                }
            } catch {
                $txtPreview.Text = "Error loading preview: $_"
                $tabRendered.Visibility = "Collapsed"
                $tabMoodle.Visibility = "Collapsed"
                $tabMoodlePreview.Visibility = "Collapsed"
            }
        }
    }
    Update-UIState
})
$btnRename.Add_Click({
    $sel = $lbItems.SelectedItem
    if ($sel) {
        # Create a simple input dialog
        $inputForm = New-Object System.Windows.Forms.Form
        $inputForm.Text = "Rename Item"
        $inputForm.Size = New-Object System.Drawing.Size(350, 150)
        $inputForm.StartPosition = "CenterParent"
        $inputForm.FormBorderStyle = "FixedDialog"
        $inputForm.MaximizeBox = $false
        $inputForm.MinimizeBox = $false

        $label = New-Object System.Windows.Forms.Label
        $label.Text = "Enter new name:"
        $label.Location = New-Object System.Drawing.Point(10, 15)
        $label.AutoSize = $true
        $inputForm.Controls.Add($label)

        $textBox = New-Object System.Windows.Forms.TextBox
        $textBox.Text = $sel.name
        $textBox.Location = New-Object System.Drawing.Point(10, 40)
        $textBox.Size = New-Object System.Drawing.Size(310, 25)
        $inputForm.Controls.Add($textBox)

        $okBtn = New-Object System.Windows.Forms.Button
        $okBtn.Text = "OK"
        $okBtn.Location = New-Object System.Drawing.Point(160, 75)
        $okBtn.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $inputForm.AcceptButton = $okBtn
        $inputForm.Controls.Add($okBtn)

        $cancelBtn = New-Object System.Windows.Forms.Button
        $cancelBtn.Text = "Cancel"
        $cancelBtn.Location = New-Object System.Drawing.Point(245, 75)
        $cancelBtn.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $inputForm.CancelButton = $cancelBtn
        $inputForm.Controls.Add($cancelBtn)

        $textBox.SelectAll()

        $result = $inputForm.ShowDialog()
        if ($result -eq [System.Windows.Forms.DialogResult]::OK -and $textBox.Text.Trim()) {
            $oldName = $sel.name
            $sel.name = $textBox.Text.Trim()

            # Refresh the listbox display
            $idx = $lbItems.Items.IndexOf($sel)
            $lbItems.Items.RemoveAt($idx)
            $lbItems.Items.Insert($idx, $sel)
            $lbItems.SelectedIndex = $idx

            $lblStatus.Text = "Renamed '$oldName' to '$($sel.name)'"
            $lblStatus.Foreground = "Green"
        }
    }
})
$btnDelete.Add_Click({
    $sel = $lbItems.SelectedItem
    if ($sel) {
        $global:items.Remove($sel)
        $lbItems.Items.Remove($sel)
        $lblStatus.Text = "Deleted $($sel.name)"
        Update-UIState
    }
})
$btnConfirm.Add_Click({
    if ($global:items.Count -gt 0) {
        # Output JSON array as the LAST line - use [Console] for reliable stdio
        $json = $global:items | ConvertTo-Json -Compress -Depth 2
        [Console]::Out.WriteLine($json)
        [Console]::Out.Flush()
        $window.Close()
    }
})
$btnCancel.Add_Click({
    $window.Close()
})
$btnCopyMoodle.Add_Click({
    if ($txtMoodle.Text) {
        [System.Windows.Clipboard]::SetText($txtMoodle.Text)
        $lblStatus.Text = "Moodle code copied to clipboard!"
        $lblStatus.Foreground = "Green"
    }
})
# --- Show Window ---
$window.ShowDialog() | Out-Null
