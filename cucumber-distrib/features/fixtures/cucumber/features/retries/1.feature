Feature: Buy more apples
  I went to the store to buy apples

  Scenario:
    Given I have 48 apples
    When I buy 2 apples
    Then I have 50 apples now
