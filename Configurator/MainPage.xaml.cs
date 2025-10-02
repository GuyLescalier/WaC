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
using Microsoft.Maui.Storage;
using Microsoft.Maui.Dispatching;
using System.Windows.Input;

namespace Configurator
{
    public partial class MainPage : ContentPage
    {
        public ObservableCollection<DscResourceViewModel> DscResources { get; } = new();

        private string? _selectedConfigFile;

        private string? _selectedFileDisplay;
        public string? SelectedFileDisplay
        {
            get => _selectedFileDisplay;
            private set { if (_selectedFileDisplay != value) { _selectedFileDisplay = value; OnPropertyChanged(); } }
        }

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
            IsApplyAllEnabled = IsConfigFileSelected && IsFullTestDone && CanApplyAllChanges;
        }

        public int ResourceCount => DscResources.Count;

        public NotificationViewModel CurrentNotification { get; } = new NotificationViewModel();
        public ICommand CancelNotificationCommand { get; private set; }

        public MainPage()
        {
            InitializeComponent();
            BindingContext = this;
            CancelNotificationCommand = new Command((sender) => CancelButton_Clicked(sender, EventArgs.Empty));
            DscResources.CollectionChanged += (_, __) =>
            {
                OnPropertyChanged(nameof(ResourceCount));
                RecomputeStats();
            };
        }

        private void RecomputeStats()
        {
            var total = DscResources.Count;
            if (total == 0) {
                CanApplyAllChanges = false;
                return;
            }

            CanApplyAllChanges = DscResources.Any(r => r.Status == "Not In Desired State");
        }

        private void SetLoadingState(bool isLoading, string? message = null, double progress = -1, bool isCancellable = false)
        {
            MainThread.BeginInvokeOnMainThread(() =>
            {
                CurrentNotification.Message = message ?? "";
                CurrentNotification.IsCancellable = isCancellable;

                if (isLoading && progress >= 0)
                {
                    CurrentNotification.IsProgressBarVisible = true;
                    CurrentNotification.Progress = progress;
                }
                else
                {
                    CurrentNotification.IsProgressBarVisible = false;
                    CurrentNotification.Progress = 0;
                }
            });
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
                SetLoadingState(false, isCancellable: false);
            }
        }

        protected override void OnAppearing()
        {
            base.OnAppearing();
            SetLoadingState(false, isCancellable: false);
        }

        private async void OnOpenFileClicked(object? sender, EventArgs e)
        {
            try
            {
                var result = await FilePicker.PickAsync(new PickOptions
                {
                    PickerTitle = "Open a DSC v3 YAML configuration"
                });

                if (result == null) return;

                var ext = Path.GetExtension(result.FileName);
                if (!string.Equals(ext, ".yaml", StringComparison.OrdinalIgnoreCase) &&
                    !string.Equals(ext, ".yml", StringComparison.OrdinalIgnoreCase))
                {
                    await DisplayAlert("Invalid file", "Please select a YAML (.yaml or .yml) file.", "OK");
                    return;
                }

                _selectedConfigFile = result.FullPath;
                SelectedFileDisplay = result.FileName;
                IsConfigFileSelected = true;
                IsFullTestDone = false;

                await LoadConfigurationPreview();
            }
            catch (Exception ex)
            {
                await DisplayAlert("File open error", ex.Message, "OK");
            }
        }

        private async Task LoadConfigurationPreview()
        {
            if (string.IsNullOrEmpty(_selectedConfigFile)) return;

            DscResources.Clear();
            CanApplyAllChanges = false;
            IsFullTestDone = false;

            try
            {
                var yamlContent = await File.ReadAllTextAsync(_selectedConfigFile);
                var deserializer = new DeserializerBuilder()
                    .WithNamingConvention(CamelCaseNamingConvention.Instance)
                    .Build();
                var config = deserializer.Deserialize<DscConfiguration>(yamlContent);

                foreach (var resource in config.Resources)
                {
                    var vm = new DscResourceViewModel
                    {
                        Name = resource.Name,
                        Type = resource.Type,
                        Resource = resource,
                    };
                    vm.TestCommand = new Command(async () => await OnTestResourceClicked(vm));
                    vm.ApplyCommand = new Command(async () => await OnApplyResourceClicked(vm));
                    DscResources.Add(vm);
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
            if (DscResources.Count == 0) return;

            _opCts = new CancellationTokenSource();
            var token = _opCts.Token;
            var total = DscResources.Count;

            IsFullTestDone = false;
            SetLoadingState(true, "Testing all resources…", 0, isCancellable: true);
            foreach (var vm in DscResources) { vm.ResetStatus(); }

            try
            {
                for (int i = 0; i < total; i++)
                {
                    if (token.IsCancellationRequested) break;

                    var vm = DscResources[i];
                    var progress = (double)(i + 1) / total;
                    SetLoadingState(true, $"Testing {i + 1}/{total}: {vm.Name}", progress, isCancellable: true);

                    var tempConfig = new DscConfiguration
                    {
                        Schema = "https://raw.githubusercontent.com/PowerShell/DSC/main/schemas/v3/bundled/config/document.json",
                        Resources = new List<DscResourceInput> { vm.Resource }
                    };
                    var serializer = new SerializerBuilder().WithNamingConvention(CamelCaseNamingConvention.Instance).Build();
                    var yamlContent = serializer.Serialize(tempConfig);

                    var (stdOut, stdErr) = await _dscService.RunDscProcessAsync("test", yamlContent, token);

                    if (token.IsCancellationRequested) continue;

                    var json = !string.IsNullOrWhiteSpace(stdOut) ? stdOut : stdErr;
                    if (!string.IsNullOrWhiteSpace(json))
                    {
                        await ParseAndDisplayResults(json, "test", vm);
                    }
                }

                if (!token.IsCancellationRequested)
                    IsFullTestDone = true;
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
                SetLoadingState(false, isCancellable: false);
                _opCts = null;
            }
        }

        private async Task OnTestResourceClicked(DscResourceViewModel vm)
        {
            await RunSingleResourceCommand(vm, "test");
        }

        private async Task OnApplyResourceClicked(DscResourceViewModel vm)
        {
            await RunSingleResourceCommand(vm, "set");
        }

        private async Task RunSingleResourceCommand(DscResourceViewModel vm, string command)
        {
            if (string.IsNullOrEmpty(_selectedConfigFile)) return;

            _opCts = new CancellationTokenSource();
            var token = _opCts.Token;
            var tempConfig = new DscConfiguration
            {
                Schema = "https://raw.githubusercontent.com/PowerShell/DSC/main/schemas/v3/bundled/config/document.json",
                Resources = new List<DscResourceInput> { vm.Resource }
            };
            var serializer = new SerializerBuilder().WithNamingConvention(CamelCaseNamingConvention.Instance).Build();
            var yamlContent = serializer.Serialize(tempConfig);

            SetLoadingState(true, $"{command}ing resource {vm.Name}…", isCancellable: true);
            try
            {
                var (stdOut, stdErr) = await _dscService.RunDscProcessAsync(command, yamlContent, token);

                var json = !string.IsNullOrWhiteSpace(stdOut) ? stdOut : stdErr;
                if (!string.IsNullOrWhiteSpace(json))
                {
                    await ParseAndDisplayResults(json, command, vm);

                    if (command == "set" && !token.IsCancellationRequested)
                    {
                        await DisplayAlert("Success", $"Resource {vm.Name} applied.", "OK");
                        await OnTestResourceClicked(vm);
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
                SetLoadingState(false, isCancellable: false);
                _opCts = null;
            }
        }



        private async Task ParseAndDisplayResults(string jsonContent, string command, DscResourceViewModel vmToUpdate)
        {
            try
            {
                var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                var dscOutput = JsonSerializer.Deserialize<DscOutput>(jsonContent, options);
                var result = dscOutput?.Results?.FirstOrDefault();
                if (result == null) return;

                await MainThread.InvokeOnMainThreadAsync(() =>
                {
                    vmToUpdate.UpdateFromResult(result, command);
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
            if (!IsFullTestDone) return;

            var resourcesToApply = DscResources.Where(r => r.Status == "Not In Desired State").ToList();
            if (resourcesToApply.Count == 0) return;

            _opCts = new CancellationTokenSource();
            var token = _opCts.Token;
            var total = resourcesToApply.Count;

            SetLoadingState(true, "Applying non-compliant changes…", 0, isCancellable: true);

            try
            {
                for (int i = 0; i < total; i++)
                {
                    if (token.IsCancellationRequested) break;

                    var vm = resourcesToApply[i];
                    var progress = (double)(i + 1) / total;
                    SetLoadingState(true, $"Applying {i + 1}/{total}: {vm.Name}", progress, isCancellable: true);

                    var tempConfig = new DscConfiguration
                    {
                        Schema = "https://raw.githubusercontent.com/PowerShell/DSC/main/schemas/v3/bundled/config/document.json",
                        Resources = new List<DscResourceInput> { vm.Resource }
                    };
                    var serializer = new SerializerBuilder().WithNamingConvention(CamelCaseNamingConvention.Instance).Build();
                    var yamlContent = serializer.Serialize(tempConfig);

                    var (stdOut, stdErr) = await _dscService.RunDscProcessAsync("set", yamlContent, token);
                    if (string.IsNullOrWhiteSpace(stdErr))
                    {
                        await ParseAndDisplayResults(stdOut, "test", vm);
                    }
                }
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
                SetLoadingState(false, isCancellable: false);
                _opCts = null;
            }
        }
    }
}
