// SPDX-License-Identifier: AGPL-3.0-only

using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;
using CouchSubs.Core;
using Frame = CouchSubs.Core.Frame;

namespace CouchSubs.App.Controls;

/// <summary>Son karenin üstünde altyazı bölgesini gösteren ve kenarlardan ayarlanan çerçeve.</summary>
public sealed class RegionPicker : UserControl
{
    private readonly Grid preview = new() { Height = 252, ClipToBounds = true };
    private readonly Rectangle frameBox = new() { StrokeThickness = 2, HorizontalAlignment = HorizontalAlignment.Left, VerticalAlignment = VerticalAlignment.Top };
    private readonly Slider top = Make(), bottom = Make(), left = Make(), right = Make();
    private CropRegion region = new();
    private bool updating;

    public event EventHandler<CropRegion>? RegionChanged;

    public RegionPicker()
    {
        frameBox.SetResourceReference(Shape.StrokeProperty, "accentBrush");
        frameBox.Fill = new SolidColorBrush(Color.FromArgb(36, 245, 184, 61));
        preview.SizeChanged += (_, _) => Layout();

        var panel = new StackPanel();
        var border = new Border { CornerRadius = new CornerRadius(10), Child = preview };
        border.SetResourceReference(Border.BackgroundProperty, "backgroundBrush");
        panel.Children.Add(border);

        var sliders = new Grid { Margin = new Thickness(0, 12, 0, 0) };
        sliders.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        sliders.ColumnDefinitions.Add(new ColumnDefinition());
        var rows = new[] { ("Top", top), ("Bottom", bottom), ("Left", left), ("Right", right) };
        for (var i = 0; i < rows.Length; i++)
        {
            sliders.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            var label = new TextBlock { Text = Localizer.Current[rows[i].Item1], Margin = new Thickness(0, 4, 16, 4), VerticalAlignment = VerticalAlignment.Center };
            Grid.SetRow(label, i);
            Grid.SetRow(rows[i].Item2, i);
            Grid.SetColumn(rows[i].Item2, 1);
            rows[i].Item2.ValueChanged += (_, _) => OnSlider();
            sliders.Children.Add(label);
            sliders.Children.Add(rows[i].Item2);
        }
        panel.Children.Add(sliders);

        var reset = new Button { Content = Localizer.Current["Reset area"], Margin = new Thickness(0, 12, 0, 0) };
        reset.Click += (_, _) => Region = new CropRegion();
        panel.Children.Add(reset);
        Content = panel;
        Frame = null;
    }

    public CropRegion Region
    {
        get => region;
        set
        {
            region = value;
            updating = true;
            (top.Value, bottom.Value, left.Value, right.Value) = (value.Top, value.Bottom, value.Left, value.Right);
            updating = false;
            Layout();
            RegionChanged?.Invoke(this, value);
        }
    }

    /// <summary>Çeviri başlayınca oyun görüntüsü burada görünür.</summary>
    public Frame? Frame
    {
        set
        {
            preview.Children.Clear();
            if (value is null)
            {
                preview.Children.Add(new TextBlock
                {
                    Text = Localizer.Current["The game picture appears here once translating starts."],
                    HorizontalAlignment = HorizontalAlignment.Center,
                    VerticalAlignment = VerticalAlignment.Center,
                    Style = (Style)Application.Current.FindResource("CaptionText"),
                });
            }
            else
            {
                var bitmap = BitmapSource.Create(value.Width, value.Height, 96, 96, PixelFormats.Bgra32, null, value.Pixels, value.Stride);
                preview.Children.Add(new Image { Source = bitmap, Stretch = Stretch.Fill });
            }
            preview.Children.Add(frameBox);
            Layout();
        }
    }

    private void OnSlider()
    {
        if (updating) return;
        // Kenarlar birbirini geçmesin; en az %5'lik bölge kalır.
        var topValue = Math.Min(top.Value, bottom.Value - 0.05);
        var leftValue = Math.Min(left.Value, right.Value - 0.05);
        Region = new CropRegion(Math.Max(0, topValue), bottom.Value, Math.Max(0, leftValue), right.Value);
    }

    private void Layout()
    {
        var (width, height) = (preview.ActualWidth, preview.ActualHeight);
        frameBox.Margin = new Thickness(width * region.Left, height * region.Top, 0, 0);
        frameBox.Width = Math.Max(0, width * (region.Right - region.Left));
        frameBox.Height = Math.Max(0, height * (region.Bottom - region.Top));
    }

    private static Slider Make() => new() { Minimum = 0, Maximum = 1, SmallChange = 0.01, LargeChange = 0.05 };
}
