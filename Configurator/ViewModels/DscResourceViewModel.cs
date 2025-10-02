#nullable enable

using Configurator.Models;
using Configurator.Services;
using Microsoft.Maui.Graphics;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.CompilerServices;
using System.Windows.Input;

namespace Configurator.ViewModels
{
    public class DscResourceViewModel : INotifyPropertyChanged
    {
        public event PropertyChangedEventHandler? PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string? name = null)
            => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));

        public string Name { get; set; } = "";
        public string Type { get; set; } = "";
        public DscResourceInput Resource { get; set; } = new();

        public ICommand TestCommand { get; set; } = null!;
        public ICommand ApplyCommand { get; set; } = null!;

        // Properties from DscResultDisplay
        private string _status = "Pending";
        public string Status
        {
            get => _status;
            set { if (_status != value) { _status = value; OnPropertyChanged(); } }
        }

        private Color _statusColor = Colors.Gray;
        public Color StatusColor
        {
            get => _statusColor;
            set { if (_statusColor != value) { _statusColor = value; OnPropertyChanged(); } }
        }

        private string? _differingPropertiesList;
        public string? DifferingPropertiesList
        {
            get => _differingPropertiesList;
            set { if (_differingPropertiesList != value) { _differingPropertiesList = value; OnPropertyChanged(); OnPropertyChanged(nameof(HasDifferingProperties)); } }
        }

        public bool HasDifferingProperties => !string.IsNullOrEmpty(DifferingPropertiesList);

        private System.DateTime? _lastTestTime;
        public System.DateTime? LastTestTime
        {
            get => _lastTestTime;
            set { if (_lastTestTime != value) { _lastTestTime = value; OnPropertyChanged(); } }
        }

        public void UpdateFromResult(DscResult result, string command)
        {
            bool inState = result.Result?.InDesiredState == true;

            DifferingPropertiesList = result.Result?.DifferingProperties != null && result.Result.DifferingProperties.Any()
                ? string.Join(", ", result.Result.DifferingProperties)
                : null;

            switch (command.ToLower())
            {
                case "test":
                    Status = inState ? "In Desired State" : "Not In Desired State";
                    StatusColor = inState ? Color.FromArgb("#16825D") : Color.FromArgb("#DA3B3B");
                    break;

                case "set":
                    bool hasChanges = result.Result?.ChangedProperties?.Count > 0;
                    Status = hasChanges ? "Changed" : "No Changes";
                    StatusColor = hasChanges ? Colors.Orange : Color.FromArgb("#16825D");
                    break;

                default:
                    Status = "Retrieved";
                    StatusColor = Colors.Blue;
                    break;
            }

            LastTestTime = System.DateTime.Now;
        }

        public void ResetStatus()
        {
            Status = "Pending";
            StatusColor = Colors.Gray;
            DifferingPropertiesList = null;
            LastTestTime = null;
        }
    }
}
