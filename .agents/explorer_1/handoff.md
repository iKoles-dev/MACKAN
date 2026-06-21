# Handoff Report — Explorer 1

This report details the findings from the exploration of Dark Theme Integration (R1), Modernized Data Grid (R3), and Build/Test commands in the MACKAN repository on macOS.

---

## 1. Observation

### R1. Dark Theme Integration
* **Registry Patches**: In `GUI/DarkTheme.reg` and `GUI/DefaultTheme.reg`, the application specifies system-level color schemes for Windows under `[HKEY_CURRENT_USER\Control Panel\Colors]`. For example, in `GUI/DarkTheme.reg`:
  ```reg
  "ButtonFace"="37 37 37"
  "ButtonText"="255 255 255"
  "Window"="255 255 255"
  "WindowText"="0 0 0"
  ```
* **Detection System**: `GUI/Util.cs` (lines 470–489) detects Dark Mode dynamically across different operating systems:
  ```csharp
  public static bool DarkMode => Platform.IsWindows
                                     #if NET10_0_OR_GREATER
                                     ? Platform.IsWindows11
                                       && WinReg.GetValue(DarkModeKey, "AppsUseLightTheme", 1) is not 1
                                     #else
                                     ? false
                                     #endif
                               : Platform.IsUnix
                                     ? (CommandOutputContains("gsettings",
                                                              "get org.gnome.desktop.interface color-scheme",
                                                              "prefer-dark")
                                        ?? CommandOutputContains("kreadconfig5",
                                                                 "--group Colors --key ColorScheme",
                                                                 "Dark")
                                        ?? false)
                               : Platform.IsMac
                                     && (CommandOutputContains("defaults",
                                                               "read -g AppleInterfaceStyle",
                                                               "Dark")
                                         ?? false);
  ```
* **Title Bar Immersive Dark Mode**: In `GUI/Program.cs` (lines 53–66), if dark mode is active on Windows, `dwmapi.dll` attributes are set:
  ```csharp
  #if NET10_0_OR_GREATER
  if (Platform.IsWindows && Util.DarkMode)
  {
      Application.SetColorMode(SystemColorMode.System);
  }
  #endif
  var main = new Main(args, manager, userAgent);
  if (Platform.IsWindows && Util.DarkMode)
  {
      int val = 1;
      DwmSetWindowAttribute(main.Handle, DWMWA_USE_IMMERSIVE_DARK_MODE_BEFORE_20H1,
                            ref val, sizeof(int));
      DwmSetWindowAttribute(main.Handle, DWMWA_USE_IMMERSIVE_DARK_MODE,
                            ref val, sizeof(int));
  }
  ```
* **Custom Themed Controls**: The controls `GUI/Controls/ThemedListView.cs` and `GUI/Controls/ThemedTabControl.cs` are customized to follow system themes. In `ThemedListView.cs` (line 36), the back color is overridden for readability when groups are present under dark backgrounds:
  ```csharp
  BackColor = Color.FromArgb(117, 117, 117);
  ```
* **Default Label Colors**: Default labels like Favourites, Hidden, and Held are defined in `Core/Types/Labels/ModuleLabelList.cs` (lines 34–48) with specific colors:
  * Favourites: `Color.PaleGreen`
  * Hidden: `Color.PaleVioletRed`
  * Held: `Color.FromArgb(255, 255, 176)`

---

### R3. Modernized Data Grid
* **Grid Class**: The main mod list grid (`ModGrid`) is a standard `System.Windows.Forms.DataGridView` defined in `GUI/Controls/ManageMods.Designer.cs`.
* **Row Formatting & Colors**: In `GUI/Model/ModList.cs` (lines 152–157), rows are created and styled:
  ```csharp
  item.DefaultCellStyle.BackColor = GetRowBackground(mod, false, instance);
  item.DefaultCellStyle.ForeColor = item.DefaultCellStyle.BackColor.ForeColorForBackColor()
                                    ?? SystemColors.WindowText;
  item.DefaultCellStyle.SelectionBackColor = SelectionBlend(item.DefaultCellStyle.BackColor);
  item.DefaultCellStyle.SelectionForeColor = item.DefaultCellStyle.SelectionBackColor.ForeColorForBackColor()
                                             ?? SystemColors.HighlightText;
  ```
* **Conflict Colors**: The reddish color for conflicted rows is hardcoded in `ModList.cs` (line 699):
  ```csharp
  private static readonly Color conflictColor = Color.FromArgb(255, 64, 64);
  ```
* **Row Blending**: Multiple label colors are averaged in `Util.BlendColors` (lines 327–334):
  ```csharp
  public static Color BlendColors(params Color[] colors)
      => colors.Length <  1 ? Color.Empty
       : colors.Length == 1 && colors[0] is var c ? c
       : Color.FromArgb(colors.Sum(c => c.A) / colors.Length,
                        colors.Sum(c => c.R) / colors.Length,
                        colors.Sum(c => c.G) / colors.Length,
                        colors.Sum(c => c.B) / colors.Length);
  ```
* **Luminance and ForeColor**: ForeColor contrast selection is determined dynamically using relative luminance in `GUI/Util.cs` (lines 352–358 and 378–399) based on the WCAG standard.
* **Selection Blend**: Selected rows with custom background colors use an alpha blend (alpha = 0.4) of the selection color (`SystemColors.Highlight`) and the cell's background color.
* **Alternating Rows**: No alternating row styling or zebra striping is currently configured for `ModGrid` in the designer or model files.
* **Row Height Logic**:
  * Managed via `AutoSizeRowsMode = DisplayedCellsExceptHeaders` in the designer (line 333).
  * Monospace/font scaling is managed under Mono in `GUI/Extensions/WinFormsExtensions.cs` (lines 57–74):
    ```csharp
    grid.DefaultCellStyle.Font = grid.DefaultCellStyle.Font?.Scale(dpi);
    grid.ColumnHeadersDefaultCellStyle.Font = grid.ColumnHeadersDefaultCellStyle.Font?.Scale(dpi);
    ```

---

### Build and Test commands
* **Build Script (`build.sh`)**: The default build script runs Frosting tasks using Cake (`Build.csproj`).
* **Unix/macOS Build Failures**:
  1. Under the default build pipeline, compiling targeting `net481` fails on macOS because Mono 6.12 lacks targeting pack reference assemblies for `v4.8.1`:
     ```
     error MSB3644: The reference assemblies for .NETFramework,Version=v4.8.1 were not found.
     ```
  2. Compiling targeting `netstandard2.0` and `net481` fails due to CS8604 nullable warnings treated as errors in `Core/Configuration/KeychainAuthTokenConfiguration.cs` line 115:
     ```
     error CS8604: Possible null reference argument for parameter 'token' in 'void IAuthTokenSecretStore.SetToken(string host, string token)'.
     ```
* **Successful Build & Test Execution**: Running the tests directly with the target framework filtered to `net10.0` and disabling Warnings-As-Errors succeeds on macOS:
  ```bash
  dotnet test CKAN.sln --framework net10.0 /p:TreatWarningsAsErrors=false
  ```
  Result:
  ```
  Passed!  - Failed:     0, Passed:  1451, Skipped:     0, Total:  1451, Duration: 1 m 2 s - CKAN.Tests.dll (net10.0)
  ```

---

## 2. Logic Chain
1. **Registry theme limitations**: Because the codebase utilizes `SystemColors` for theme settings under WinForms on Windows, older runtime environments relied on `DarkTheme.reg` to override registry keys under `Control Panel/Colors` to change the colors of window objects.
2. **Dynamic color detection**: On non-Windows platforms, runtime checks query the system terminal commands (`gsettings`, `kreadconfig5`, `defaults`) to set `Util.DarkMode` property.
3. **No zebra striping configuration**: Data search of the GUI designer and code files (for `Alternating` or `Zebra`) confirmed no alternating row background colors are currently applied to `ModGrid` cells. Default background inherits the grid base window color.
4. **Dynamic styling based on labels**: The rows in the grid are colored based on the list of labels containing each mod, blending custom colors together or using a hardcoded red for conflicts. Contrast is maintained dynamically via luminance-based ForeColor selection.
5. **Target framework issues on macOS**:
   * Cake build script runs all target frameworks (`net481` and `net10.0`) by default.
   * `net481` is not natively supported by Mono 6.12 targeting packs on the host, causing MSBuild failures.
   * `net10.0-windows` cannot be compiled on macOS as Windows Forms is Windows-only.
   * Thus, restricting compilation and tests to the `net10.0` target framework via `dotnet test --framework net10.0` successfully builds the non-GUI packages (Core, NetKAN, ConsoleUI, Tests) and runs all 1,451 unit tests.

---

## 3. Caveats
* **Runtime theme toggle**: The current codebase does not implement a GUI setting or button to toggle dark theme programmatically. Instead, it relies on system detection or manual registry file imports.
* **Mono Windows Forms limitations**: Running the GUI project itself on macOS was not verified due to the missing `.NETFramework,Version=v4.8.1` targeting pack under the local Mono installation.

---

## 4. Conclusion
* **R1**: Dark theme detection is fully implemented across Windows, Linux, and macOS. Programmatic dark styling is applied to title bars via `DwmSetWindowAttribute` on Windows, but WinForms controls rely on standard Windows registry colors (`DarkTheme.reg`) or custom themed list/tab control overrides.
* **R3**: The main mod list grid (`ModGrid`) has no alternating rows/zebra striping. Selection uses a 40% blend of selection highlight and row back color. Row height is calculated dynamically based on cell content.
* **Build/Test**: The codebase can be verified on macOS by executing:
  ```bash
  dotnet test CKAN.sln --framework net10.0 /p:TreatWarningsAsErrors=false
  ```

---

## 5. Verification Method
1. Run the following command in the project root:
   ```bash
   dotnet test CKAN.sln --framework net10.0 /p:TreatWarningsAsErrors=false
   ```
2. Verify that the build succeeds and all 1,451 tests in `CKAN.Tests.dll` pass.
3. Inspect `GUI/Util.cs` lines 470–489 to verify the dark theme OS detection logic.
4. Inspect `GUI/Model/ModList.cs` lines 152–157 and `SelectionBlend` at line 686 to confirm the cell styling and selection color blending logic.
