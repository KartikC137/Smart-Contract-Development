- Using 0.8.19 pragma because of dependent contracts
- Use Chainlink brownie contracts.
- Use Chainlink automation to automate your contracts
- foundry-devops repo to easily work with contract deployements (like getting latest contract deployement)

# Test

### Levels of Testing:

- unit
- integrations
- forked
- staging <- run tests on a mainnent or testnet

- fuzzing
- stateful fuzz
- stateless fuzz
- formal verification

- Fuzz testing:
  Fuzz testing is a software testing technique that involves intentionally feeding invalid data into a program to find bugs, errors, and security risks.

# Events

- Whenever updating storage variables, emit an event
- Events have two types of parameters: indexed and non-indexed
- Indexed parameters are also called topics and are searchable

## Why Events:

- Makes Migrations easier
- Makes front end "indexing" easier

# Layout of Contract:

1. version
2. imports
3. errors
4. interfaces, libraries, contracts
5. Type declarations
6. State variables
7. Events
8. Modifiers
9. Functions

# Layout of Functions:

1. constructor
2. receive function (if exists)
3. fallback function (if exists)
4. external
5. public
6. internal
7. private
8. view & pure functions

# Naming standards:

- for custom errors: ContractName\_\_ErrorName();

# Basic Math tricks:

- Any no. % certain no., the answer returned is always between 0 and certain no. - 1
