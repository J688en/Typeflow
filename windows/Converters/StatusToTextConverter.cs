using System.Globalization;
using System.Windows.Data;
using TypeFlow.ViewModels;

namespace TypeFlow.Converters;

/// <summary>
/// Converts AppStatus enum to a human-readable status label string.
/// </summary>
[ValueConversion(typeof(AppStatus), typeof(string))]
public class StatusToTextConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (value is AppStatus status)
        {
            return status switch
            {
                AppStatus.Idle      => "Ready",
                AppStatus.Countdown => "Starting...",
                AppStatus.Typing    => "Typing",
                _                   => "Ready"
            };
        }
        return "Ready";
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        => throw new NotImplementedException();
}
