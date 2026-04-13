using System.Globalization;
using System.Windows.Data;

namespace TypeFlow.Converters;

/// <summary>
/// Converts an enum value to bool for RadioButton bindings.
/// ConverterParameter should be the enum value to compare against.
/// </summary>
public class EnumToBoolConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (parameter is string paramStr && value != null)
            return value.ToString() == paramStr;
        return false;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (value is bool b && b && parameter is string paramStr)
            return Enum.Parse(targetType, paramStr);
        return Binding.DoNothing;
    }
}
