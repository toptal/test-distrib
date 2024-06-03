Feature: User does random things
  In order to provide great service for our customers
  So as a user
  I should be able to do whatever I want

  @guest
  Scenario: Sending as a guest user
    When I am not authorized
    And I complete contact form
    Then email should be sent:
      | to     | subject                           |
      | user   | We have received your application |
    Background:
      | role      |      email      |
      | user      | john@doe.com    |
      | moderator | agent@smith.com |
      | admin     | neo@matrix.com  |
