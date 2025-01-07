# Gas Optimization:

## How Storage works:

**Notes:**

- Each slot is 32 bytes long, and represents the bytes version of the object
  - For example, the uint256 25 is 0x000...0019, since that’s the hex representation
  - For a “true” boolean, it would be 0x000...001, since that’s it’s hex
- For dynamic values like mappings and dynamic arrays, the elements are stored using a hashing function. You can see those functions in the documentation.
  - For arrays, a sequential storage spot is taken up for the length of the array.
  - For mappings, a sequential storage spot is taken up, but left blank
- Constants and immutable variables are not in storage, but they are considered part of the core of the bytecode of the contract.
- Variables in functions are also not in storage as they are only available for the duration of the function/

To check layout of storage of a contract_name.sol:
`forge inspect contract_name storageLayout`

## foundry make files

- A simple text file used by the utility called make to automate the process of building and compiling programs or projects.

Create a file named `Makefile`
In the file:

```
  -include .env #to include .env file

  shortcut_name:; command to execute
  #semicolon, if writing command on same line or just write on next line after a tab

```

- In makefiles, for environment variables, put them in brackets after $. ex - 
`$(PRIVATE_KEY)`
