using System;
using System.Collections.Generic;
using System.Dynamic;
using System.Text;

namespace PetProject.Helper
{
    public class Common
    {
        public static bool DoesPropertyExist(dynamic settings, string name)
        {
            if (settings is ExpandoObject)
                return ((IDictionary<string, object>)settings).ContainsKey(name);

            return settings.GetType().GetProperty(name) != null;
        }
    }
}
