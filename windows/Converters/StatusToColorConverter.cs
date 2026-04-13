using System.Globalization;
using System.Windows.Data;
using System.Windows.Media;
using TypeFlow.ViewModels;

namespace TypeFlow.Converters;

/// <summary>
/// Converts AppStatus enum to a brush color for the status indicator dot.
/// </summary>
[ValueConversion(typeof(AppStatus), typeof(Brush))]
public class StatusToColorConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (value is AppStatus status)
        {
            return status switch
            {
                AppStatus.Typing  => new SolidColorBrush(Color.FromRgb(0x0F, 0x7B, 0x0F)),  // green
                AppStatus.Countdown => new SolidColorBrush(Color.FromRgb(0xFF, 0x8C, 0x00)), // orange
                AppStatus.Idle    => new SolidColorBrush(Color.FromRgb(0xAB, 0xAB, 0xAB)),  // grey
                _ => new SolidColorBrush(Colors.Gray)
            };
        }
        return new SolidColorBrush(Colors.Gray);
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        => throw new NotImplementedException();
}
