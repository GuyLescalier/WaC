using System;
using Microsoft.Maui.Controls;

namespace Configurator.Views
{
    public partial class HeaderView : ContentView
    {
        // Événements pour communiquer avec la page parente
        public event EventHandler OpenFileClicked;
        public event EventHandler RunFullConfigTestClicked;
        public event EventHandler ApplyAllChangesClicked;

        // Propriété bindable pour l'affichage du nom de fichier
        public static readonly BindableProperty SelectedFileDisplayProperty =
            BindableProperty.Create(nameof(SelectedFileDisplay), typeof(string), typeof(HeaderView), "No file selected.");

        public string SelectedFileDisplay
        {
            get => (string)GetValue(SelectedFileDisplayProperty);
            set => SetValue(SelectedFileDisplayProperty, value);
        }

        // Propriété bindable pour activer/désactiver les boutons principaux
        public static readonly BindableProperty IsConfigFileSelectedProperty =
            BindableProperty.Create(nameof(IsConfigFileSelected), typeof(bool), typeof(HeaderView), false);

        public bool IsConfigFileSelected
        {
            get => (bool)GetValue(IsConfigFileSelectedProperty);
            set => SetValue(IsConfigFileSelectedProperty, value);
        }

        // Propriété bindable pour le bouton "APPLY ALL"
        public static readonly BindableProperty IsApplyAllEnabledProperty =
            BindableProperty.Create(nameof(IsApplyAllEnabled), typeof(bool), typeof(HeaderView), false);

        public bool IsApplyAllEnabled
        {
            get => (bool)GetValue(IsApplyAllEnabledProperty);
            set => SetValue(IsApplyAllEnabledProperty, value);
        }

        public HeaderView()
        {
            InitializeComponent();
        }

        // Les handlers de clic ne font que déclencher les événements
        private void OnOpenFileClicked(object sender, EventArgs e)
        {
            OpenFileClicked?.Invoke(this, EventArgs.Empty);
        }

        private void OnRunFullConfigTestClicked(object sender, EventArgs e)
        {
            RunFullConfigTestClicked?.Invoke(this, EventArgs.Empty);
        }

        private void OnApplyAllChangesClicked(object sender, EventArgs e)
        {
            ApplyAllChangesClicked?.Invoke(this, EventArgs.Empty);
        }
    }
}
