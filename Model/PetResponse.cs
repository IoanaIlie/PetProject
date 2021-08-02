using System;
using System.Collections.Generic;
using System.Text;

namespace PetProject.Model
{
    public class PetResponse : PetSwagger.Pet
    {
        public int ResponseStatus { get; set; }
    }
}
