using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace Configurator.ViewModels
{
    public class NotificationViewModel : INotifyPropertyChanged
    {
        public event PropertyChangedEventHandler? PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string? name = null)
            => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));

        private string _message = "";
        public string Message
        {
            get => _message;
            set { if (_message != value) { _message = value; OnPropertyChanged(); } }
        }

        private double _progress;
        public double Progress
        {
            get => _progress;
            set { if (_progress != value) { _progress = value; OnPropertyChanged(); } }
        }

        private bool _isProgressBarVisible;
        public bool IsProgressBarVisible
        {
            get => _isProgressBarVisible;
            set { if (_isProgressBarVisible != value) { _isProgressBarVisible = value; OnPropertyChanged(); } }
        }

        private bool _isIndeterminate;
        public bool IsIndeterminate
        {
            get => _isIndeterminate;
            set { if (_isIndeterminate != value) { _isIndeterminate = value; OnPropertyChanged(); } }
        }

        private bool _isCancellable;
        public bool IsCancellable
        {
            get => _isCancellable;
            set { if (_isCancellable != value) { _isCancellable = value; OnPropertyChanged(); } }
        }
    }
}
