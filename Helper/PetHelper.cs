

using PetSwagger;
using System;
using System.Collections.Generic;
using System.Dynamic;
using System.Text;

namespace PetProject.Helper
{
    public static class PetHelper
    {
        public static string DEFAULT = "https://www.google.com/url?sa=i&url=https%3A%2F%2Fwww.shutterstock.com%2Fde%2Fcategory%2Fnature&psig=AOvVaw0AA1xAdD9YN_KgiBzTAgxz&ust=1627815241456000&source=images&cd=vfe&ved=0CAsQjRxqFwoTCJCrtr2SjfICFQAAAAAdAAAAABAI";
        public static string DEFAULT2 = "";
        public static Pet CreatePet(dynamic petVariables)
        {
            Pet pet = new Pet();

            // random ID
            Random rnd = new Random();
            pet.Id = rnd.Next(1000, 10000);
            if (Common.DoesPropertyExist(petVariables, "name"))
                pet.Name = petVariables.name;
            if (Common.DoesPropertyExist(petVariables, "status"))
                pet.Status = petVariables.status == 1 ? PetStatus.Available : petVariables.status == 0 ? PetStatus.Sold : PetStatus.Pending;

            //create category
            if (Common.DoesPropertyExist(petVariables, "categoryId") && Common.DoesPropertyExist(petVariables, "categoryName"))
            {
                Category category = new Category();
                category.Id = petVariables.categoryId;
                category.Name = petVariables.categoryName;
                pet.Category = category;
            }

            //create photo urls
            if (Common.DoesPropertyExist(petVariables, "photoUrls"))
            {
                List<string> photoUrls = new List<string>();
                photoUrls.Add(petVariables.photoUrls == "default" ? DEFAULT : petVariables.photoUrls == "default2" ? DEFAULT2 : petVariables.photoUrls);
                pet.PhotoUrls = photoUrls;
            }

            //create tags
            if (Common.DoesPropertyExist(petVariables, "tagId") && Common.DoesPropertyExist(petVariables, "tagName"))
            {
                Tag tag = new Tag();
                tag.Id = petVariables.tagId;
                tag.Name = petVariables.tagName;
                List<Tag> tags = new List<Tag>();
                tags.Add(tag);
                pet.Tags = tags;
            }

            return pet;
        }
        

    }

}
