using PetProject.Helper;
using PetSwagger;
using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Text;
using System.Threading;
using TechTalk.SpecFlow;
using TechTalk.SpecFlow.Assist;

namespace PetProject.Steps
{
    [Binding]
    public class UserSteps
    {

        [Given(@"the user with:")]
        public void GivenTheUserWith(Table table)
        {
            dynamic userVariables = table.CreateDynamicInstance();
            User user = UserHelper.CreateUser(userVariables);
            ScenarioContext.Current["UserRequest"] = user;
        }



        [When(@"a user is created")]
        public void WhenAUserIsCreated()
        {
            User userRequest = (User)ScenarioContext.Current["UserRequest"];
            HttpClient client = new HttpClient();
            PetSwaggerClient petClient = new PetSwaggerClient(client);

            var petResponse = petClient.CreateUserAsync (userRequest, CancellationToken.None).Result;
            ScenarioContext.Current["UserResponse"] = petResponse;
        }

    }
}
