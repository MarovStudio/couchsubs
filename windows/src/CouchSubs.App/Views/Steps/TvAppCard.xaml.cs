// SPDX-License-Identifier: AGPL-3.0-only

using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Threading;
using CouchSubs.Core;
using CouchSubs.Core.LgTv;
using CouchSubs.Shell;

namespace CouchSubs.App.Views.Steps;

/// <summary>TV uygulamasını geliştirici moduyla kurma adımları. Yapılacak bir şey yoksa görünmez.</summary>
public partial class TvAppCard : UserControl
{
    // Kullanıcı TV'de geliştirici modunu açınca kendiliğinden devam eder.
    private readonly DispatcherTimer devModeWatch = new() { Interval = TimeSpan.FromSeconds(3) };
    private AppController? controller;

    public TvAppCard()
    {
        InitializeComponent();
        devModeWatch.Tick += async (_, _) =>
        {
            if (controller is not null) await controller.RefreshTvAppAsync();
        };
        Loaded += (_, _) =>
        {
            controller = DataContext as AppController;
            if (controller is null) return;
            controller.PropertyChanged += OnChanged;
            Show(controller.TvApp);
        };
        Unloaded += (_, _) =>
        {
            devModeWatch.Stop();
            if (controller is not null) controller.PropertyChanged -= OnChanged;
        };
    }

    private void OnChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(AppController.TvApp)) Dispatcher.Invoke(() => Show(controller!.TvApp));
    }

    private void Show(TvAppState state)
    {
        var text = Localizer.Current;
        Visibility = state.Kind == TvAppKind.Unknown ? Visibility.Collapsed : Visibility.Visible;
        Steps.Visibility = state.Kind == TvAppKind.DevModeOff ? Visibility.Visible : Visibility.Collapsed;
        PassphraseArea.Visibility = state.Kind == TvAppKind.NeedsPassphrase ? Visibility.Visible : Visibility.Collapsed;
        Retry.Visibility = state.Kind == TvAppKind.Failed ? Visibility.Visible : Visibility.Collapsed;
        Status.Text = state.Kind switch
        {
            TvAppKind.Working => text["Checking the TV app…"],
            TvAppKind.UpToDate => string.Format(text["The TV app is ready (version %@)."].Replace("%@", "{0}"), state.Version),
            TvAppKind.DevModeOff => text["The TV app is not installed. CouchSubs can install it once Developer Mode is on."],
            TvAppKind.NeedsPassphrase => text["Developer Mode is on. One last step to install the TV app:"],
            _ => "",
        };
        Problem.Text = state.Error is { } error ? Message(error) : "";
        if (state.Kind == TvAppKind.DevModeOff) devModeWatch.Start();
        else devModeWatch.Stop();
    }

    private static string Message(DevModeError error) => Localizer.Current[error switch
    {
        DevModeError.KeyServerOff => "Key Server is off. Turn it on in the Developer Mode app and keep the app on screen.",
        DevModeError.WrongPassphrase => "The passphrase is not correct. Check it on the TV screen.",
        DevModeError.KeyRefused => "The TV refused the key. Open Key Server and type the passphrase again.",
        DevModeError.Unreachable => "The TV did not respond. Make sure it is on and on the same network.",
        DevModeError.ToolMissing => "Windows' OpenSSH Client is missing. Add it in Settings › System › Optional features and try again.",
        _ => "The TV app could not be installed. Check the TV's free space and try again.",
    }];

    private async void OnInstall(object sender, RoutedEventArgs e)
    {
        if (controller is not null && !string.IsNullOrWhiteSpace(Passphrase.Text))
            await controller.InstallTvAppAsync(Passphrase.Text);
    }

    private async void OnRetry(object sender, RoutedEventArgs e)
    {
        if (controller is not null) await controller.RefreshTvAppAsync();
    }
}
