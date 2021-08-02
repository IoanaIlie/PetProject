using PetSwagger;
using System;
using System.Collections.Generic;
using System.Text;

namespace PetProject.Helper
{
   public  class UserHelper
    {
        public static User CreateUser(dynamic userVariables)
        {
            User user = new User();
            if (Common.DoesPropertyExist(userVariables, "id"))
                user.Id = userVariables.id;
            if (Common.DoesPropertyExist(userVariables, "username"))
                user.Username = userVariables.username;
            if (Common.DoesPropertyExist(userVariables, "firstname"))
                user.FirstName = userVariables.name;
            if (Common.DoesPropertyExist(userVariables, "lastname"))
                user.LastName = userVariables.lastname;
            if (Common.DoesPropertyExist(userVariables, "email"))
                user.Email = userVariables.email;
            if (Common.DoesPropertyExist(userVariables, "password"))
                user.Password = userVariables.password;
            if (Common.DoesPropertyExist(userVariables, "phone"))
                user.Phone = userVariables.phone;
            if (Common.DoesPropertyExist(userVariables, "userStatus"))
                user.UserStatus = userVariables.userStatus;

            return user;
        }
    }
}
