using Microsoft.VisualStudio.TestTools.UnitTesting;
using PetProject.Helper;
using PetProject.Model;
using PetSwagger;
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using TechTalk.SpecFlow;
using TechTalk.SpecFlow.Assist;

namespace PetTestingProject.Steps
{
    [Binding]
    class PetSteps
    {
        [Given(@"the pet with:")]
        public void GivenThePetWith(Table table)
        {
            dynamic petVariables = table.CreateDynamicInstance();
            Pet pet = PetHelper.CreatePet(petVariables);
            ScenarioContext.Current["PetRequest"] = pet;
        }

        [Given(@"the values:")]
        public void GivenTheValues(Table table)
        {
            dynamic petVariables = table.CreateDynamicInstance();
            if (Common.DoesPropertyExist(petVariables, "id"))
                ScenarioContext.Current["IdRequest"] = petVariables.id;
            if (Common.DoesPropertyExist(petVariables, "name"))
                ScenarioContext.Current["NameRequest"] = petVariables.name;
            if (Common.DoesPropertyExist(petVariables, "status"))
                ScenarioContext.Current["StatusRequest"] = petVariables.status;
            if (Common.DoesPropertyExist(petVariables, "additionalMetadata"))
                ScenarioContext.Current["AdditionalMetadataRequest"] = petVariables.additionalMetadata;
            if (Common.DoesPropertyExist(petVariables, "file"))
                ScenarioContext.Current["FileRequest"] = petVariables.file;
        }


        [Given(@"the status filter as (.*)")]
        public void GivenTheStatusFilterAs(string statusFilter)
        {
            string[] statuses = statusFilter.Split(',');
            List<PetStatus> listOfStatuses = new List<PetStatus>();
            foreach (string status in statuses)
            {
                PetStatus petStatus = status == "1" ? PetStatus.Available : status == "0" ? PetStatus.Sold : PetStatus.Pending;
                listOfStatuses.Add(petStatus);
            }
            ScenarioContext.Current["StatusFilter"] = listOfStatuses;

        }

        [When(@"a pet is created")]
        public void WhenAPetIsCreated()
        {
            Pet petRequest = (Pet)ScenarioContext.Current["PetRequest"];
            HttpClient client = new HttpClient();
            PetSwaggerClient petClient = new PetSwaggerClient(client);

            var petResponse = petClient.AddPetAsync(petRequest, CancellationToken.None).Result;
            ScenarioContext.Current["PetResponse"] = petResponse;
        }

        [When(@"the pet is deleted")]
        public void WhenThePetIsDeleted()
        {
            Pet petRequest = (Pet)ScenarioContext.Current["PetRequest"];
            HttpClient client = new HttpClient();
            PetSwaggerClient petClient = new PetSwaggerClient(client);

            var petResponse = petClient.DeletePetAsync(null, (long)petRequest.Id).Result;
            ScenarioContext.Current["PetResponse"] = petResponse;
        }


        [When(@"the pet is updated")]
        public void WhenThePetIsUpdated()
        {
            Pet petRequest = (Pet)ScenarioContext.Current["PetRequest"];
            Pet petResponse = (Pet)ScenarioContext.Current["PetResponse"];
            petRequest.Id = petResponse.Id;

            HttpClient client = new HttpClient();
            PetSwaggerClient petClient = new PetSwaggerClient(client);

            var petUpdateResponse = petClient.UpdatePetAsync(petRequest, CancellationToken.None).Result;
            ScenarioContext.Current["PetResponse"] = petUpdateResponse;
        }

        [When(@"the ""(.*)"" of the pet is updated")]
        public void WhenTheOfThePetIsUpdated(string updateType)
        {
            HttpClient client = new HttpClient();
            PetSwaggerClient petClient = new PetSwaggerClient(client);
            long petId = 0;
            if (ScenarioContext.Current.ContainsKey("IdRequest"))
                petId = (int)ScenarioContext.Current["IdRequest"];
            else if (ScenarioContext.Current.ContainsKey("PetResponse"))
            {
                PetResponse petResponse = (PetResponse)ScenarioContext.Current["PetResponse"];
                petId = (long)petResponse.Id;
            }
            if ("form".Equals(updateType))
            {
                string name = (string)ScenarioContext.Current["NameRequest"];
                string status = (string)ScenarioContext.Current["StatusRequest"];


                var petUpdateResponse = petClient.UpdatePetWithFormAsync(petId, name, status).Result;
                ScenarioContext.Current["PetResponse"] = petUpdateResponse;
            }
            else if ("image".Equals(updateType))
            {
                string additionalMetadata = (string)ScenarioContext.Current["AdditionalMetadataRequest"];
                string image = (string)ScenarioContext.Current["FileRequest"];
                if (!string.IsNullOrEmpty(image))
                {
                    FileStream fs = File.Create(image);
                    FileParameter fileParameter = new FileParameter(fs);
                    var apiResponse = petClient.UploadFileAsync(petId, additionalMetadata, fileParameter).Result;
                    ScenarioContext.Current["ApiResponse"] = apiResponse;
                }
                else
                {
                    var apiResponse = petClient.UploadFileAsync(petId, additionalMetadata, null).Result;
                    ScenarioContext.Current["ApiResponse"] = apiResponse;
                }

            }
        }


        [When(@"try to find the pet by ""(.*)""")]
        public void WhenTryToFindThePetBy(string filter)
        {
            HttpClient client = new HttpClient();
            PetSwaggerClient petClient = new PetSwaggerClient(client);

            switch (filter)
            {
                case "ID":
                    Pet petRequest = (Pet)ScenarioContext.Current["PetRequest"];
                    var petResponse = petClient.GetPetByIdAsync((long)petRequest.Id, CancellationToken.None).Result;
                    ScenarioContext.Current["PetResponse"] = petResponse;
                    break;
                case "STATUS":
                    List<PetStatus> statuses = (List<PetStatus>)ScenarioContext.Current["StatusFilter"];
                    var pets = petClient.FindPetsByStatusAsync(statuses, CancellationToken.None).Result;
                    ScenarioContext.Current["PetResponses"] = pets;
                    break;
                default: break;
            }
        }


        [Then(@"the response contains the posted values")]
        public void ThenTheResponseContainsThePostedValues()
        {
            if (ScenarioContext.Current.ContainsKey("ApiResponse"))
            {
                ApiResponse apiResponse = (ApiResponse)ScenarioContext.Current["ApiResponse"];
                string additionalMetadata = (string)ScenarioContext.Current["AdditionalMetadataRequest"];
                string file = (string)ScenarioContext.Current["FileRequest"];
                Assert.AreEqual(200, apiResponse.Code);
                Assert.IsTrue(apiResponse.Message.Contains(additionalMetadata));
                Assert.IsTrue(apiResponse.Message.Contains(file));

            }
            else
            {
                Pet petResponse = (Pet)ScenarioContext.Current["PetResponse"];
                Pet petRequest = (Pet)ScenarioContext.Current["PetRequest"];

                Assert.IsNotNull(petResponse);
                Assert.AreEqual(petRequest.Id, petResponse.Id);
                if (petRequest.Name != null)
                    Assert.AreEqual(petRequest.Name, petResponse.Name);
                if (petRequest.Status != null)
                    Assert.AreEqual(petRequest.Status, petResponse.Status);
                if (petRequest.PhotoUrls.Count != 0)
                {
                    string photosRequest = petRequest.PhotoUrls.Aggregate((i, j) => i + "," + j);
                    string photosResponse = petResponse.PhotoUrls.Aggregate((i, j) => i + "," + j);
                    Assert.AreEqual(photosRequest, photosResponse);
                }

                if (petRequest.Category != null)
                {
                    Assert.AreEqual(petRequest.Category.Id, petResponse.Category.Id);
                    Assert.AreEqual(petRequest.Category.Name,
                        petResponse.Category.Name);
                }
                if (petRequest.Tags != null)
                {
                    Assert.AreEqual(string.Join("|", petRequest.Tags.Select(x => x.Id.ToString()).ToArray()),
                        string.Join("|", petResponse.Tags.Select(x => x.Id.ToString()).ToArray()));
                    Assert.AreEqual(string.Join("|", petRequest.Tags.Select(x => x.Name.ToString()).ToArray()),
                       string.Join("|", petResponse.Tags.Select(x => x.Name.ToString()).ToArray()));
                }
            }
        }

        [Then(@"the response code should be ""(.*)""")]
        public void ThenTheResponseCodeShouldBe(int responseStatus)
        {
            if (ScenarioContext.Current.ContainsKey("PetResponse"))
            {
                PetResponse petResponse = (PetResponse)ScenarioContext.Current["PetResponse"];
                Assert.AreEqual(responseStatus, petResponse.ResponseStatus);
            }
            else if (ScenarioContext.Current.ContainsKey("PetResponse"))
            {
                ApiResponse apiResponse = (ApiResponse)ScenarioContext.Current["ApiResponse"];
                Assert.AreEqual(responseStatus, apiResponse.Code);
            }
        }
        [Then(@"the response contains the searched statuses")]
        public void ThenTheResponseContainsTheSearchedStatuses()
        {
            var petsFromStatusSearch = (List<Pet>)ScenarioContext.Current["PetResponses"];
            List<PetStatus> statuses = (List<PetStatus>)ScenarioContext.Current["StatusFilter"];
            HashSet<PetStatus> listOfStatusesFromResponse = new HashSet<PetStatus>();

            foreach (Pet pet in petsFromStatusSearch)
            {
                //verify if all the pets returned have the status in the searched list
                var find = statuses.FirstOrDefault(status => status == pet.Status);
                Assert.IsNotNull(find, "The status: " + pet.Status + " for pet.Id " + pet.Id + " does not appear in the search status list! ");

                //try to verify if all the searched statuses were found in the responses
                // PetHelper.Add<PetStatus>(listOfStatusesFromResponse, (PetStatus)pet.Status);
                listOfStatusesFromResponse.Add((PetStatus)pet.Status);
            }

            if (!(!listOfStatusesFromResponse.Except(statuses).Any() && !statuses.Except(listOfStatusesFromResponse).Any()))
            {
                Assert.Fail("Not all the searched statuses appear in the Pet result list! ");
            }
        }

    }
}
