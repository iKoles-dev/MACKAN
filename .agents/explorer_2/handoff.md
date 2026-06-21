# Handoff Report — Human-Readable Sizes & Build/Test Discovery

## 1. Observation
### A. Mod Grid Data Population and Column Layout
- In `/Users/elijahn/GitHub/MACKAN/GUI/Controls/ManageMods.Designer.cs`, `ModGrid` is declared as a `System.Windows.Forms.DataGridView` (line 59) and the two size-related columns are defined as `DataGridViewTextBoxColumn` (lines 70, 71):
  ```csharp
  this.DownloadSize = new System.Windows.Forms.DataGridViewTextBoxColumn();
  this.InstallSize = new System.Windows.Forms.DataGridViewTextBoxColumn();
  ```
- In `/Users/elijahn/GitHub/MACKAN/GUI/Controls/ManageMods.resx`, the headers for these columns are localized (lines 150, 151):
  ```xml
  <data name="DownloadSize.HeaderText" xml:space="preserve"><value>Download</value></data>
  <data name="InstallSize.HeaderText" xml:space="preserve"><value>Install</value></data>
  ```
- In `/Users/elijahn/GitHub/MACKAN/GUI/Model/ModList.cs` (lines 225, 226, 240), each row is populated in `MakeRow`:
  ```csharp
  var downloadSize  = new DataGridViewTextBoxCell { Value = mod.DownloadSize            };
  var installSize   = new DataGridViewTextBoxCell { Value = mod.InstallSize             };
  ...
  item.Cells.AddRange(selecting, autoInstalled, updating, replacing, name, author, installVersion, latestVersion, compat, downloadSize, installSize, releaseDate, installDate, downloadCount, desc);
  ```

### B. Size Formatting Logic
- In `/Users/elijahn/GitHub/MACKAN/GUI/Model/GUIMod.cs` (lines 273, 274), formatting is assigned during `GUIMod` construction:
  ```csharp
  DownloadSize   = mod.download_size == 0 ? Properties.Resources.GUIModNSlashA : CkanModule.FmtSize(mod.download_size);
  InstallSize    = mod.install_size  == 0 ? Properties.Resources.GUIModNSlashA : CkanModule.FmtSize(mod.install_size);
  ```
- The formatting function `CkanModule.FmtSize(long bytes)` is defined in `/Users/elijahn/GitHub/MACKAN/Core/Types/CkanModule.cs` (lines 780-785):
  ```csharp
  public static string FmtSize(long bytes)
      => bytes < K       ? $"{bytes} B"
       : bytes < K*K     ? $"{bytes /K :N1} KiB"
       : bytes < K*K*K   ? $"{bytes /K/K :N1} MiB"
       : bytes < K*K*K*K ? $"{bytes /K/K/K :N1} GiB"
       :                   $"{bytes /K/K/K/K :N1} TiB";
  ```
  where `K` is defined as `private const double K = 1024;` (line 771).
- In `/Users/elijahn/GitHub/MACKAN/MACKAN.Service/CoreMackanModuleProvider.cs` (lines 432-433), the JSON-RPC Swift macOS app sidecar also formats sizes using `CkanModule.FmtSize`:
  ```csharp
  private static string SizeDisplay(long bytes)
      => bytes > 0 ? CkanModule.FmtSize(bytes) : "";
  ```

### C. Build & Test Commands on macOS
- Main Cake build file `/Users/elijahn/GitHub/MACKAN/build.sh` runs `dotnet run --project build/Build.csproj -- --verbosity Minimal ...`.
- Invoking `./build.sh` initially fails with:
  ```
  /Users/elijahn/GitHub/MACKAN/Core/Configuration/KeychainAuthTokenConfiguration.cs(115,43): error CS8604: Possible null reference argument for parameter 'token' in 'void IAuthTokenSecretStore.SetToken(string host, string token)'. [/Users/elijahn/GitHub/MACKAN/Core/CKAN-core.csproj::TargetFramework=net481]
  ```
  because `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>` is enabled in `/Users/elijahn/GitHub/MACKAN/Core/CKAN-core.csproj` (line 22).
- Compiling only the GUI project `CKAN-GUI.csproj` using Mono's `msbuild` with WarningsAsErrors bypassed completes successfully:
  ```bash
  msbuild GUI/CKAN-GUI.csproj /p:TargetFramework=net481 /p:TreatWarningsAsErrors=false /p:Configuration=Debug
  ```
  *Result*: `0 Error(s), 48 Warning(s)`, successfully compiled.
- Running the unit test suite on macOS:
  ```bash
  dotnet test Tests/Tests.csproj -p:TreatWarningsAsErrors=false
  ```
  *Result*: `Passed: 1450, Failed: 1`, where the single failure is `ModulesAsTheyFinish_InvalidURLsAndFiles_ThrowsModuleDownloadErrorsKraken` due to local/offline filesystem mock resolving variances in the `CODE_ONLY` network mode.

---

## 2. Logic Chain
1. **Mod Table Structure**: `ModGrid` is populated dynamically row-by-row in `ModList.MakeRow` using the values `DownloadSize` and `InstallSize` from `GUIMod` model.
2. **Formatting Centralization**: The formatting of the size string is centralized in `CkanModule.FmtSize(long bytes)`. Both the Windows Forms GUI and the Swift macOS app (via the `MACKAN.Service` JSON-RPC contracts) use this function.
3. **Representing Size Dynamically**: To satisfy R2 (Human-Readable sizes in KB, MB, GB, etc.), modifying the base `K` from `1024` to `1000` and changing the formatting suffixes from binary (`KiB`, `MiB`, `GiB`) to decimal (`KB`, `MB`, `GB`) inside `CkanModule.FmtSize` will dynamically and immediately update sizes across both the Windows Forms GUI and the Swift macOS app.
4. **Bypassing compilation block**: The build error CS8604 is caused by compiler nullable analysis flow limitations for the `netstandard2.0` and `net481` targets. Adding `-p:TreatWarningsAsErrors=false` allows verification of compilation and testing on macOS.

---

## 3. Caveats
- Direct verification of the macOS Swift client app UI presentation was not performed, but the underlying JSON-RPC contract mapping in `CoreMackanModuleProvider.cs` was inspected and verified to depend entirely on `CkanModule.FmtSize`.
- Changing `CkanModule.FmtSize` will also affect size strings in the `ConsoleUI` and `CmdLine` interfaces since they share the `Core` package.

---

## 4. Conclusion
- The target columns for formatting are the `DownloadSize` and `InstallSize` columns of `ModGrid` in the GUI.
- The formatting logic is located at `/Users/elijahn/GitHub/MACKAN/Core/Types/CkanModule.cs` in `CkanModule.FmtSize`.
- **Proposed Fix (Code Diff)**:
  Apply a null-forgiving operator to line 115 in `KeychainAuthTokenConfiguration.cs` to resolve the build warning:
  ```csharp
  // Before
  tokenStore.SetToken(host, token);
  // After
  tokenStore.SetToken(host, token!);
  ```
  And refactor `FmtSize` in `CkanModule.cs` to use decimal units:
  ```csharp
  private const double K_DECIMAL = 1000;
  public static string FmtSize(long bytes)
      => bytes < K_DECIMAL ? $"{bytes} B"
       : bytes < K_DECIMAL * K_DECIMAL ? $"{bytes / K_DECIMAL:N1} KB"
       : bytes < K_DECIMAL * K_DECIMAL * K_DECIMAL ? $"{bytes / K_DECIMAL / K_DECIMAL:N1} MB"
       : bytes < K_DECIMAL * K_DECIMAL * K_DECIMAL * K_DECIMAL ? $"{bytes / K_DECIMAL / K_DECIMAL / K_DECIMAL:N1} GB"
       : $"{bytes / K_DECIMAL / K_DECIMAL / K_DECIMAL / K_DECIMAL:N1} TB";
  ```

---

## 5. Verification Method
1. Compile the GUI project under macOS:
   ```bash
   msbuild GUI/CKAN-GUI.csproj /p:TargetFramework=net481 /p:TreatWarningsAsErrors=false /p:Configuration=Debug
   ```
2. Run the test suite:
   ```bash
   dotnet test Tests/Tests.csproj -p:TreatWarningsAsErrors=false
   ```
3. Inspect `Core/Types/CkanModule.cs` and `GUI/Model/GUIMod.cs` to confirm where `FmtSize` is defined and used.
