
using Configurator.Models;
using Microsoft.Maui.Graphics;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Text.Json;

namespace Configurator.ViewModels
{
    public class DscResultDisplay : INotifyPropertyChanged
    {
        public event PropertyChangedEventHandler? PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string? name = null)
            => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));

        public bool HasDifferingProperties => !string.IsNullOrEmpty(DifferingPropertiesList);

        public string Name { get; }
        public string Type { get; }
        public string Status { get; }
        public Color StatusColor { get; }
        public string StatusIcon { get; }
        public DscResultPayload? OriginalResultPayload { get; }

        public string? DifferingPropertiesList { get; }

        private bool _canApplyChange;
        public bool CanApplyChange
        {
            get => _canApplyChange;
            set
            {
                if (_canApplyChange != value)
                {
                    _canApplyChange = value;
                    OnPropertyChanged();
                }
            }
        }

        public DscResultDisplay(DscResult result, string command)
        {
            Name = result.Name;
            Type = result.Type;
            OriginalResultPayload = result.Result;

            bool inState = result.Result.InDesiredState == true;
            
            DifferingPropertiesList = result.Result.DifferingProperties != null && result.Result.DifferingProperties.Any()
                ? string.Join(", ", result.Result.DifferingProperties)
                : null;

            switch (command.ToLower())
            {
                case "test":
                    Status = inState ? "In Desired State" : "Not In Desired State";
                    StatusColor = inState ? Colors.Green : Colors.Red;
                    StatusIcon = inState ? "✓" : "✗";
                    CanApplyChange = !inState;
                    break;

                case "set":
                    bool hasChanges = result.Result.ChangedProperties?.Count > 0;
                    Status = hasChanges ? "Changed" : "No Changes";
                    StatusColor = hasChanges ? Colors.Orange : Colors.Green;
                    StatusIcon = hasChanges ? "⊛" : "✓";
                    break;

                default:
                    Status = "Retrieved";
                    StatusColor = Colors.Blue;
                    StatusIcon = "ℹ";
                    break;
            }
        }
    }
}
