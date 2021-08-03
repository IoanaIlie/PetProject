Feature: Pet

#petstatus - 1 = Available
#pet.status - 0 = Sold
#pet.status - 2 = Pending
@positive @CreatePet
Scenario Outline: 1. Create pet using valid values
	Given the pet with:
		| variable     | value          |
		| name         | <name>         |
		| status       | <status>       |
		| categoryId   | <categoryId>   |
		| categoryName | <categoryName> |
		| photoUrls    | default        |
		| tagId        | <tagId>        |
		| tagName      | <tagName>      |
	When a pet is created
	Then the response code should be "200"
	And the response contains the posted values
	When try to find the pet by "ID"
	Then the response code should be "200"
	And the response contains the posted values

	Examples:
		| ID | name  | status | categoryId | categoryName | tagId | tagName |
		| 1  | Lila  | 1      | 1          | NicePet      | 2     | Tag1    |
		| 2  | Lila0 | 0      | 2          | NicePets     | 3     | Tag2    |
		| 3  | Lila1 | 1      | 1          | NicePet      | 4     | Tag3    |
		| 4  | Lila2 | 2      | 2          | NicePets     | 5     | Tag4    |

@negative @CreatePet
Scenario Outline: 2. Create pet using invalid and mandatory(name and photoUrls) values values
	Given the pet with:
		| variable  | value   |
		| id        | <id>    |
		| name      | <name>  |
		| photoUrls | default |
	When a pet is created
	Then the response code should be "405"

	Examples:
		| ID | id              | name | photoUrls |
		| 1  | -1              | Dog  | default   |
		| 2  | 999999999999999 | Dog  | default   |
		| 3  | 0               |      | default   |
		| 4  | 0               | Dog  |           |
		| 5  | 0               |      |           |

@validation @CreatePet
Scenario Outline: 3. Create Pet - duplicate detection for the same id and status
	Given the pet with:
		| variable  | value     |
		| id        | <id1>     |
		| name      | Dog       |
		| status    | <status1> |
		| photoUrls | default   |
	When a pet is created
	Then the response code should be "200"
	Given the pet with:
		| variable  | value     |
		| id        | <id2>     |
		| name      | Dog       |
		| status    | <status2> |
		| photoUrls | default   |
	When a pet is created
	Then the response code should be "<duplicateResponse>"

	Examples:
		| ID | id1 | status1 | id2 | status2 | duplicateResponse |
		| 1  | 10  | 1       | 10  | 1       | 405               |
		| 2  | 20  | 0       | 20  | 0       | 405               |
		| 3  | 30  | 2       | 30  | 2       | 405               |
		| 4  | 40  | 1       | 40  | 2       | 200               |
		| 5  | 50  | 0       | 50  | 2       | 200               |
		| 6  | 60  | 2       | 60  | 1       | 200               |

@positive @SearchPet
Scenario Outline: 4. Search pet by status validation
	Given the status filter as <status>
	When try to find the pet by "STATUS"
	Then the response code should be "200"
	And the response contains the searched statuses

	Examples:
		| ID | status |
		| 1  | 1      |
		| 2  | 2      |
		| 3  | 0      |
		| 4  | 0,1    |
		| 5  | 1,2    |
		| 6  | 0,2    |
		| 7  | 0,1,2  |

@positive @UpdatePet
Scenario Outline: 5. Modify pet using valid values
	Given the pet with:
		| variable     | value           |
		| name         | <name1>         |
		| status       | <status1>       |
		| categoryId   | <categoryId1>   |
		| categoryName | <categoryName1> |
		| photoUrls    | default         |
		| tagId        | <tagId1>        |
		| tagName      | <tagName1>      |
	When a pet is created
	Then the response code should be "200"
	And the response contains the posted values
	Given the pet with:
		| variable     | value           |
		| name         | <name2>         |
		| status       | <status2>       |
		| categoryId   | <categoryId2>   |
		| categoryName | <categoryName2> |
		| photoUrls    | default2        |
		| tagId        | <tagId2>        |
		| tagName      | <tagName2>      |
	When the pet is updated
	Then the response code should be "200"
	And the response contains the posted values

	Examples:
		| ID | name1    | status1 | categoryId1 | categoryName1 | tagId1 | tagName1  | name2      | status2 | categoryId2 | categoryName2 | tagId2 | tagName2  |
		| 1  | Lila1    | 1       | 1           | NicePet1      | 1      | Tag1      | Lila2      | 2       | 2           | NicePet2      | 2      | Tag2      |
		| 2  | Lila01   | 1       | 1           | NicePet01     | 1      | Tag01     | Lila01     | 0       | 2           | NicePet02     | 2      | Tag02     |
		| 3  | Lila001  | 2       | 1           | NicePet001    | 1      | Tag001    | Lila001    | 1       | 2           | NicePet002    | 2      | Tag002    |
		| 4  | Lila0001 | 2       | 1           | NicePet0001   | 1      | Tag0001   | Lila0001   | 0       | 2           | NicePet0002   | 2      | Tag0002   |
		| 5  | Lila0001 | 0       | 1           | NicePet00001  | 1      | Tag00001  | Lila00001  | 1       | 2           | NicePet00002  | 2      | Tag00002  |
		| 6  | Lila0001 | 0       | 1           | NicePet000001 | 1      | Tag000001 | Lila000001 | 2       | 2           | NicePet000002 | 2      | Tag000002 |

@negative @UpdatePet
Scenario Outline: 6. Modify pet using invalid values
	Given the pet with:
		| variable     | value           |
		| name         | <name1>         |
		| status       | <status1>       |
		| categoryId   | <categoryId1>   |
		| categoryName | <categoryName1> |
		| photoUrls    | default         |
		| tagId        | <tagId1>        |
		| tagName      | <tagName1>      |
	When a pet is created
	Then the response code should be "200"
	And the response contains the posted values
	Given the pet with:
		| variable     | value           |
		| id           | <id2>           |
		| name         | <name2>         |
		| categoryId   | <categoryId2>   |
		| categoryName | <categoryName2> |
		| photoUrls    | default2        |
		| tagId        | <tagId2>        |
		| tagName      | <tagName2>      |
	When the pet is updated
	Then the response code should be "<responseUpdate>"

	Examples:
		| ID | name1  | status1 | categoryId1 | categoryName1 | tagId1 | tagName1 | id2               | name2  | categoryId2 | categoryName2 | tagId2 | tagName2 | responseUpdate |
		| 1  | Lila1  | 1       | 1           | NicePet1      | 1      | Tag1     | 1                 | Lila2  | 2           | NicePet2      | 2      | Tag2     | 400            |
		| 2  | Lila01 | 1       | 1           | NicePet01     | 1      | Tag01    | 99999999999999999 | Lila01 | 2           | NicePet02     | 2      | Tag02    | 404            |

@positive @DeletePet
Scenario Outline: 7. Delete existing pet
	Given the pet with:
		| variable     | value          |
		| name         | <name>         |
		| status       | <status>       |
		| categoryId   | <categoryId>   |
		| categoryName | <categoryName> |
		| photoUrls    | default        |
		| tagId        | <tagId>        |
		| tagName      | <tagName>      |
	When a pet is created
	Then the response code should be "200"
	And the response contains the posted values
	When the pet is deleted
	#in the documentation should be 204 instead 200, and the validation should be done acordingly
	Then the response code should be "200"
	When the pet is deleted
	Then the response code should be "404"

	Examples:
		| ID | name  | status | categoryId | categoryName | tagId | tagName |
		| 1  | Lila  | 1      | 1          | NicePet      | 2     | Tag1    |
		| 2  | Lila0 | 0      | 2          | NicePets     | 3     | Tag2    |
		| 3  | Lila2 | 2      | 2          | NicePets     | 5     | Tag4    |

@negative @DeletePet
Scenario Outline: 8. Delete pet - invalid id
	Given the pet with:
		| variable | value |
		| id       | <id>  |
	When the pet is deleted
	Then the response code should be "<deleteResponse>"
	When the pet is deleted
	Then the response code should be "404"

	Examples:
		| ID | id                  | deleteResponse |
		| 1  | -1                  | 400            |
		| 2  | 9999999999999999999 | 404            |

@positive @UpdatePet
Scenario Outline: 9. Update name and status - valid values
	Given the pet with:
		| variable  | value     |
		| name      | <name1>   |
		| status    | <status1> |
		| photoUrls | default   |
	When a pet is created
	Then the response code should be "200"
	And the response contains the posted values
	Given the values:
		| variable | value     |
		| name     | <name2>   |
		| status   | <status2> |
	When the name and/or status of the pet are updated
	Then the response code should be "200"
	And the response contains the posted values

	Examples:
		| ID | name1    | status1 | name2      | status2   |
		| 1  | Lila1    | 1       | Lila2      | pending   |
		| 2  | Lila01   | 1       | Lila01     | sold      |
		| 3  | Lila001  | 2       | Lila001    | available |
		| 4  | Lila0001 | 2       | Lila0001   | sold      |
		| 5  | Lila0001 | 0       | Lila00001  | available |
		| 6  | Lila0001 | 0       | Lila000001 | pending   |

@negative @UpdatePet
Scenario Outline: 10. Update name and status - invalid values
	Given the pet with:
		| variable  | value     |
		| name      | <name1>   |
		| status    | <status1> |
		| photoUrls | default   |
	When a pet is created
	Then the response code should be "200"
	And the response contains the posted values
	Given the values:
		| variable | value     |
		| name     | <name2>   |
		| status   | <status2> |
	When the "form" of the pet is updated
	Then the response code should be "405"
	And the response contains the posted values

	Examples:
		| ID | name1    | status1 | name2  | status2   |
		| 1  | Lila1    | 1       |        | pending   |
		| 2  | Lila01   | 1       | Lila01 | sold123   |
		| 3  | Lila001  | 2       | Lila   | $%^&$%^*$ |
		| 4  | Lila0001 | 2       | Lila   |           |

@negative @UpdatePet
Scenario: 11. Update name and status - pet not foud
	Given the values:
		| variable | value  |
		| id       | 999999 |
		| name     | Lila   |
		| status   | sold   |
	When the "form" of the pet is updated
	Then the response code should be "404"

@positive @UpdatePetImage
Scenario: 12. Update pet with image
	Given the pet with:
		| variable  | value   |
		| name      | Lila    |
		| status    | 1       |
		| photoUrls | default |
	When a pet is created
	Then the response code should be "200"
	And the response contains the posted values
	Given the values:
		| variable           | value                                              |
		| additionalMetadata | metainfo                                           |
		| file               | C:\\Users\\Ioana\\Pictures\\Screenpresso\\test.png |
	When the "image" of the pet is updated
	Then the response code should be "200"
	And the response contains the posted values

@negative @UpdatePet
Scenario Outline: 13. Update pet with image - validations
	Given the values:
		| variable           | value                |
		| id                 | <id>                 |
		| additionalMetadata | <additionalMetadata> |
		| file               | <file>               |
	When the "image" of the pet is updated
	Then the response code should be "<responseCode>"

	Examples:
		| ID | id      | additionalMetadata | file  | responseCode |
		| 1  | 0       | meta               | a.jpg | 400          |
		| 1  | 9999999 | meta               | a.jpg | 400          |
		| 2  | 2       |                    | a.jpg | 200          |
		| 3  | 2       | meta               |       | 200          |
		| 4  | 2       |                    |       | 400          |

@positive @CreatePet
Scenario: 1. Create pet  - idempotency validation
	Given the pet with:
		| variable     | value          |
		| name         | Lila         |
		| status       | 1       |
		| photoUrls    | default        |
	When a pet is created
	Then the response code should be "200"
	And the response contains the posted values
	When a pet is created
	Then the response code should be "200"
	And the response contains the posted values