Feature: User does random things
  In order to provide great service for our customers
  So as a user
  I should be able to do whatever I want

  Background:
    Given I open homepage

  @guest
  Scenario: Sending as a guest user
    When I am not authorized
    And I complete contact form
    Then email should be sent:
      | to     | subject                           |
      | user   | We have received your application |

  @logged_in
  Scenario Outline: Staff sends feedback
    When I am authorized as <role>
    And I complete contact form
    Then email should be sent:
      | to      | subject               |
      | <email> | Knock, knock, <role>  |
    Examples:
      | role      |      email      |
      | user      | john@doe.com    |
      | moderator | agent@smith.com |
      | admin     | neo@matrix.com  |

  Scenario Outline: Client gets discount
    When my referral status is <status>
    And I put <amount> of goods into the cart
    Then I get <discount> discount

  Scenarios: First time customer
    | status      | amount  |  discount |
    | organic     |   5     |    15%    |
    | ad campaign |  10     |     5%    |

  Scenarios: Returning customer
    | status       | amount  |  discount |
    | email        |   5     |     5%    |
    | social media |  10     |    10%    |
