
namespace Comparison {
    int sort_function (Granite.Widgets.SourceList.Item str1, Granite.Widgets.SourceList.Item str2) {
        if (!(str1 is SymbolItem && str2 is SymbolItem))
            return str1.name.collate (str2.name);
        var a = (SymbolItem) str1;
        var b = (SymbolItem) str2;
        var sa = a.symbol;
        var sb = b.symbol;
        if (sa is Vala.Class)
            return (compare_class ((Vala.Class) sa, sb));
        else if (sa is Vala.Constant)
            return (compare_constant ((Vala.Constant) sa, sb));
        else if (sa is Vala.Delegate)
            return (compare_delegate ((Vala.Delegate) sa, sb));
        else if (sa is Vala.Constructor)
            return (compare_constructor ((Vala.Constructor) sa, sb));
        else if (sa is Vala.Destructor)
            return (compare_destructor ((Vala.Destructor) sa, sb));
        else if (sa is Vala.CreationMethod)
            return (compare_creationmethod ((Vala.CreationMethod) sa, sb));
        else if (sa is Vala.Enum)
            return (compare_enum ((Vala.Enum) sa, sb));
        else if (sa is Vala.Field)
            return (compare_field ((Vala.Field) sa, sb));
        else if (sa is Vala.Interface)
            return (compare_interface ((Vala.Interface) sa, sb));
        else if (sa is Vala.Method)
            return (compare_method ((Vala.Method) sa, sb));
        else if (sa is Vala.Namespace)
            return (compare_namespace ((Vala.Namespace) sa, sb));
        else if (sa is Vala.Property)
            return (compare_property ((Vala.Property) sa, sb));
        else if (sa is Vala.Signal)
            return (compare_signal ((Vala.Signal) sa, sb));
        else if (sa is Vala.Struct)
            return (compare_struct ((Vala.Struct) sa, sb));
        return str1.name.collate (str2.name);
    }
    
    int compare_class (Vala.Class s, Vala.Symbol s2)
    {
        if (s2 is Vala.Constant)
            return 1;
        else if (s2 is Vala.Delegate)
            return 1;
        else if (s2 is Vala.CreationMethod)
            return 1;
        else if (s2 is Vala.Constructor)
            return 1;
        else if (s2 is Vala.Destructor)
            return 1;
        else if (s2 is Vala.Enum)
            return 1;
        else if (s2 is Vala.Field)
            return 1;
        else if (s2 is Vala.Interface)
            return 1;
        else if (s2 is Vala.Method)
            return 1;
        else if (s2 is Vala.Namespace)
            return 1;
        else if (s2 is Vala.Property)
            return 1;
        else if (s2 is Vala.Signal)
            return 1;
        else if (s2 is Vala.Struct)
            return 1;
        return s.name.collate (s2.name);
    }
    int compare_constant (Vala.Constant s, Vala.Symbol s2)
    {
        if (s2 is Vala.Class)
            return -1;
        else if (s2 is Vala.Delegate)
            return -1;
        else if (s2 is Vala.CreationMethod)
            return -1;
        else if (s2 is Vala.Constructor)
            return -1;
        else if (s2 is Vala.Destructor)
            return -1;
        else if (s2 is Vala.Enum)
            return 1;
        else if (s2 is Vala.Field)
            return -1;
        else if (s2 is Vala.Interface)
            return -1;
        else if (s2 is Vala.Method)
            return -1;
        else if (s2 is Vala.Namespace)
            return -1;
        else if (s2 is Vala.Property)
            return -1;
        else if (s2 is Vala.Signal)
            return -1;
        else if (s2 is Vala.Struct)
            return -1;
        return s.name.collate (s2.name);
    }
    int compare_delegate (Vala.Delegate s, Vala.Symbol s2)
    {
        if (s2 is Vala.Constant)
            return 1;
        else if (s2 is Vala.Class)
            return -1;
        else if (s2 is Vala.CreationMethod)
            return 1;
        else if (s2 is Vala.Constructor)
            return 1;
        else if (s2 is Vala.Destructor)
            return 1;
        else if (s2 is Vala.Enum)
            return 1;
        else if (s2 is Vala.Field)
            return 1;
        else if (s2 is Vala.Interface)
            return -1;
        else if (s2 is Vala.Method)
            return -1;
        else if (s2 is Vala.Namespace)
            return -1;
        else if (s2 is Vala.Property)
            return 1;
        else if (s2 is Vala.Signal)
            return 1;
        else if (s2 is Vala.Struct)
            return -1;
        return s.name.collate (s2.name);
    }
    int compare_constructor (Vala.Constructor s, Vala.Symbol s2)
    {
        if (s2 is Vala.Constant)
            return 1;
        else if (s2 is Vala.Delegate)
            return -1;
        else if (s2 is Vala.Class)
            return -1;
        else if (s2 is Vala.CreationMethod)
            return 1;
        else if (s2 is Vala.Destructor)
            return -1;
        else if (s2 is Vala.Enum)
            return 1;
        else if (s2 is Vala.Field)
            return 1;
        else if (s2 is Vala.Interface)
            return -1;
        else if (s2 is Vala.Method)
            return -1;
        else if (s2 is Vala.Namespace)
            return -1;
        else if (s2 is Vala.Property)
            return 1;
        else if (s2 is Vala.Signal)
            return 1;
        else if (s2 is Vala.Struct)
            return -1;
        return s.name.collate (s2.name);
    }
    int compare_destructor (Vala.Destructor s, Vala.Symbol s2)
    {
        if (s2 is Vala.Constant)
            return 1;
        else if (s2 is Vala.Delegate)
            return -1;
        else if (s2 is Vala.CreationMethod)
            return 1;
        else if (s2 is Vala.Constructor)
            return 1;
        else if (s2 is Vala.Class)
            return -1;
        else if (s2 is Vala.Enum)
            return 1;
        else if (s2 is Vala.Field)
            return 1;
        else if (s2 is Vala.Interface)
            return -1;
        else if (s2 is Vala.Method)
            return -1;
        else if (s2 is Vala.Namespace)
            return -1;
        else if (s2 is Vala.Property)
            return 1;
        else if (s2 is Vala.Signal)
            return 1;
        else if (s2 is Vala.Struct)
            return -1;
        return s.name.collate (s2.name);
    }
    int compare_creationmethod (Vala.CreationMethod s, Vala.Symbol s2)
    {
        if (s2 is Vala.Constant)
            return 1;
        else if (s2 is Vala.Delegate)
            return -1;
        else if (s2 is Vala.Class)
            return -1;
        else if (s2 is Vala.Constructor)
            return -1;
        else if (s2 is Vala.Destructor)
            return -1;
        else if (s2 is Vala.Enum)
            return 1;
        else if (s2 is Vala.Field)
            return 1;
        else if (s2 is Vala.Interface)
            return -1;
        else if (s2 is Vala.Method)
            return -1;
        else if (s2 is Vala.Namespace)
            return -1;
        else if (s2 is Vala.Property)
            return 1;
        else if (s2 is Vala.Signal)
            return 1;
        else if (s2 is Vala.Struct)
            return -1;

        if (s.name == ".new")
            return -1;

        if (s2.name == ".new")
            return 1;

        return s.name.collate (s2.name);
    }
    int compare_enum (Vala.Enum s, Vala.Symbol s2)
    {
        if (s2 is Vala.Constant)
            return -1;
        else if (s2 is Vala.Delegate)
            return -1;
        else if (s2 is Vala.CreationMethod)
            return -1;
        else if (s2 is Vala.Constructor)
            return -1;
        else if (s2 is Vala.Destructor)
            return -1;
        else if (s2 is Vala.Class)
            return -1;
        else if (s2 is Vala.Field)
            return -1;
        else if (s2 is Vala.Interface)
            return -1;
        else if (s2 is Vala.Method)
            return -1;
        else if (s2 is Vala.Namespace)
            return 1;
        else if (s2 is Vala.Property)
            return -1;
        else if (s2 is Vala.Signal)
            return -1;
        else if (s2 is Vala.Struct)
            return -1;
        return s.name.collate (s2.name);
    }
    int compare_field (Vala.Field s, Vala.Symbol s2)
    {
        if (s2 is Vala.Constant)
            return 1;
        else if (s2 is Vala.Delegate)
            return -1;
        else if (s2 is Vala.CreationMethod)
            return -1;
        else if (s2 is Vala.Constructor)
            return -1;
        else if (s2 is Vala.Destructor)
            return -1;
        else if (s2 is Vala.Enum)
            return -1;
        else if (s2 is Vala.Class)
            return -1;
        else if (s2 is Vala.Interface)
            return -1;
        else if (s2 is Vala.Method)
            return -1;
        else if (s2 is Vala.Namespace)
            return -1;
        else if (s2 is Vala.Property)
            return -1;
        else if (s2 is Vala.Signal)
            return -1;
        else if (s2 is Vala.Struct)
            return -1;
        return s.name.collate (s2.name);
    }
    int compare_interface (Vala.Interface s, Vala.Symbol s2)
    {
        if (s2 is Vala.Constant)
            return 1;
        else if (s2 is Vala.Delegate)
            return -1;
        else if (s2 is Vala.CreationMethod)
            return -1;
        else if (s2 is Vala.Constructor)
            return -1;
        else if (s2 is Vala.Destructor)
            return -1;
        else if (s2 is Vala.Enum)
            return 1;
        else if (s2 is Vala.Field)
            return 1;
        else if (s2 is Vala.Class)
            return -1;
        else if (s2 is Vala.Method)
            return -1;
        else if (s2 is Vala.Namespace)
            return 1;
        else if (s2 is Vala.Property)
            return 1;
        else if (s2 is Vala.Signal)
            return 1;
        else if (s2 is Vala.Struct)
            return -1;
        return s.name.collate (s2.name);
    }
    int compare_method (Vala.Method s, Vala.Symbol s2)
    {
        if (s2 is Vala.Constant)
            return 1;
        else if (s2 is Vala.Delegate)
            return 1;
        else if (s2 is Vala.CreationMethod)
            return 1;
        else if (s2 is Vala.Constructor)
            return 1;
        else if (s2 is Vala.Destructor)
            return 1;
        else if (s2 is Vala.Enum)
            return 1;
        else if (s2 is Vala.Field)
            return 1;
        else if (s2 is Vala.Interface)
            return -1;
        else if (s2 is Vala.Class)
            return -1;
        else if (s2 is Vala.Namespace)
            return -1;
        else if (s2 is Vala.Property)
            return 1;
        else if (s2 is Vala.Signal)
            return 1;
        else if (s2 is Vala.Struct)
            return -1;
        return s.name.collate (s2.name);
    }
    int compare_namespace (Vala.Namespace s, Vala.Symbol s2)
    {
        if (s2 is Vala.Constant)
            return -1;
        else if (s2 is Vala.Delegate)
            return -1;
        else if (s2 is Vala.CreationMethod)
            return -1;
        else if (s2 is Vala.Constructor)
            return -1;
        else if (s2 is Vala.Destructor)
            return -1;
        else if (s2 is Vala.Enum)
            return -1;
        else if (s2 is Vala.Field)
            return -1;
        else if (s2 is Vala.Interface)
            return -1;
        else if (s2 is Vala.Method)
            return -1;
        else if (s2 is Vala.Class)
            return -1;
        else if (s2 is Vala.Property)
            return -1;
        else if (s2 is Vala.Signal)
            return -1;
        else if (s2 is Vala.Struct)
            return -1;
        return s.name.collate (s2.name);
    }
    int compare_property (Vala.Property s, Vala.Symbol s2)
    {
        if (s2 is Vala.Constant)
            return 1;
        else if (s2 is Vala.Delegate)
            return -1;
        else if (s2 is Vala.CreationMethod)
            return -1;
        else if (s2 is Vala.Constructor)
            return -1;
        else if (s2 is Vala.Destructor)
            return -1;
        else if (s2 is Vala.Enum)
            return -1;
        else if (s2 is Vala.Field)
            return 1;
        else if (s2 is Vala.Interface)
            return -1;
        else if (s2 is Vala.Method)
            return -1;
        else if (s2 is Vala.Namespace)
            return -1;
        else if (s2 is Vala.Class)
            return -1;
        else if (s2 is Vala.Signal)
            return -1;
        else if (s2 is Vala.Struct)
            return -1;
        return s.name.collate (s2.name);
    }
    int compare_signal (Vala.Signal s, Vala.Symbol s2)
    {
        if (s2 is Vala.Constant)
            return 1;
        else if (s2 is Vala.Delegate)
            return -1;
        else if (s2 is Vala.CreationMethod)
            return -1;
        else if (s2 is Vala.Constructor)
            return -1;
        else if (s2 is Vala.Destructor)
            return -1;
        else if (s2 is Vala.Enum)
            return -1;
        else if (s2 is Vala.Field)
            return 1;
        else if (s2 is Vala.Interface)
            return -1;
        else if (s2 is Vala.Method)
            return -1;
        else if (s2 is Vala.Namespace)
            return -1;
        else if (s2 is Vala.Property)
            return 1;
        else if (s2 is Vala.Class)
            return -1;
        else if (s2 is Vala.Struct)
            return -1;
        return s.name.collate (s2.name);
    }
    int compare_struct (Vala.Struct s, Vala.Symbol s2)
    {
        if (s2 is Vala.Constant)
            return -1;
        else if (s2 is Vala.Delegate)
            return -1;
        else if (s2 is Vala.CreationMethod)
            return -1;
        else if (s2 is Vala.Constructor)
            return -1;
        else if (s2 is Vala.Destructor)
            return -1;
        else if (s2 is Vala.Enum)
            return 1;
        else if (s2 is Vala.Field)
            return -1;
        else if (s2 is Vala.Interface)
            return 1;
        else if (s2 is Vala.Method)
            return -1;
        else if (s2 is Vala.Namespace)
            return 1;
        else if (s2 is Vala.Property)
            return -1;
        else if (s2 is Vala.Signal)
            return -1;
        else if (s2 is Vala.Class)
            return -1;
        return s.name.collate (s2.name);
    }
}
