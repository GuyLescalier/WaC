using System.Collections.ObjectModel;
using Configurator.ViewModels;

namespace Configurator.Views;

public partial class ResourceListView : ContentView
{
    public static readonly BindableProperty ItemsSourceProperty =
        BindableProperty.Create(nameof(ItemsSource), typeof(ObservableCollection<DscResourceViewModel>), typeof(ResourceListView), null);

    public ObservableCollection<DscResourceViewModel> ItemsSource
    {
        get => (ObservableCollection<DscResourceViewModel>)GetValue(ItemsSourceProperty);
        set => SetValue(ItemsSourceProperty, value);
    }

	public ResourceListView()
	{
		InitializeComponent();
	}
}