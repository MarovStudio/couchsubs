// SPDX-License-Identifier: AGPL-3.0-only

using System.Windows;
using System.Windows.Controls;
using CouchSubs.Core;
using CouchSubs.Shell;

namespace CouchSubs.App.Views;

public partial class SettingsWindow : Window
{
    private static readonly (string Code, string Name)[] Languages =
        [("en", "English"), ("ja", "Japanese"), ("de", "German"), ("fr", "French"), ("es", "Spanish")];

    private readonly AppController controller;
    private bool loading = true;

    internal SettingsWindow(AppController controller)
    {
        this.controller = controller;
        InitializeComponent();
        var settings = controller.Settings;
        (settings.Style.FontSize switch { 36 => Small, 58 => Large, 72 => ExtraLarge, _ => Medium }).IsChecked = true;
        Position.Value = settings.Style.BottomPercent;
        Placement.SelectedItem = Placement.Items.Cast<ComboBoxItem>().First(item => (string)item.Tag == settings.Style.Placement.ToString());
        ShowPlacement(settings.Style.Placement);
        BackgroundOpacity.Value = settings.Style.Background;
        Bold.IsChecked = settings.Style.Bold;
        // Yalnız çeviri modeli olan diller listelenir; tek dil varsa seçim gösterilmez.
        foreach (var (code, name) in Languages.Where(l => controller.SupportsLanguage(l.Code)))
            GameLanguage.Items.Add(new ComboBoxItem { Content = Localizer.Current[name], Tag = code, IsSelected = code == settings.SourceLanguage });
        LanguageCard.Visibility = GameLanguage.Items.Count > 1 ? Visibility.Visible : Visibility.Collapsed;
        Region.Region = settings.Region;
        Region.Frame = controller.LastFrame;
        loading = false;
    }

    public static void Open(Window? owner, AppController controller) =>
        new SettingsWindow(controller) { Owner = owner }.ShowDialog();

    private void Update(Func<UserSettings, UserSettings> change)
    {
        if (!loading) controller.Settings = change(controller.Settings);
    }

    private void OnSize(object sender, RoutedEventArgs e) =>
        Update(s => s with { Style = s.Style with { FontSize = int.Parse((string)((RadioButton)sender).Tag) } });

    private void OnPosition(object sender, RoutedPropertyChangedEventArgs<double> e) =>
        Update(s => s with { Style = s.Style with { BottomPercent = (int)Math.Round(e.NewValue) } });

    private void OnPositionStart(object sender, System.Windows.Input.MouseButtonEventArgs e) => controller.SendTestSubtitle();

    private void OnPlacement(object sender, SelectionChangedEventArgs e)
    {
        if (Placement.SelectedItem is not ComboBoxItem { Tag: string tag }) return;
        var placement = Enum.Parse<SubtitlePlacement>(tag);
        ShowPlacement(placement);
        Update(s => s with { Style = s.Style with { Placement = placement } });
    }

    /// <summary>Elle ayarlanan yükseklik yalnız sabit yerleşimde anlamlıdır.</summary>
    private void ShowPlacement(SubtitlePlacement placement)
    {
        var isFixed = placement == SubtitlePlacement.Fixed;
        FixedPanel.Visibility = isFixed ? Visibility.Visible : Visibility.Collapsed;
        FollowsHint.Visibility = isFixed ? Visibility.Collapsed : Visibility.Visible;
    }

    private void OnBackground(object sender, RoutedPropertyChangedEventArgs<double> e) =>
        Update(s => s with { Style = s.Style with { Background = (int)Math.Round(e.NewValue) } });

    private void OnBold(object sender, RoutedEventArgs e) =>
        Update(s => s with { Style = s.Style with { Bold = Bold.IsChecked == true } });

    private void OnLanguage(object sender, SelectionChangedEventArgs e)
    {
        if (GameLanguage.SelectedItem is ComboBoxItem { Tag: string code }) Update(s => s with { SourceLanguage = code });
    }

    private void OnRegion(object? sender, CropRegion region) => Update(s => s with { Region = region });

    private void OnTest(object sender, RoutedEventArgs e) => controller.SendTestSubtitle();

    private void OnAbout(object sender, RoutedEventArgs e) => AboutWindow.Open(this);

    private void OnReset(object sender, RoutedEventArgs e)
    {
        var text = Localizer.Current;
        var answer = MessageBox.Show(this, text["The saved PS5, account and TV connection will be removed."], text["Set up again?"],
            MessageBoxButton.OKCancel, MessageBoxImage.Warning);
        if (answer != MessageBoxResult.OK) return;
        controller.ResetSetup();
        Close();
    }

    private void OnDone(object sender, RoutedEventArgs e) => Close();
}
