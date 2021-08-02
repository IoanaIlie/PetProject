using System;
using System.Collections.Generic;
using System.Text;

namespace PetProject.Model
{
    public class UserResponse : PetSwagger.User
    {
        public int ResponseStatus { get; set; }

    }
}
