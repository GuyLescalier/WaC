
#nullable enable

using Configurator.Models;
using System.Windows.Input;

namespace Configurator.ViewModels
{
    public class DscResourcePreview
    {
        public string Name { get; set; } = "";
        public string Type { get; set; } = "";
        public DscResourceInput Resource { get; set; } = new();

        public ICommand? TestCommand { get; set; }
        public ICommand? ApplyCommand { get; set; }
    }
}
