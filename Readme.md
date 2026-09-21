# What's?

bip39-dice-cli-generator is an offline-friendly command-line utility for creating BIP-39 mnemonic seed phrases using physical dice rolls. It transforms manually entered dice-roll data into entropy and derives a standard wallet recovery phrase, giving users a transparent way to generate seeds without depending on online services or hidden system randomness.

Designed for users who value verifiable entropy, self-custody, and privacy, the tool provides a simple CLI workflow for generating wallet mnemonics from randomness they can observe and control.

----------------------
# Introduction

To generate a strong wallet, you need a strong source of entropy. This because the private key is nothing more than a simple number between 2^1 and 2^256.

To be secure against a bruteforce attack you need at least 128 bits of entropy. This is the motivation behind the choice of the minimum entropy in [bip39](https://github.com/bitcoin/bips/blob/master/bip-0039/english.txt) wallets.

The human race are not good to generate an unbiased source of entropy. Something that it seems random it's the result of our personal experiences mixed with our personal temperament.

You have only two choices to get a random number:
- RNG function from a electronic device, like a PC or hardware wallet
- The vibrations of the universe canalized thought a multiple throws of dices

The former is the fastest and comfortable choice, but you can't be shure that at some point someone finds out a vulnerability in this functions and at our expense we discover that the key you have generated is not much random as you thought.

The huge number behind 256 bits of entropy:
```2^256 1.157920892373162e+77```

A standard dice D6 entropy:
```D6entropy = log(6) / log(2) = log2(6) = 2.584962500721156 ~ 2.585 bits```

To know how much throws you need, you must divide the entropy target with the entropy of the single dice throw:
```NumberOfThrows = EntropyTarget / D6Entropy = 256 / 2.584962500721156 = 99.03431865204266 ~ 99```

To prove mathematically, multipliy the dice entropy with the number of throws founded
```EntropyTarget = D6Entropy * NumberOfThrows = log2(6) * 99 = 2.584962500721156 * 99 = 255.91128757139444 ~ 256 bits```

PS: if your dice have only 2 faces, you just flipping a coin :)
log2(2) = 1 * 256 = 256 bits
```D6entropy = log(2) / log(2) = log2(2) = 1 bit```

# Test script

Just for testing purpose you can generate a pseudo-random sequence of throws with this command:
```shuf -r -i 1-6 -n 99 | tr -d '\n'```

DO NOT USE THE GENERATE SEQUENCE FOR REAL WALLET!!
USE PHYSICAL DICES!!!


# Usage

Generate seed inserting throws for default D6 dice
```bash bip39-dice-generator.sh -s <sequence_of_values>```

Generate seed for coin flipping
```bash bip39-dice-generator.sh -s <sequence_of_values> -f 2```


