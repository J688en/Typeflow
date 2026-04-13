using System.Globalization;
using System.Windows;
using System.Windows.Data;

namespace TypeFlow.Converters;

/// <summary>
/// Converts a boolean to Visibility. True → Visible, False → Collapsed.
/// Use ConverterParameter="Invert" to reverse the logic.
/// </summary>
[ValueConversion(typeof(bool), typeof(Visibility))]
public class BoolToVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        bool boolValue = value is bool b && b;
        bool invert = parameter is string s && s.Equals("Invert", StringComparison.OrdinalIgnoreCase);
        bool visible = invert ? !boolValue : boolValue;
        return visible ? Visibility.Visible : Visibility.Collapsed;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        bool invert = parameter is string s && s.Equals("Invert", StringComparison.OrdinalIgnoreCase);
        bool visible = value is Visibility v && v == Visibility.Visible;
        return invert ? !visible : visible;
    }
}
