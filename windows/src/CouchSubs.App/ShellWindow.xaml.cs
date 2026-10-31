// SPDX-License-Identifier: AGPL-3.0-only

using System.Windows;

namespace CouchSubs.App;

/// <summary>Uygulamanın tek penceresi: kurulum bitmediyse sihirbaz, bittiyse ana ekran.</summary>
public partial class ShellWindow : Window
{
    public ShellWindow() => InitializeComponent();
}
