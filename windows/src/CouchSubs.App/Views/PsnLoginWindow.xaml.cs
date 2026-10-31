// SPDX-License-Identifier: AGPL-3.0-only

using System.IO;
using System.Windows;
using CouchSubs.App.Services;
using CouchSubs.RemotePlay;
using Microsoft.Web.WebView2.Core;

namespace CouchSubs.App.Views;

/// <summary>Sony'nin giriş sayfasını açar; giriş bitince yönlendirme adresini yakalar. Parola yalnız Sony'ye gider.</summary>
public partial class PsnLoginWindow : Window
{
    private Uri? redirect;

    private PsnLoginWindow()
    {
        InitializeComponent();
        Loaded += async (_, _) => await OpenAsync();
    }

    /// <summary>Giriş tamamlanırsa yönlendirme adresini, vazgeçilirse null döner.</summary>
    public static Uri? Show(Window? owner)
    {
        var window = new PsnLoginWindow { Owner = owner };
        window.ShowDialog();
        return window.redirect;
    }

    private async Task OpenAsync()
    {
        // Her girişte temiz oturum: önceki çerezler (ör. kendi hesabınız) karışmasın.
        var folder = Path.Combine(AppPaths.Data, "webview", Guid.NewGuid().ToString("N"));
        var environment = await CoreWebView2Environment.CreateAsync(null, folder);
        await Browser.EnsureCoreWebView2Async(environment);
        Browser.CoreWebView2.NavigationStarting += OnNavigation;
        Browser.CoreWebView2.Navigate(PsnAccount.AuthorizeUrl.AbsoluteUri);
        Closed += (_, _) =>
        {
            Browser.Dispose();
            try { Directory.Delete(folder, true); } catch (IOException) { }
        };
    }

    private void OnNavigation(object? sender, CoreWebView2NavigationStartingEventArgs e)
    {
        if (!e.Uri.StartsWith(PsnAccount.RedirectPrefix, StringComparison.Ordinal)) return;
        e.Cancel = true;
        redirect = new Uri(e.Uri);
        Close();
    }

    private void OnCancel(object sender, RoutedEventArgs e) => Close();
}
