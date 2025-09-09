#nullable enable

using Configurator.Models;
using Configurator.Services;
using Configurator.ViewModels;
using Microsoft.Maui.Controls;
using System;
using System.Collections.ObjectModel;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.NamingConventions;

namespace Configurator
{
    public partial class MainPage : ContentPage
    {
        public ObservableCollection<string> ConfigFiles { get; } = new();
        public ObservableCollection<DscResourcePreview> DscResourcePreviews { get; } = new();
        public ObservableCollection<DscResultDisplay> DscResults { get; } = new();

        private string? _selectedConfigFile;
        private readonly string _configFilesPath = Path.GetFullPath(
            Path.Combine(AppDomain.CurrentDomain.BaseDirectory,
                         "..", "..", "..", "..", "..", "configurations", "DSCv3")
        );
        private readonly DscService _dscService = new();
        private CancellationTokenSource? _opCts;

        // === UI State ===
        private bool _isLoadingOverlayVisible;
        public bool IsLoadingOverlayVisible
        {
            get => _isLoadingOverlayVisible;
            set { if (_isLoadingOverlayVisible != value) { _isLoadingOverlayVisible = value; OnPropertyChanged(); } }
        }

        private bool _isConfigFileSelected;
        public bool IsConfigFileSelected
        {
            get => _isConfigFileSelected;
            set { if (_isConfigFileSelected != value) { _isConfigFileSelected = value; OnPropertyChanged(); UpdateApplyAllEnabled(); } }
        }

        private bool _canApplyAllChanges;
        public bool CanApplyAllChanges
        {
            get => _canApplyAllChanges;
            set { if (_canApplyAllChanges != value) { _canApplyAllChanges = value; OnPropertyChanged(); UpdateApplyAllEnabled(); } }
        }

        private double _operationProgress;
        public double OperationProgress
        {
            get => _operationProgress;
            set { if (_operationProgress != value) { _operationProgress = value; OnPropertyChanged(); } }
        }

        private bool _isProgressBarVisible;
        public bool IsProgressBarVisible
        {
            get => _isProgressBarVisible;
            set { if (_isProgressBarVisible != value) { _isProgressBarVisible = value; OnPropertyChanged(); } }
        }

        // === Nouvelle logique d'activation ApplyAll ===
        private bool _isFullTestDone;
        public bool IsFullTestDone
        {
            get => _isFullTestDone;
            private set { if (_isFullTestDone != value) { _isFullTestDone = value; OnPropertyChanged(); UpdateApplyAllEnabled(); } }
        }

        private bool _isApplyAllEnabled;
        public bool IsApplyAllEnabled
        {
            get => _isApplyAllEnabled;
            private set { if (_isApplyAllEnabled != value) { _isApplyAllEnabled = value; OnPropertyChanged(); } }
        }

        private void UpdateApplyAllEnabled()
        {
            // Apply All = actif seulement si
            // - un fichier est sélectionné
            // - un "Test All" a été exécuté
            // - des ressources sont "Not In Desired State"
            IsApplyAllEnabled = IsConfigFileSelected && IsFullTestDone && CanApplyAllChanges;
        }

        // === Bind du Picker ===
        private string? _selectedConfigFileName;
        public string? SelectedConfigFile
        {
            get => _selectedConfigFileName;
            set
            {
                if (_selectedConfigFileName == value) return;
                _selectedConfigFileName = value;
                OnPropertyChanged();

                if (!string.IsNullOrEmpty(_selectedConfigFileName))
                {
                    _selectedConfigFile = Path.Combine(_configFilesPath, _selectedConfigFileName);
                    IsConfigFileSelected = true;
                    IsFullTestDone = false; // nouveau fichier => il faut relancer Test All
                    _ = LoadConfigurationPreview();
                }
                else
                {
                    _selectedConfigFile = null;
                    IsConfigFileSelected = false;
                    IsFullTestDone = false;
                    DscResourcePreviews.Clear();
                    DscResults.Clear();
                    ResultsViewBorder.IsVisible = false;
                }
            }
        }

        // === Stats bindées (footer et header de droite) ===
        private bool _hasResults;
        public bool HasResults
        {
            get => _hasResults;
            private set { if (_hasResults != value) { _hasResults = value; OnPropertyChanged(); } }
        }

        private int _compliantCount;
        public int CompliantCount { get => _compliantCount; private set { if (_compliantCount != value) { _compliantCount = value; OnPropertyChanged(); } } }

        private int _nonCompliantCount;
        public int NonCompliantCount { get => _nonCompliantCount; private set { if (_nonCompliantCount != value) { _nonCompliantCount = value; OnPropertyChanged(); } } }

        private int _errorCount;
        public int ErrorCount { get => _errorCount; private set { if (_errorCount != value) { _errorCount = value; OnPropertyChanged(); } } }

        private double _compliancePercentage;
        public double CompliancePercentage { get => _compliancePercentage; private set { if (_compliancePercentage != value) { _compliancePercentage = value; OnPropertyChanged(); } } }

        public int ResourceCount => DscResourcePreviews.Count;

        public MainPage()
        {
            InitializeComponent();
            BindingContext = this;

            // calcule les stats à chaque changement de la liste
            DscResults.CollectionChanged += (_, __) => RecomputeStats();
            DscResourcePreviews.CollectionChanged += (_, __) => OnPropertyChanged(nameof(ResourceCount));
        }

        private void CancelButton_Clicked(object sender, EventArgs e)
        {
            try
            {
                _opCts?.Cancel();
                _dscService.CancelDscProcess();
            }
            finally
            {
                SetLoadingState(false);
            }
        }

        protected override void OnAppearing()
        {
            base.OnAppearing();
            LoadConfigFiles();
            SetLoadingState(false);
        }

        private void LoadConfigFiles()
        {
            ConfigFiles.Clear();
            try
            {
                var dir = new DirectoryInfo(_configFilesPath);
                if (!dir.Exists)
                {
                    DisplayAlert("Error", $"Directory not found: {_configFilesPath}", "OK");
                    return;
                }
                foreach (var file in dir.GetFiles("*.yaml").Concat(dir.GetFiles("*.yml")))
                    ConfigFiles.Add(file.Name);
            }
            catch (Exception ex)
            {
                DisplayAlert("Error loading files", ex.Message, "OK");
            }
        }

        private async Task LoadConfigurationPreview()
        {
            if (string.IsNullOrEmpty(_selectedConfigFile))
                return;

            DscResourcePreviews.Clear();
            DscResults.Clear();
            ResultsViewBorder.IsVisible = false;
            CanApplyAllChanges = false;
            IsFullTestDone = false; // nouvelle preview => test requis

            try
            {
                var yamlContent = await File.ReadAllTextAsync(_selectedConfigFile);
                var deserializer = new DeserializerBuilder()
                    .WithNamingConvention(CamelCaseNamingConvention.Instance)
                    .Build();
                var config = deserializer.Deserialize<DscConfiguration>(yamlContent);

                foreach (var resource in config.Resources)
                {
                    var preview = new DscResourcePreview
                    {
                        Name = resource.Name,
                        Type = resource.Type,
                        Resource = resource,
                        TestCommand = new Command(async () => await OnTestResourceClicked(resource)),
                        ApplyCommand = new Command(async () => await OnApplyResourceClicked(resource))
                    };
                    DscResourcePreviews.Add(preview);
                }
            }
            catch (Exception ex)
            {
                await DisplayAlert("Error parsing configuration", ex.Message, "OK");
            }
        }

        private async void OnRunFullConfigTestClicked(object sender, EventArgs e)
        {
            await RunFullConfigTest();
        }

        private async Task RunFullConfigTest()
        {
            if (DscResourcePreviews.Count == 0) return;

            _opCts = new CancellationTokenSource();
            var token = _opCts.Token;
            var total = DscResourcePreviews.Count;

            IsFullTestDone = false; // on (re)lance un test
            SetLoadingState(true, "Testing all resources…", 0);
            DscResults.Clear();
            ResultsViewBorder.IsVisible = true;

            try
            {
                for (int i = 0; i < total; i++)
                {
                    if (token.IsCancellationRequested) break;

                    var resourcePreview = DscResourcePreviews[i];
                    var resource = resourcePreview.Resource;

                    var progress = (double)(i + 1) / total;
                    SetLoadingState(true, $"Testing {i + 1}/{total}: {resource.Name}", progress);

                    var tempFile = string.Empty;
                    try
                    {
                        tempFile = await CreateTempConfigFileForSingleResource(resource);
                        var (stdOut, stdErr) = await _dscService.RunDscProcessAsync($"config test --file \"{tempFile}\"", token);

                        if (token.IsCancellationRequested) continue;

                        var json = !string.IsNullOrWhiteSpace(stdOut) ? stdOut : stdErr;
                        if (!string.IsNullOrWhiteSpace(json))
                        {
                            await ParseAndDisplayResults(json, "test", clearResults: false);
                        }
                    }
                    finally
                    {
                        if (!string.IsNullOrEmpty(tempFile) && File.Exists(tempFile))
                            File.Delete(tempFile);
                    }
                }

                if (!token.IsCancellationRequested)
                    IsFullTestDone = true; // le test complet a bien été exécuté
            }
            catch (OperationCanceledException)
            {
                Debug.WriteLine("RunFullConfigTest cancelled.");
            }
            catch (Exception ex)
            {
                if (!token.IsCancellationRequested)
                    await DisplayAlert("Execution Error", ex.Message, "OK");
            }
            finally
            {
                SetLoadingState(false);
                _opCts = null;
            }
        }

        private async Task OnTestResourceClicked(DscResourceInput resource)
        {
            await RunSingleResourceCommand(resource, "test");
        }

        private async Task OnApplyResourceClicked(DscResourceInput resource)
        {
            await RunSingleResourceCommand(resource, "set");
        }

        private async Task RunSingleResourceCommand(DscResourceInput resource, string command)
        {
            if (string.IsNullOrEmpty(_selectedConfigFile)) return;

            _opCts = new CancellationTokenSource();
            var token = _opCts.Token;
            var tempFile = string.Empty;

            SetLoadingState(true, $"{command}ing resource {resource.Name}…");
            try
            {
                tempFile = await CreateTempConfigFileForSingleResource(resource);
                var (stdOut, stdErr) = await _dscService.RunDscProcessAsync($"config {command} --file \"{tempFile}\"", token);

                var json = !string.IsNullOrWhiteSpace(stdOut) ? stdOut : stdErr;
                if (!string.IsNullOrWhiteSpace(json))
                {
                    await ParseAndDisplayResults(json, command);
                    ResultsViewBorder.IsVisible = true;

                    if (command == "set" && !token.IsCancellationRequested)
                    {
                        await DisplayAlert("Success", $"Resource {resource.Name} applied.", "OK");
                        await OnTestResourceClicked(resource);
                    }
                }
                else if (!token.IsCancellationRequested)
                {
                    await DisplayAlert("DSC Process Output", $"Standard Output:\n{stdOut}\n\nStandard Error:\n{stdErr}", "OK");
                }
            }
            catch (OperationCanceledException)
            {
                Debug.WriteLine($"RunSingleResourceCommand {command} cancelled.");
            }
            catch (Exception ex)
            {
                if (!token.IsCancellationRequested)
                    await DisplayAlert("Execution Error", ex.Message, "OK");
            }
            finally
            {
                if (!string.IsNullOrEmpty(tempFile) && File.Exists(tempFile))
                    File.Delete(tempFile);
                SetLoadingState(false);
                _opCts = null;
            }
        }

        private async Task<string> CreateTempConfigFileForSingleResource(DscResourceInput resource)
        {
            var tempConfig = new DscConfiguration
            {
                Schema = "https://raw.githubusercontent.com/PowerShell/DSC/main/schemas/v3/bundled/config/document.json",
                Resources = new List<DscResourceInput> { resource }
            };

            var serializer = new SerializerBuilder()
                .WithNamingConvention(CamelCaseNamingConvention.Instance)
                .Build();
            var yamlContent = serializer.Serialize(tempConfig);

            var tempFile = Path.Combine(Path.GetTempPath(), $"temp_{Guid.NewGuid()}.yaml");
            await File.WriteAllTextAsync(tempFile, yamlContent);
            return tempFile;
        }

        private async Task<string> CreateTempConfigFileForFullPath(string filePath)
        {
            var yamlContent = await File.ReadAllTextAsync(filePath);
            var deserializer = new DeserializerBuilder()
                .WithNamingConvention(CamelCaseNamingConvention.Instance)
                .Build();
            var config = deserializer.Deserialize<DscConfiguration>(yamlContent);

            config.Schema = "https://raw.githubusercontent.com/PowerShell/DSC/main/schemas/v3/bundled/config/document.json";

            var serializer = new SerializerBuilder()
                .WithNamingConvention(CamelCaseNamingConvention.Instance)
                .Build();
            var newYamlContent = serializer.Serialize(config);

            var tempFile = Path.Combine(Path.GetTempPath(), $"temp_{Guid.NewGuid()}.yaml");
            await File.WriteAllTextAsync(tempFile, newYamlContent);
            return tempFile;
        }

        private async Task ParseAndDisplayResults(string jsonContent, string command, bool clearResults = true)
        {
            try
            {
                var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                var dscOutput = JsonSerializer.Deserialize<DscOutput>(jsonContent, options);
                if (dscOutput?.Results == null) return;

                await MainThread.InvokeOnMainThreadAsync(() =>
                {
                    if (clearResults)
                        DscResults.Clear();

                    foreach (var result in dscOutput.Results)
                        DscResults.Add(new DscResultDisplay(result, command));

                    CanApplyAllChanges = DscResults.Any(r => r.Status == "Not In Desired State");
                    RecomputeStats();
                });
            }
            catch (JsonException ex)
            {
                await DisplayAlert("JSON Parsing Error", ex.Message, "OK");
            }
        }

        private async void OnApplyAllChangesClicked(object sender, EventArgs e)
        {
            // Par sécurité, on bloque si le Test All n'a pas été fait
            if (!IsFullTestDone) return;
            if (DscResourcePreviews.Count == 0) return;

            _opCts = new CancellationTokenSource();
            var token = _opCts.Token;

            // On applique seulement les ressources détectées "Not In Desired State" par le Test All
            var resourcesToApply = DscResults
                .Where(r => r.Status == "Not In Desired State")
                .Select(r => DscResourcePreviews.FirstOrDefault(p => p.Name == r.Name && p.Type == r.Type)?.Resource)
                .Where(r => r != null)!
                .ToList();

            var total = resourcesToApply.Count;
            if (total == 0)
            {
                SetLoadingState(true, "No non-compliant resources to apply.", 1);
                await Task.Delay(1500, token);
                SetLoadingState(false);
                return;
            }

            var appliedCount = 0;
            var successfullyApplied = new List<DscResourceInput>(); // <-- on mémorise celles qui ont réussi

            SetLoadingState(true, "Applying non-compliant changes…", 0);

            try
            {
                for (int i = 0; i < total; i++)
                {
                    if (token.IsCancellationRequested) break;

                    var resource = resourcesToApply[i];

                    var progress = (double)(i + 1) / total;
                    SetLoadingState(true, $"Applying {i + 1}/{total}: {resource!.Name}", progress);

                    var tempFile = string.Empty;
                    try
                    {
                        tempFile = await CreateTempConfigFileForSingleResource(resource!);
                        var (stdOut, stdErr) = await _dscService.RunDscProcessAsync($"config set --file \"{tempFile}\"", token);
                        if (string.IsNullOrWhiteSpace(stdErr))
                        {
                            appliedCount++;
                            successfullyApplied.Add(resource!); // <-- mémorisation
                        }
                    }
                    finally
                    {
                        if (!string.IsNullOrEmpty(tempFile) && File.Exists(tempFile))
                            File.Delete(tempFile);
                    }
                }

                SetLoadingState(true, $"Applied {appliedCount}/{total} non-compliant resources successfully.", 1);
                await Task.Delay(600, token);

                if (token.IsCancellationRequested)
                    await DisplayAlert("Cancelled", "Operation was cancelled.", "OK");

                //Retester UNIQUEMENT les ressources appliquées
                await RetestResources(successfullyApplied, token);
            }
            catch (OperationCanceledException)
            {
                Debug.WriteLine("OnApplyAllChangesClicked cancelled.");
            }
            catch (Exception ex)
            {
                if (!token.IsCancellationRequested)
                    await DisplayAlert("Execution Error", ex.Message, "OK");
            }
            finally
            {
                SetLoadingState(false);
                _opCts = null;
            }
        }

        private async Task RetestResources(IList<DscResourceInput> resources, CancellationToken token)
        {
            if (resources == null || resources.Count == 0) return;

            SetLoadingState(true, "Verifying applied resources…", 0);

            for (int i = 0; i < resources.Count; i++)
            {
                if (token.IsCancellationRequested) break;

                var res = resources[i];
                var progress = (double)(i + 1) / resources.Count;
                SetLoadingState(true, $"Testing {i + 1}/{resources.Count}: {res.Name}", progress);

                string tempFile = string.Empty;
                try
                {
                    tempFile = await CreateTempConfigFileForSingleResource(res);
                    var (stdOut, stdErr) = await _dscService.RunDscProcessAsync($"config test --file \"{tempFile}\"", token);

                    var json = !string.IsNullOrWhiteSpace(stdOut) ? stdOut : stdErr;
                    if (!string.IsNullOrWhiteSpace(json))
                    {
                        await ReplaceResultsForResourceFromJson(json);
                    }
                }
                finally
                {
                    if (!string.IsNullOrEmpty(tempFile) && File.Exists(tempFile))
                        File.Delete(tempFile);
                }
            }

            SetLoadingState(false);
        }

        private async Task ReplaceResultsForResourceFromJson(string json)
{
    try
    {
        var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
        var dscOutput = JsonSerializer.Deserialize<DscOutput>(json, options);
        if (dscOutput?.Results == null) return;

        await MainThread.InvokeOnMainThreadAsync(() =>
        {
            foreach (var r in dscOutput.Results)
            {
                var updated = new DscResultDisplay(r, "test");

                // On cherche l'existant (même Name + Type)
                var index = -1;
                for (int i = 0; i < DscResults.Count; i++)
                {
                    if (string.Equals(DscResults[i].Name, updated.Name, StringComparison.OrdinalIgnoreCase) &&
                        string.Equals(DscResults[i].Type, updated.Type, StringComparison.OrdinalIgnoreCase))
                    {
                        index = i; break;
                    }
                }

                if (index >= 0)
                    DscResults[index] = updated;   // remplace
                else
                    DscResults.Add(updated);        // ou ajoute si pas présent
            }

            // Met à jour les stats et le bouton Apply All si d'autres ressources restent non conformes
            CanApplyAllChanges = DscResults.Any(x => x.Status == "Not In Desired State");
            RecomputeStats();
        });
    }
    catch (JsonException ex)
    {
        await DisplayAlert("JSON Parsing Error", ex.Message, "OK");
    }
}



        private void SetLoadingState(bool isLoading, string? message = null, double progress = -1)
        {
            MainThread.BeginInvokeOnMainThread(() =>
            {
                IsLoadingOverlayVisible = isLoading;
                LoadingIndicator.IsRunning = isLoading;
                ConfigFileListView.IsEnabled = !isLoading;
                LoadingMessageLabel.Text = message ?? string.Empty;

                if (isLoading && progress >= 0)
                {
                    IsProgressBarVisible = true;
                    OperationProgress = progress;
                }
                else
                {
                    IsProgressBarVisible = false;
                    OperationProgress = 0;
                }
            });
        }

        private void RecomputeStats()
        {
            var total = DscResults.Count;
            HasResults = total > 0;
            CompliantCount = DscResults.Count(r => string.Equals(r.Status, "In Desired State", StringComparison.OrdinalIgnoreCase));
            NonCompliantCount = DscResults.Count(r => string.Equals(r.Status, "Not In Desired State", StringComparison.OrdinalIgnoreCase));
            ErrorCount = DscResults.Count(r => string.Equals(r.Status, "Error", StringComparison.OrdinalIgnoreCase) ||
                                               string.Equals(r.Status, "Failed", StringComparison.OrdinalIgnoreCase));

            CompliancePercentage = total == 0 ? 0d : (double)CompliantCount / total;
        }
    }
}
