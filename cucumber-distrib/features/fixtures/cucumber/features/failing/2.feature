Feature: Buy even more apples
  I went to the store to buy apples

  Scenario:
    Given I have 3 apples
    When I buy 2 apples
    Then I have 6 apples now
