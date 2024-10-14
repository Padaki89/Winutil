function Toggle-CategoryVisibility {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Category,
        [Parameter(Mandatory=$true)]
        [System.Windows.Controls.ItemsControl]$ItemsControl,
        [Parameter(Mandatory=$true)]
        [bool]$isChecked
    )

    $appsInCategory = $ItemsControl.Items | Where-Object {
        if ($null -ne $_.Tag) {
            $sync.configs.applicationsHashtable.$($_.Tag).Category -eq $Category
        }
    }
    
    foreach ($appEntry in $appsInCategory) {
        $appEntry.Visibility = if ($isChecked) {
            [Windows.Visibility]::Visible
        } else {
            [Windows.Visibility]::Collapsed
        }
    }
}

function Search-AppsByNameOrDescription {
    param(
        [Parameter(Mandatory=$false)]
        [string]$SearchString = "",
        [Parameter(Mandatory=$false)]
        [System.Windows.Controls.ItemsControl]$ItemsControl = $sync.ItemsControl
    )
    $Apps = $ItemsControl.Items

    if ([string]::IsNullOrWhiteSpace($SearchString)) {
        $Apps | ForEach-Object {
            if ($null -ne $_.Tag) {
                $_.Visibility = 'Collapsed'
            } else {
                $_.Visibility = 'Visible'
            }
        }   
    } else {
        $Apps | ForEach-Object {
            if ($null -ne $_.Tag) {
                if ($sync.configs.applicationsHashtable.$($_.Tag).Content -like "*$SearchString*") {
                    $_.Visibility = 'Visible'
                } else {
                    $_.Visibility = 'Collapsed'
                }
            }
        }
    }
}
function Show-OnlyCheckedApps {
    param (
        [Parameter(Mandatory=$false)]
        [String[]]$appKeys,
        [Parameter(Mandatory=$true)]
        [System.Windows.Controls.ItemsControl]$ItemsControl
    )
    # If no apps are selected, do not allow switching to show only selected
    if (($false -eq $sync.ShowOnlySelected) -and ($appKeys.Count -eq 0)) {
        return
    }
        $sync.ShowOnlySelected = -not $sync.ShowOnlySelected
        if ($sync.ShowOnlySelected) {
        $sync.Buttons.ShowSelectedAppsButton.Content = "Show All"
        foreach ($item in $ItemsControl.Items) {
            if ($appKeys -contains $item.Tag) {
                $item.Visibility = [Windows.Visibility]::Visible
            } else {
                $item.Visibility = [Windows.Visibility]::Collapsed
            }
        }
    } else {
        $sync.Buttons.ShowSelectedAppsButton.Content = "Show Selected"
        $ItemsControl.Items | ForEach-Object { $_.Visibility = [Windows.Visibility]::Visible }
    }
}
function Invoke-WPFUIApps {
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [PSCustomObject[]]$Apps,
        [Parameter(Mandatory, Position = 1)]
        [string]$TargetGridName
    )

    function Initialize-StackPanel {
        $targetGrid = $window.FindName($TargetGridName)
        $borderStyle = $window.FindResource("BorderStyle")

        $null = $targetGrid.Children.Clear()

        $mainBorder = New-Object Windows.Controls.Border
        $mainBorder.VerticalAlignment = "Stretch"
        $mainBorder.Style = $borderStyle

        $null = $targetGrid.Children.Add($mainBorder)
        return $targetGrid
    }

    function Initialize-Header {
        param($TargetGrid)
        $mainBorder = $TargetGrid.Children[0]
        $dockPanel = New-Object Windows.Controls.DockPanel
        $mainBorder.Child = $dockPanel

        function New-WPFButton {
            param (
                [string]$Name,
                [string]$Content
            )
            $button = New-Object Windows.Controls.Button
            $button.Name = $Name
            $button.Content = $Content
            $button.Margin = New-Object Windows.Thickness(2)
            $button.HorizontalAlignment = "Stretch"
            return $button
        }

        $wrapPanelTop = New-Object Windows.Controls.WrapPanel
        $wrapPanelTop.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, "MainBackgroundColor")
        $wrapPanelTop.HorizontalAlignment = "Left"
        $wrapPanelTop.VerticalAlignment = "Top"
        $wrapPanelTop.Orientation = "Horizontal"
        $wrapPanelTop.Margin = $window.FindResource("TabContentMargin")

        $buttonConfigs = @(
            @{Name="WPFInstall"; Content="Install/Upgrade Selected"},
            @{Name="WPFInstallUpgrade"; Content="Upgrade All"},
            @{Name="WPFUninstall"; Content="Uninstall Selected"}
        )

        foreach ($config in $buttonConfigs) {
            $button = New-WPFButton -Name $config.Name -Content $config.Content
            $null = $wrapPanelTop.Children.Add($button)
            $sync[$config.Name] = $button
        }

        $selectedLabel = New-Object Windows.Controls.Label
        $selectedLabel.Name = "WPFSelectedLabel"
        $selectedLabel.Content = "Selected Apps: 0"
        $selectedLabel.SetResourceReference([Windows.Controls.Control]::FontSizeProperty, "FontSizeHeading")
        $selectedLabel.SetResourceReference([Windows.Controls.Control]::MarginProperty, "TabContentMargin")
        $selectedLabel.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, "MainForegroundColor")
        $selectedLabel.HorizontalAlignment = "Center"
        $selectedLabel.VerticalAlignment = "Center"

        $null = $wrapPanelTop.Children.Add($selectedLabel)
        $sync.$($selectedLabel.Name) = $selectedLabel

        $showSelectedAppsButton = New-Object Windows.Controls.Button
        $showSelectedAppsButton.Name = "ShowSelectedAppsButton"
        $showSelectedAppsButton.Content = "Show Selected"
        $showSelectedAppsButton.Add_Click({
            Show-OnlyCheckedApps -appKeys $sync.SelectedApps -ItemsControl $sync.ItemsControl
        })
        $sync.Buttons.ShowSelectedAppsButton = $showSelectedAppsButton
        $null = $wrapPanelTop.Children.Add($showSelectedAppsButton)

        [Windows.Controls.DockPanel]::SetDock($wrapPanelTop, [Windows.Controls.Dock]::Top)
        $null = $dockPanel.Children.Add($wrapPanelTop)
        return $dockPanel
    }

    function Initialize-AppArea {
        param($TargetGrid)
        $scrollViewer = New-Object Windows.Controls.ScrollViewer
        $scrollViewer.VerticalScrollBarVisibility = 'Auto'
        $scrollViewer.HorizontalAlignment = 'Stretch'
        $scrollViewer.VerticalAlignment = 'Stretch'
        $scrollViewer.CanContentScroll = $true

        $itemsControl = New-Object Windows.Controls.ItemsControl
        $itemsControl.HorizontalAlignment = 'Stretch'
        $itemsControl.VerticalAlignment = 'Stretch'

        $itemsPanelTemplate = New-Object Windows.Controls.ItemsPanelTemplate
        $factory = New-Object Windows.FrameworkElementFactory ([Windows.Controls.VirtualizingStackPanel])
        $itemsPanelTemplate.VisualTree = $factory
        $itemsControl.ItemsPanel = $itemsPanelTemplate

        $itemsControl.SetValue([Windows.Controls.VirtualizingStackPanel]::IsVirtualizingProperty, $true)
        $itemsControl.SetValue([Windows.Controls.VirtualizingStackPanel]::VirtualizationModeProperty, [Windows.Controls.VirtualizationMode]::Recycling)

        $scrollViewer.Content = $itemsControl

        [Windows.Controls.DockPanel]::SetDock($scrollViewer, [Windows.Controls.Dock]::Bottom)
        $null = $TargetGrid.Children.Add($scrollViewer)
        return $itemsControl
    }

    function Add-Category {
        param(
            [string]$Category,
            $ItemsControl
        )
        
        $toggleButton = New-Object Windows.Controls.Primitives.ToggleButton
        $toggleButton.Content = "$Category"
        $toggleButton.Cursor = [System.Windows.Input.Cursors]::Hand
        $toggleButton.Style = $window.FindResource("CategoryToggleButtonStyle")
    

        $toggleButton.Add_Click({
            # Clear the search bar when a category is clicked
            $sync.SearchBar.Text = ""
            Toggle-CategoryVisibility -Category $this.Content -ItemsControl $this.Parent -isChecked $this.IsChecked
        })
        $null = $ItemsControl.Items.Add($toggleButton)
    }

    function New-CategoryAppList {
        param(
            $TargetGrid,
            $Apps
        )
        $loadingLabel = New-Object Windows.Controls.Label
        $loadingLabel.Content = "Loading, please wait..."
        $loadingLabel.HorizontalAlignment = "Center"
        $loadingLabel.VerticalAlignment = "Center"
        $loadingLabel.SetResourceReference([Windows.Controls.Control]::FontSizeProperty, "FontSizeHeading")
        $loadingLabel.FontWeight = [Windows.FontWeights]::Bold
        $loadingLabel.Foreground = [Windows.Media.Brushes]::Gray
        $sync.LoadingLabel = $loadingLabel

        $itemsControl.Items.Clear()
        $null = $itemsControl.Items.Add($sync.LoadingLabel)

        $itemsControl.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{
            $itemsControl.Items.Clear()

            $categories = $Apps.Values | Select-Object -ExpandProperty category -Unique | Sort-Object
            foreach ($category in $categories) {
                Add-Category -Category $category -ItemsControl $itemsControl
                $Apps.Keys | Where-Object { $Apps.$_.Category -eq $category } | Sort-Object | ForEach-Object {
                    New-AppEntry -ItemsControl $itemsControl -AppKey $_ -Hidden $true
                }
            }
        })
    }

    function New-AppEntry {
        param(
            $ItemsControl,
            $AppKey,
            [bool]$Hidden
        )
        $App = $Apps.$AppKey
        # Create the outer Border for the application type
        $border = New-Object Windows.Controls.Border
        $border.BorderBrush = [Windows.Media.Brushes]::Gray
        $border.BorderThickness = 1
        $border.CornerRadius = 5
        $border.Padding = New-Object Windows.Thickness(10)
        $border.HorizontalAlignment = "Stretch"
        $border.VerticalAlignment = "Top"
        $border.Margin = New-Object Windows.Thickness(0, 10, 0, 0)
        $border.Cursor = [System.Windows.Input.Cursors]::Hand
        $border.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, "AppInstallUnselectedColor")
        $border.Tag = $Appkey
        $border.ToolTip = $App.description
        $border.Visibility = if ($Hidden) {[Windows.Visibility]::Collapsed} else {[Windows.Visibility]::Visible}
        $border.Add_MouseUp({
            $childCheckbox = ($this.Child.Children | Where-Object {$_.Template.TargetType -eq [System.Windows.Controls.Checkbox]})[0]
            $childCheckBox.isChecked = -not $childCheckbox.IsChecked
        })
        # Create a DockPanel inside the Border
        $dockPanel = New-Object Windows.Controls.DockPanel
        $dockPanel.LastChildFill = $true
        $border.Child = $dockPanel

        # Create the CheckBox, vertically centered
        $checkBox = New-Object Windows.Controls.CheckBox
        $checkBox.Name = $AppKey
        $checkBox.Background = "Transparent"
        $checkBox.HorizontalAlignment = "Left"
        $checkBox.VerticalAlignment = "Center"
        $checkBox.Margin = New-Object Windows.Thickness(5, 0, 10, 0)
        $checkBox.SetResourceReference([Windows.Controls.Control]::StyleProperty, "CollapsedCheckBoxStyle") 
        $checkbox.Add_Checked({
            Invoke-WPFSelectedLabelUpdate -type "Add" -checkbox $this
            $borderElement = $this.Parent.Parent
            $borderElement.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, "AppInstallSelectedColor")
        })

        $checkbox.Add_Unchecked({
            Invoke-WPFSelectedLabelUpdate -type "Remove" -checkbox $this
            $borderElement = $this.Parent.Parent
            $borderElement.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, "AppInstallUnselectedColor")
        })
        $sync.$($checkBox.Name) = $checkBox
        # Create a StackPanel for the image and name
        $imageAndNamePanel = New-Object Windows.Controls.StackPanel
        $imageAndNamePanel.Orientation = "Horizontal"
        $imageAndNamePanel.VerticalAlignment = "Center"

        # Create the Image and set a placeholder
        $image = New-Object Windows.Controls.Image
        # $image.Name = "wpfapplogo" + $App.Name
        $image.Width = 40
        $image.Height = 40
        $image.Margin = New-Object Windows.Thickness(0, 0, 10, 0)
        $image.Source = $noimage  # Ensure $noimage is defined in your script

        # Clip the image corners
        $image.Clip = New-Object Windows.Media.RectangleGeometry
        $image.Clip.Rect = New-Object Windows.Rect(0, 0, $image.Width, $image.Height)
        $image.Clip.RadiusX = 5
        $image.Clip.RadiusY = 5

        $imageAndNamePanel.Children.Add($image) | Out-Null

        # Create the TextBlock for the application name
        $appName = New-Object Windows.Controls.TextBlock
        $appName.Text = $App.Content
        $appName.FontSize = 16
        $appName.FontWeight = [Windows.FontWeights]::Bold
        $appName.VerticalAlignment = "Center"
        $appName.Margin = New-Object Windows.Thickness(5, 0, 0, 0)
        $appName.Background = "Transparent"
        $imageAndNamePanel.Children.Add($appName) | Out-Null

        # Add the image and name panel to the Checkbox
        $checkBox.Content = $imageAndNamePanel

        # Add the checkbox to the DockPanel
        [Windows.Controls.DockPanel]::SetDock($checkBox, [Windows.Controls.Dock]::Left)
        $dockPanel.Children.Add($checkBox) | Out-Null

        # Create the StackPanel for the buttons and dock it to the right
        $buttonPanel = New-Object Windows.Controls.StackPanel
        $buttonPanel.Orientation = "Horizontal"
        $buttonPanel.HorizontalAlignment = "Right"
        $buttonPanel.VerticalAlignment = "Center"
        $buttonPanel.Margin = New-Object Windows.Thickness(10, 0, 0, 0)
        [Windows.Controls.DockPanel]::SetDock($buttonPanel, [Windows.Controls.Dock]::Right)

        # Create the "Install" button
        $installButton = New-Object Windows.Controls.Button
        $installButton.Width = 45
        $installButton.Height = 35
        $installButton.Margin = New-Object Windows.Thickness(0, 0, 10, 0)

        $installIcon = New-Object Windows.Controls.TextBlock
        $installIcon.Text = [char]0xE118  # Install Icon
        $installIcon.FontFamily = "Segoe MDL2 Assets"
        $installIcon.FontSize = 20
        $installIcon.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, "MainForegroundColor")
        $installIcon.Background = "Transparent"
        $installIcon.HorizontalAlignment = "Center"
        $installIcon.VerticalAlignment = "Center"

        $installButton.Content = $installIcon
        $installButton.ToolTip = "Install or Upgrade the application"
        $buttonPanel.Children.Add($installButton) | Out-Null

        # Add Click event for the "Install" button
        $installButton.Add_Click({
            $appKey = $this.Parent.Parent.Parent.Tag
            $appObject = $sync.configs.applicationsHashtable.$appKey
            Invoke-WPFInstall -PackagesToInstall $appObject
        })

        # Create the "Uninstall" button
        $uninstallButton = New-Object Windows.Controls.Button
        $uninstallButton.Width = 45
        $uninstallButton.Height = 35

        $uninstallIcon = New-Object Windows.Controls.TextBlock
        $uninstallIcon.Text = [char]0xE74D  # Uninstall Icon
        $uninstallIcon.FontFamily = "Segoe MDL2 Assets"
        $uninstallIcon.FontSize = 20
        $uninstallIcon.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, "MainForegroundColor")
        $uninstallIcon.Background = "Transparent"
        $uninstallIcon.HorizontalAlignment = "Center"
        $uninstallIcon.VerticalAlignment = "Center"

        $uninstallButton.Content = $uninstallIcon
        $buttonPanel.Children.Add($uninstallButton) | Out-Null

        $uninstallButton.ToolTip = "Uninstall the application"
        $uninstallButton.Add_Click({
            $appKey = $this.Parent.Parent.Parent.Tag
            $appObject = $sync.configs.applicationsHashtable.$appKey
            Invoke-WPFUnInstall -PackagesToUninstall $appObject
        })

        # Create the "Info" button
        $infoButton = New-Object Windows.Controls.Button
        $infoButton.Width = 45
        $infoButton.Height = 35
        $infoButton.Margin = New-Object Windows.Thickness(10, 0, 0, 0)

        $infoIcon = New-Object Windows.Controls.TextBlock
        $infoIcon.Text = [char]0xE946  # Info Icon
        $infoIcon.FontFamily = "Segoe MDL2 Assets"
        $infoIcon.FontSize = 20
        $infoIcon.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, "MainForegroundColor")
        $infoIcon.Background = "Transparent"
        $infoIcon.HorizontalAlignment = "Center"
        $infoIcon.VerticalAlignment = "Center"

        $infoButton.Content = $infoIcon
        $infoButton.ToolTip = "Open the application's website in your default browser"
        $buttonPanel.Children.Add($infoButton) | Out-Null

        $infoButton.Add_Click({
            $appKey = $this.Parent.Parent.Parent.Tag
            $appObject = $sync.configs.applicationsHashtable.$appKey
            Start-Process $appObject.link
        })

        # Add the button panel to the DockPanel
        $dockPanel.Children.Add($buttonPanel) | Out-Null

        # Add the border to the main items control in the grid
        $itemsControl.Items.Add($border) | Out-Null
    }


    $window = $sync.Form

    switch ($TargetGridName) {
        "appspanel" {
            $targetGrid = Initialize-StackPanel
            $dockPanelContainer = Initialize-Header -TargetGrid $targetGrid
            $itemsControl = Initialize-AppArea -TargetGrid $dockPanelContainer
            $sync.ItemsControl = $itemsControl
            New-CategoryAppList -TargetGrid $itemsControl -Apps $Apps
        }
        default {
            Write-Output "$TargetGridName not yet implemented"
        }
    }
}
