// SPDX-License-Identifier: AGPL-3.0-only

using System.Windows;
using CouchSubs.App.Services;
using CouchSubs.App.Theme;
using CouchSubs.Core;
using CouchSubs.Shell;

namespace CouchSubs.App;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        if (e.Args is ["--render-screens", var folder])
        {
            ScreenRenderer.Run(this, folder);
            return;
        }
        ThemeManager.Apply(Resources);
        ThemeManager.Follow(Resources);
        var controller = new AppController(new LiveServices(), new DpapiAppStore(), new FileSettingsStore(), new WindowsSleepGuard(),
            Localizer.Current, action => Dispatcher.BeginInvoke(action));
        var window = new ShellWindow(controller);
        MainWindow = window;
        window.Show();
    }
}
