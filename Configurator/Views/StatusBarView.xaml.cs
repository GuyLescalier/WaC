using Microsoft.Maui.Controls;
using System;
using System.Windows.Input;
using Configurator.ViewModels;

namespace Configurator.Views;

public partial class StatusBarView : ContentView
{
    public static readonly BindableProperty CancelCommandProperty =
        BindableProperty.Create(nameof(CancelCommand), typeof(ICommand), typeof(StatusBarView), null);

    public ICommand CancelCommand
    {
        get => (ICommand)GetValue(CancelCommandProperty);
        set => SetValue(CancelCommandProperty, value);
    }

    public StatusBarView()
    {
        InitializeComponent();
    }
}