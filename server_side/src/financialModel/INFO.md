# HouseholdPaymentPool

This is an implementation of a basic financial model which distributes transactions initiated by a user to other members of this user's household. The model aims to charge user's under the main constraint that a user should never be charged more than they would have spent otherwise for a given period.

The financial model will receive its data and information from the front-end of the whole application. Requests to the model will include the following data:

1. Creation of Household: This will be a call to the model to create an entry in the database for the following information:
   1. Name of Household, preferably a randomly generated uuid.
   2. A relevant list of the members, although that may not be necessary depending on what information a member has.

    Every member will have an entry in the DBMS with the following information:
   1. Name of member, which will probably be another uuid
   2. Household of member
   3. Current Budget, which represents how much money a member has
   4. Current Charged, which represents how much money has been charged to that member's budget.
   5. Current Actual Spend, which represents how much money a member has actually spent.

2. Spending Transactions: This will be a call to the model to charge a specific amount of funds to a subset of the household members, initiated when a member pays using the app. That call should include the following information:
   1. Name of member who initiated transaction
   2. Name of household
   3. Amount spent

3. Top-Ups: This call will update the current budget by incrementing it by a desired amount. This will require the following information:
   1. Name of member whose is being topped
   2. Name of household
   3. Amount to add

The database should be able to return a list of the members of a household.
