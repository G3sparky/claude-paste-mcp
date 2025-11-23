# Load WPF Assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Drawing
# --- Configuration ---
$TempDir = "$env:TEMP\claude-paste-mcp"
if (-not (Test-Path $TempDir)) { New-Item -ItemType Directory -Force -Path $TempDir | Out-Null }
# --- XAML UI Definition (Phase 2: Master-Detail) ---
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Paste Item for Claude" Height="500" Width="700" WindowStartupLocation="CenterScreen" Topmost="True">
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
            <RowDefinition Height="Auto"/> <!-- Footer -->
        </Grid.RowDefinitions>
        <!-- Header -->
        <StackPanel Grid.Row="0" Margin="0,0,0,10">
            <TextBlock Text="Paste Items for Claude" FontSize="18" FontWeight="Bold" HorizontalAlignment="Center"/>
            <TextBlock Text="Press Ctrl+V to paste images. Select items to preview or delete." FontSize="12" Foreground="Gray" HorizontalAlignment="Center" Margin="0,5,0,0"/>
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
            <!-- Right: Preview -->
            <DockPanel Grid.Column="1">
                <TextBlock Text="Preview" DockPanel.Dock="Top" FontWeight="SemiBold" Margin="0,0,0,5"/>
                <Border BorderBrush="#DDDDDD" BorderThickness="1" Background="#F9F9F9">
                    <Image Name="imgPreview" Stretch="Uniform" Margin="5"/>
                </Border>
            </DockPanel>
        </Grid>
        <!-- Footer: Status & Buttons -->
        <Grid Grid.Row="2" Margin="0,10,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            
            <TextBlock Name="lblStatus" Text="Ready." VerticalAlignment="Center" Foreground="Gray"/>
            <StackPanel Grid.Column="1" Orientation="Horizontal">
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
$lblStatus = $window.FindName("lblStatus")
$btnDelete = $window.FindName("btnDelete")
$btnConfirm = $window.FindName("btnConfirm")
$btnCancel = $window.FindName("btnCancel")
# --- State ---
$global:items = New-Object System.Collections.ArrayList
$global:imageCount = 0
# --- Helper Functions ---
function Update-UIState {
    $hasItems = $global:items.Count -gt 0
    $btnConfirm.IsEnabled = $hasItems
    
    $hasSelection = $lbItems.SelectedItem -ne $null
    $btnDelete.IsEnabled = $hasSelection
    if (-not $hasSelection) {
        $imgPreview.Source = $null
    }
}
# --- Event Handlers ---
$window.Add_KeyDown({
    param($sender, $e)
    # Handle Ctrl+V
    if ($e.Key -eq 'V' -and ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control)) {
        
        # PHASE 3 TODO: Check for Text or HTML (Excel) here
        # if ([System.Windows.Clipboard]::ContainsText()) { ... }
        if ([System.Windows.Clipboard]::ContainsImage()) {
            try {
                $image = [System.Windows.Clipboard]::GetImage()
                
                # Generate filename
                $global:imageCount++
                $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
                $name = "Image $($global:imageCount)"
                $filename = "image-$timestamp-$($global:imageCount).png"
                $path = Join-Path $TempDir $filename
                
                # Save PNG
                $encoder = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
                $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($image))
                $fs = [System.IO.File]::OpenWrite($path)
                $encoder.Save($fs)
                $fs.Close()
                # Create Item Object
                $newItem = [PSCustomObject]@{
                    type = "image"
                    name = $name
                    path = $path
                    contentPreview = "" # Reserved for text
                }
                # Add to list
                [void]$global:items.Add($newItem)
                [void]$lbItems.Items.Add($newItem)
                
                # Select new item
                $lbItems.SelectedItem = $newItem
                
                $lblStatus.Text = "Captured $name"
                $lblStatus.Foreground = "Green"
            }
            catch {
                $lblStatus.Text = "Error pasting image."
                $lblStatus.Foreground = "Red"
            }
        }
        else {
            $lblStatus.Text = "Clipboard does not contain an image."
            $lblStatus.Foreground = "Red"
        }
        Update-UIState
    }
})
$lbItems.Add_SelectionChanged({
    $sel = $lbItems.SelectedItem
    if ($sel -and $sel.type -eq "image") {
        try {
            # Load image for preview (CacheOption=OnLoad to avoid file locking)
            $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
            $bmp.BeginInit()
            $bmp.CacheOption = "OnLoad"
            $bmp.UriSource = $sel.path
            $bmp.EndInit()
            $imgPreview.Source = $bmp
        } catch {
            $imgPreview.Source = $null
        }
    }
    Update-UIState
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
        # Output JSON array as the LAST line
        $json = $global:items | ConvertTo-Json -Compress -Depth 2
        Write-Output $json
        $window.Close()
    }
})
$btnCancel.Add_Click({
    $window.Close()
})
# --- Show Window ---
$window.ShowDialog() | Out-Null
