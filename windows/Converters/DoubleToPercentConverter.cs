using System.Globalization;
using System.Windows.Data;

namespace TypeFlow.Converters;

/// <summary>
/// Converts a double (0.0–1.0) to a percentage string like "42%".
/// </summary>
[ValueConversion(typeof(double), typeof(string))]
public class DoubleToPercentConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (value is double d)
            return $"{(int)(d * 100)}%";
        return "0%";
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        => throw new NotImplementedException();
}
