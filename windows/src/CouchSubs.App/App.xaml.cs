// SPDX-License-Identifier: AGPL-3.0-only

using System.Windows;
using CouchSubs.App.Theme;

namespace CouchSubs.App;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        ThemeManager.Apply(Resources);
        ThemeManager.Follow(Resources);
        var window = new ShellWindow();
        MainWindow = window;
        window.Show();
    }
}
