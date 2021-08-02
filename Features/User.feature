Feature: User

@positive
Scenario: 1. Create user
	Given the user with:
		| variable   | value        |
		| id         | 1            |
		| username   | username123  |
		| firstName  | firstName123 |
		| lastName   | lastName123  |
		| email      | email123     |
		| password   | password123  |
		| phone      | phone123     |
		| userStatus | 0            |
	When a user is created
	Then the response code should be "200"