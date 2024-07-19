# Earn Periphery

## Definitions

### Delayed Withdrawal Manager

When a delayed withdrawal is started, the Earn strategy will delegate the withdrawal to a delayed withdraw adapter. That
adapter is the one that will start the withdraw, and then register itself to the manager. By doing so, we will be able
to track all pending withdrawals for a specific position in one place

### Global Earn Config

A singleton contract that holds global configuration for the Earn ecosystem.

## Usage

This is a list of the most frequently needed commands.

### Build

Build the contracts:

```sh
$ forge build
```

### Clean

Delete the build artifacts and cache directories:

```sh
$ forge clean
```

### Compile

Compile the contracts:

```sh
$ forge build
```

### Coverage

Get a test coverage report:

```sh
$ forge coverage
```

### Format

Format the contracts:

```sh
$ forge fmt
```

### Gas Usage

Get a gas report:

```sh
$ forge test --gas-report
```

### Lint

Lint the contracts:

```sh
$ pnpm lint
```

### Test

Run the tests:

```sh
$ forge test
```

## License

TBD
