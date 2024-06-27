Feature: Buy more apples
  I went to the store to buy apples

  Scenario:
    Given I have 48 apples
    When I sell 2 apples
    Then I have 46 apples now
